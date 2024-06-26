use std::cell::RefCell;
use std::env::var;
use std::error::Error;
use std::net::SocketAddr;
use std::num::ParseIntError;
use std::rc::Rc;
use std::str::FromStr;
use std::time::SystemTime;

use http_body_util::{BodyExt, Full};
use hyper::{
    body::{Bytes, Incoming},
    header::{CONTENT_ENCODING, CONTENT_TYPE},
    server::conn::http1::Builder as ConnBuilder,
    service::service_fn,
    Method, Request, Response, StatusCode, Uri,
};
use hyper_util::rt::tokio::{TokioIo, TokioTimer};
use rusqlite::{Connection, Transaction};
use serde::{de::DeserializeOwned, ser::Serialize};
use serde_json::{from_slice, to_vec};
use tokio::{
    net::TcpListener,
    runtime::Builder as RuntimeBuilder,
    task::{spawn_local, LocalSet},
};
use url::form_urlencoded::parse;

mod datenbank;
mod modell;
mod versenden;

type Fallible<T> = Result<T, Box<dyn Error + Send + Sync>>;

fn main() -> Fallible<()> {
    let bind_addr = var("BIND_ADDR")?.parse::<SocketAddr>()?;

    let conn = Rc::new(RefCell::new(datenbank::schema_anlegen()?));

    LocalSet::new().block_on(
        &RuntimeBuilder::new_current_thread().enable_all().build()?,
        async move {
            let listener = TcpListener::bind(bind_addr).await?;

            loop {
                let (socket, _) = listener.accept().await?;

                let conn = conn.clone();

                spawn_local(async move {
                    if let Err(err) = ConnBuilder::new()
                        .timer(TokioTimer::new())
                        .serve_connection(
                            TokioIo::new(socket),
                            service_fn(move |req| {
                                let conn = conn.clone();

                                async move {
                                    match (req.method(), req.uri().path()) {
                                        (&Method::GET, "/ui/Pflegemittel") => {
                                            pflegemittel_anzeigen()
                                        }
                                        (&Method::GET, "/ui/NeueBestellung") => {
                                            neue_bestellung_anlegen()
                                        }

                                        (&Method::GET, "/api/anbieter") => {
                                            anbieter_laden(req.uri(), &conn)
                                        }

                                        (&Method::GET, "/api/pflegemittel") => {
                                            pflegemittel_laden(req.uri(), &conn)
                                        }
                                        (&Method::POST, "/api/pflegemittel") => {
                                            pflegemittel_speichern(req, &conn).await
                                        }

                                        (&Method::GET, "/api/bestellungen") => {
                                            bestellungen_laden(req.uri(), &conn)
                                        }
                                        (&Method::POST, "/api/bestellungen") => {
                                            bestellung_versenden(req, &conn).await
                                        }

                                        _ => Response::builder()
                                            .status(StatusCode::NOT_FOUND)
                                            .header(CONTENT_TYPE, "text/plain")
                                            .body("Method or path not found.".into())
                                            .map_err(Into::into),
                                    }
                                }
                            }),
                        )
                        .await
                    {
                        eprintln!("Unhandled internal error: {err}");
                    }
                });
            }
        },
    )
}

type Antwort = Fallible<Response<Full<Bytes>>>;

fn pflegemittel_anzeigen() -> Antwort {
    eingebette_seite_ausliefern(include_bytes!("../target/html/Pflegemittel.html.gz"))
}

fn neue_bestellung_anlegen() -> Antwort {
    eingebette_seite_ausliefern(include_bytes!("../target/html/NeueBestellung.html.gz"))
}

fn anbieter_laden(uri: &Uri, conn: &RefCell<Connection>) -> Antwort {
    anfrage_verarbeiten(uri, conn, |_, txn| datenbank::anbieter_laden(txn))
}

fn pflegemittel_laden(uri: &Uri, conn: &RefCell<Connection>) -> Antwort {
    anfrage_verarbeiten(uri, conn, |_, txn| datenbank::pflegemittel_laden(txn))
}

