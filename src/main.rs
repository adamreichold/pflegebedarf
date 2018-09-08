#![recursion_limit = "1024"]

extern crate bodyparser;
extern crate iron;
extern crate persistent;
extern crate router;
extern crate urlencoded;

extern crate serde;
#[macro_use]
extern crate serde_derive;
extern crate serde_json;
extern crate serde_yaml;

extern crate lettre;
extern crate lettre_email;

extern crate rusqlite;

extern crate time;

#[macro_use]
extern crate error_chain;

use bodyparser::Struct;
use iron::headers::{ContentEncoding, ContentType, Encoding};
use iron::prelude::*;
use iron::status::Status;
use iron::typemap::Key;
use persistent::Write;
use router::Router;
use urlencoded::UrlEncodedQuery;

use serde::Serialize;
use serde_json::to_vec;

use rusqlite::{Connection, Transaction};

use time::get_time;

mod datenbank;
mod modell;
mod versenden;

#[global_allocator]
static ALLOC: ::std::alloc::System = ::std::alloc::System;

mod errors {
    error_chain! {
        foreign_links {
            Io(::std::io::Error);
            SQLite(::rusqlite::Error);
            Json(::serde_json::Error);
            Yaml(::serde_yaml::Error);
            LettreSmtp(::lettre::smtp::error::Error);
            LettreEmail(::lettre_email::error::Error);
            Http(::iron::error::HttpError);
            Url(::urlencoded::UrlDecodingError);
            Body(::bodyparser::BodyError);
            ParseInt(::std::num::ParseIntError);
        }
    }
}

use errors::{Error, Result};

impl From<Error> for ::iron::error::IronError {
    fn from(err: Error) -> Self {
        let mut resp = ::iron::Response::new();

        resp.status = Some(Status::BadRequest);
        resp.headers.set(ContentType::plaintext());
        resp.body = Some(Box::new(err.to_string()));

        Self {
            error: Box::new(err),
            response: resp,
        }
    }
}

fn main() -> Result<()> {
    let conn = datenbank::schema_anlegen()?;

    let mut router = Router::new();

    router.get(
        "/ui/Pflegemittel",
        pflegemittel_anzeigen,
        "pflegemittel_anzeigen",
    );
    router.get(
        "/ui/NeueBestellung",
        neue_bestellung_anlegen,
        "neue_bestellung_anlegen",
    );

    router.get("/api/anbieter", anbieter_laden, "anbieter_laden");

    router.get(
        "/api/pflegemittel",
        pflegemittel_laden,
        "pflegemittel_laden",
    );
    router.post(
        "/api/pflegemittel",
        pflegemittel_speichern,
        "pflegemittel_speichern",
    );

    router.get(
        "/api/bestellungen",
        bestellungen_laden,
        "bestellungen_laden",
    );
    router.post(
        "/api/bestellungen",
        bestellung_versenden,
        "bestellungen_versenden",
    );

    let mut chain = Chain::new(router);

    chain.link_before(Write::<Database>::one(conn));

    let mut server = Iron::new(chain);

    server.threads = 1;
    server.http(("0.0.0.0", 8080))?;

    Ok(())
}

fn pflegemittel_anzeigen(_: &mut Request) -> IronResult<Response> {
    eingebette_seite_ausliefern(include_bytes!("../ui/html/Pflegemittel.html.gz"))
}

fn neue_bestellung_anlegen(_: &mut Request) -> IronResult<Response> {
    eingebette_seite_ausliefern(include_bytes!("../ui/html/NeueBestellung.html.gz"))
}

fn anbieter_laden(req: &mut Request) -> IronResult<Response> {
    anfrage_verarbeiten(req, |_, txn| datenbank::anbieter_laden(txn))
}

fn pflegemittel_laden(req: &mut Request) -> IronResult<Response> {
    anfrage_verarbeiten(req, |_, txn| datenbank::pflegemittel_laden(txn))
}

fn pflegemittel_speichern(req: &mut Request) -> IronResult<Response> {
    anfrage_verarbeiten(req, |req, txn| {
        match req.get::<Struct<Vec<modell::Pflegemittel>>>()? {
            None => bail!("Keine Pflegemittel übertragen."),
            Some(pflegemittel) => {
                datenbank::pflegemittel_speichern(txn, pflegemittel, get_time().sec)?;
            }
        }

        datenbank::pflegemittel_laden(txn)
    })
}

fn bestellungen_laden(req: &mut Request) -> IronResult<Response> {
    anfrage_verarbeiten(req, |req, txn| {
        let anbieter = parse_anbieter(req)?;
        let bis_zu = parse_bis_zu(req)?;

        datenbank::bestellungen_laden(txn, anbieter, bis_zu)
    })
}

fn bestellung_versenden(req: &mut Request) -> IronResult<Response> {
    anfrage_verarbeiten(req, |req, txn| {
        let anbieter = parse_anbieter(req)?;
        let bis_zu = parse_bis_zu(req)?;

        match req.get::<Struct<modell::Bestellung>>()? {
            None => bail!("Keine Bestellung übermittelt."),
            Some(bestellung) => {
                let bestellung = datenbank::bestellung_speichern(txn, bestellung, get_time().sec)?;

                versenden::bestellung_versenden(txn, bestellung)?;
            }
        }

        datenbank::bestellungen_laden(txn, anbieter, bis_zu)
    })
}

fn eingebette_seite_ausliefern(body: &'static [u8]) -> IronResult<Response> {
    let mut resp = Response::new();

    resp.status = Some(Status::Ok);
    resp.body = Some(Box::new(body));
    resp.headers.set(ContentType::html());
    resp.headers.set(ContentEncoding(vec![Encoding::Gzip]));

    Ok(resp)
}

fn anfrage_verarbeiten<T: Serialize, F: FnOnce(&mut Request, &Transaction) -> Result<T>>(
    req: &mut Request,
    f: F,
) -> IronResult<Response> {
    fn anfrage_verarbeiten1<T1: Serialize, F1: FnOnce(&mut Request, &Transaction) -> Result<T1>>(
        req: &mut Request,
        f: F1,
    ) -> Result<Response> {
        let db = req.get::<Write<Database>>().unwrap();
        let mut conn = db.lock().unwrap();
        let txn = conn.transaction()?;

        let t = f(req, &txn)?;

        txn.commit()?;

        let mut resp = Response::new();

        resp.status = Some(Status::Ok);
        resp.body = Some(Box::new(to_vec(&t)?));
        resp.headers.set(ContentType::json());

        Ok(resp)
    }

    Ok(anfrage_verarbeiten1(req, f)?)
}

fn parse_anbieter(req: &mut Request) -> Result<i64> {
    let params = req.get_ref::<UrlEncodedQuery>()?;

    if let Some(vals) = params.get("anbieter") {
        return Ok(vals.first().unwrap().parse()?);
    }

    Ok(0)
}

fn parse_bis_zu(req: &mut Request) -> Result<u32> {
    let params = req.get_ref::<UrlEncodedQuery>()?;

    if let Some(vals) = params.get("bis_zu") {
        return Ok(vals.first().unwrap().parse()?);
    }

    Ok(1)
}

struct Database;

impl Key for Database {
    type Value = Connection;
}
