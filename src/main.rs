use std::num::ParseIntError;
use std::str::FromStr;
use std::sync::{Arc, Mutex};

use futures::future::{ok, Future};
use futures::stream::Stream;
use hyper::header::{CONTENT_ENCODING, CONTENT_TYPE};
use hyper::service::service_fn;
use hyper::{Body, Error, Method, Request, Response, Server, StatusCode, Uri};
use tokio::runtime::current_thread::run;
use url::form_urlencoded::parse;

use serde::{de::DeserializeOwned, ser::Serialize};
use serde_json::{from_slice, to_vec};

use rusqlite::{Connection, Transaction};

use error_chain::ChainedError;
use time::get_time;

mod datenbank;
mod modell;
mod versenden;

mod errors {
    use error_chain::{
        error_chain, error_chain_processing, impl_error_chain_kind, impl_error_chain_processed,
        impl_extract_backtrace,
    };

    error_chain! {
        foreign_links {
            Io(::std::io::Error);
            ParseInt(::std::num::ParseIntError);
            SQLite(::rusqlite::Error);
            SerdeJson(::serde_json::Error);
            LettreSmtp(::lettre::smtp::error::Error);
            LettreEmail(::lettre_email::error::Error);
        }
    }
}

use self::errors::Result;

fn main() -> Result<()> {
    let conn = Arc::new(Mutex::new(datenbank::schema_anlegen()?));

    let service = move || {
        let conn = conn.clone();

        service_fn(move |req| match (req.method(), req.uri().path()) {
            (&Method::GET, "/ui/Pflegemittel") => pflegemittel_anzeigen(),
            (&Method::GET, "/ui/NeueBestellung") => neue_bestellung_anlegen(),

            (&Method::GET, "/api/anbieter") => anbieter_laden(req.uri(), &conn),

            (&Method::GET, "/api/pflegemittel") => pflegemittel_laden(req.uri(), &conn),
            (&Method::POST, "/api/pflegemittel") => pflegemittel_speichern(req, conn.clone()),

            (&Method::GET, "/api/bestellungen") => bestellungen_laden(req.uri(), &conn),
            (&Method::POST, "/api/bestellungen") => bestellung_versenden(req, conn.clone()),

            _ => Box::new(ok(Response::builder()
                .status(StatusCode::NOT_FOUND)
                .header(CONTENT_TYPE, "text/plain")
                .body("Method or path not found.".into())
                .unwrap())),
        })
    };

    let server = Server::bind(&([0, 0, 0, 0], 8080).into())
        .serve(service)
        .map_err(|err| eprintln!("Server error: {}", err));

    run(server);

    Ok(())
}

type Antwort = Box<Future<Item = Response<Body>, Error = Error> + Send>;

fn pflegemittel_anzeigen() -> Antwort {
    eingebette_seite_ausliefern(include_bytes!("../target/html/Pflegemittel.html.gz"))
}

fn neue_bestellung_anlegen() -> Antwort {
    eingebette_seite_ausliefern(include_bytes!("../target/html/NeueBestellung.html.gz"))
}

fn anbieter_laden(uri: &Uri, conn: &Mutex<Connection>) -> Antwort {
    anfrage_verarbeiten(uri, conn, |_, txn| datenbank::anbieter_laden(txn))
}

fn pflegemittel_laden(uri: &Uri, conn: &Mutex<Connection>) -> Antwort {
    anfrage_verarbeiten(uri, conn, |_, txn| datenbank::pflegemittel_laden(txn))
}

fn pflegemittel_speichern(req: Request<Body>, conn: Arc<Mutex<Connection>>) -> Antwort {
    anfrage_mit_objekt_verarbeiten(req, conn, |_, pflegemittel, txn| {
        datenbank::pflegemittel_speichern(txn, pflegemittel, get_time().sec)?;
        datenbank::pflegemittel_laden(txn)
    })
}

fn bestellungen_laden(uri: &Uri, conn: &Mutex<Connection>) -> Antwort {
    anfrage_verarbeiten(uri, conn, |uri, txn| {
        let anbieter = parse_anbieter(uri)?;
        let bis_zu = parse_bis_zu(uri)?;

        datenbank::bestellungen_laden(txn, anbieter, bis_zu)
    })
}

fn bestellung_versenden(req: Request<Body>, conn: Arc<Mutex<Connection>>) -> Antwort {
    anfrage_mit_objekt_verarbeiten(req, conn, |uri, bestellung, txn| {
        let anbieter = parse_anbieter(uri)?;
        let bis_zu = parse_bis_zu(uri)?;

        let bestellung = datenbank::bestellung_speichern(txn, bestellung, get_time().sec)?;
        versenden::bestellung_versenden(txn, bestellung)?;
        datenbank::bestellungen_laden(txn, anbieter, bis_zu)
    })
}

fn eingebette_seite_ausliefern(body: &'static [u8]) -> Antwort {
    Box::new(ok(Response::builder()
        .header(CONTENT_TYPE, "text/html")
        .header(CONTENT_ENCODING, "gzip")
        .body(body.into())
        .unwrap()))
}

fn anfrage_verarbeiten<T: Serialize, H: FnOnce(&Uri, &Transaction) -> Result<T>>(
    uri: &Uri,
    conn: &Mutex<Connection>,
    handler: H,
) -> Antwort {
    Box::new(ok(fehler_behandeln(in_transaktion_ausfuehren(
        uri, conn, handler,
    ))))
}

fn anfrage_mit_objekt_verarbeiten<
    S: DeserializeOwned,
    T: Serialize,
    H: 'static + Send + FnOnce(&Uri, S, &Transaction) -> Result<T>,
>(
    req: Request<Body>,
    conn: Arc<Mutex<Connection>>,
    handler: H,
) -> Antwort {
    let (parts, body) = req.into_parts();

    Box::new(body.concat2().and_then(move |body| {
        ok(fehler_behandeln(in_transaktion_ausfuehren(
            &parts.uri,
            &conn,
            move |uri, txn| handler(uri, from_slice(body.as_ref())?, txn),
        )))
    }))
}

fn in_transaktion_ausfuehren<T: Serialize, H: FnOnce(&Uri, &Transaction) -> Result<T>>(
    uri: &Uri,
    conn: &Mutex<Connection>,
    handler: H,
) -> Result<Response<Body>> {
    let mut conn = conn.lock().unwrap();
    let txn = conn.transaction()?;

    let body = to_vec(&handler(uri, &txn)?)?;

    txn.commit()?;

    Ok(Response::builder()
        .header(CONTENT_TYPE, "application/json")
        .body(body.into())
        .unwrap())
}

fn fehler_behandeln(resp: Result<Response<Body>>) -> Response<Body> {
    match resp {
        Ok(resp) => resp,

        Err(err) => {
            eprintln!("{}", err.display_chain());

            Response::builder()
                .status(StatusCode::INTERNAL_SERVER_ERROR)
                .header(CONTENT_TYPE, "text/plain")
                .body(err.to_string().into())
                .unwrap()
        }
    }
}

fn parse_anbieter(uri: &Uri) -> Result<i64> {
    parse_param(uri, "anbieter", 0)
}

fn parse_bis_zu(uri: &Uri) -> Result<u32> {
    parse_param(uri, "bis_zu", 1)
}

fn parse_param<T: FromStr<Err = ParseIntError>>(
    uri: &Uri,
    param: &'static str,
    def_val: T,
) -> Result<T> {
    if let Some(query) = uri.query() {
        for (key, val) in parse(query.as_bytes()) {
            if key == param {
                return Ok(val.parse()?);
            }
        }
    }

    Ok(def_val)
}