async fn pflegemittel_speichern(req: Request<Incoming>, conn: &RefCell<Connection>) -> Antwort {
    anfrage_mit_objekt_verarbeiten(req, conn, |_, pflegemittel, txn| {
        datenbank::pflegemittel_speichern(txn, pflegemittel, zeitstempel())?;
        datenbank::pflegemittel_laden(txn)
    })
    .await
}

fn bestellungen_laden(uri: &Uri, conn: &RefCell<Connection>) -> Antwort {
    anfrage_verarbeiten(uri, conn, |uri, txn| {
        let anbieter = parse_anbieter(uri)?;
        let bis_zu = parse_bis_zu(uri)?;

        datenbank::bestellungen_laden(txn, anbieter, bis_zu)
    })
}

async fn bestellung_versenden(req: Request<Incoming>, conn: &RefCell<Connection>) -> Antwort {
    anfrage_mit_objekt_verarbeiten(req, conn, |uri, bestellung, txn| {
        let anbieter = parse_anbieter(uri)?;
        let bis_zu = parse_bis_zu(uri)?;

        let bestellung = datenbank::bestellung_speichern(txn, bestellung, zeitstempel())?;
        versenden::bestellung_versenden(txn, bestellung)?;
        datenbank::bestellungen_laden(txn, anbieter, bis_zu)
    })
    .await
}

fn eingebette_seite_ausliefern(body: &'static [u8]) -> Antwort {
    Response::builder()
        .header(CONTENT_TYPE, "text/html")
        .header(CONTENT_ENCODING, "gzip")
        .body(Full::new(Bytes::from_static(body)))
        .map_err(Into::into)
}

fn anfrage_verarbeiten<T: Serialize, H: FnOnce(&Uri, &Transaction) -> Fallible<T>>(
    uri: &Uri,
    conn: &RefCell<Connection>,
    handler: H,
) -> Antwort {
    fehler_behandeln(in_transaktion_ausfuehren(uri, conn, handler))
}

async fn anfrage_mit_objekt_verarbeiten<
    S: DeserializeOwned,
    T: Serialize,
    H: 'static + Send + FnOnce(&Uri, S, &Transaction) -> Fallible<T>,
>(
    req: Request<Incoming>,
    conn: &RefCell<Connection>,
    handler: H,
) -> Antwort {
    let (parts, body) = req.into_parts();

    let obj = from_slice(&body.collect().await?.to_bytes())?;

    fehler_behandeln(in_transaktion_ausfuehren(
        &parts.uri,
        conn,
        move |uri, txn| handler(uri, obj, txn),
    ))
}

fn in_transaktion_ausfuehren<T: Serialize, H: FnOnce(&Uri, &Transaction) -> Fallible<T>>(
    uri: &Uri,
    conn: &RefCell<Connection>,
    handler: H,
) -> Antwort {
    let mut conn = conn.borrow_mut();
    let txn = conn.transaction()?;

    let body = to_vec(&handler(uri, &txn)?)?;

    txn.commit()?;

    Response::builder()
        .header(CONTENT_TYPE, "application/json")
        .body(body.into())
        .map_err(Into::into)
}

fn fehler_behandeln(resp: Antwort) -> Antwort {
    match resp {
        Ok(resp) => Ok(resp),

        Err(err) => {
            eprintln!("Internal server error: {err}");

            Response::builder()
                .status(StatusCode::INTERNAL_SERVER_ERROR)
                .header(CONTENT_TYPE, "text/plain")
                .body(err.to_string().into())
                .map_err(Into::into)
        }
    }
}

fn parse_anbieter(uri: &Uri) -> Fallible<i64> {
    parse_param(uri, "anbieter", 0)
}

fn parse_bis_zu(uri: &Uri) -> Fallible<u32> {
    parse_param(uri, "bis_zu", 1)
}

fn parse_param<T: FromStr<Err = ParseIntError>>(
    uri: &Uri,
    param: &'static str,
    def_val: T,
) -> Fallible<T> {
    if let Some(query) = uri.query() {
        for (key, val) in parse(query.as_bytes()) {
            if key == param {
                return Ok(val.parse()?);
            }
        }
    }

    Ok(def_val)
}

fn zeitstempel() -> i64 {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs()
        .try_into()
        .unwrap()
}
