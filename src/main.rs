#![feature(plugin, custom_derive)]
#![plugin(rocket_codegen)]
#![recursion_limit = "1024"]

extern crate rocket;
extern crate rocket_contrib;

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

extern crate regex;
#[macro_use]
extern crate lazy_static;

use std::alloc::System;
use std::io::Cursor;
use std::sync::Mutex;

use rocket::http::hyper::header::{ContentEncoding, Encoding};
use rocket::http::ContentType;
use rocket::response::Response;
use rocket::State;
use rocket_contrib::Json;

use rusqlite::{Connection, Transaction};

use time::get_time;

mod datenbank;
mod modell;
mod versenden;

#[global_allocator]
static ALLOC: System = System;

mod errors {
    error_chain! {
        foreign_links {
            Io(::std::io::Error);
            SQLite(::rusqlite::Error);
            Yaml(::serde_yaml::Error);
            LettreSmtp(::lettre::smtp::error::Error);
            LettreEmail(::lettre_email::error::Error);
        }
    }
}

use errors::*;

fn main() {
    let conn = datenbank::schema_anlegen().expect("Konnte Datenbankschema nicht anlegen.");

    rocket::ignite()
        .manage(Mutex::new(conn))
        .mount(
            "/ui",
            routes![pflegemittel_anzeigen, neue_bestellung_anlegen],
        ).mount(
            "/api",
            routes![
                pflegemittel_laden,
                pflegemittel_speichern,
                bestellungen_laden,
                bestellung_versenden
            ],
        ).launch();
}

#[get("/Pflegemittel")]
fn pflegemittel_anzeigen() -> Response<'static> {
    eingebette_seite_ausliefern(include_bytes!("../ui/html/Pflegemittel.html.gz"))
}

#[get("/NeueBestellung")]
fn neue_bestellung_anlegen() -> Response<'static> {
    eingebette_seite_ausliefern(include_bytes!("../ui/html/NeueBestellung.html.gz"))
}

fn eingebette_seite_ausliefern(body: &[u8]) -> Response {
    Response::build()
        .header(ContentType::HTML)
        .header(ContentEncoding(vec![Encoding::Gzip]))
        .sized_body(Cursor::new(body))
        .finalize()
}

#[get("/pflegemittel")]
fn pflegemittel_laden(conn: State<Mutex<Connection>>) -> Result<Json<Vec<modell::Pflegemittel>>> {
    anfrage_verarbeiten(&conn, |txn| Ok(datenbank::pflegemittel_laden(txn)?))
}

#[post("/pflegemittel", data = "<pflegemittel>")]
fn pflegemittel_speichern(
    conn: State<Mutex<Connection>>,
    pflegemittel: Json<Vec<modell::Pflegemittel>>,
) -> Result<Json<Vec<modell::Pflegemittel>>> {
    anfrage_verarbeiten(&conn, |txn| {
        datenbank::pflegemittel_speichern(txn, pflegemittel.into_inner(), get_time().sec)?;
        Ok(datenbank::pflegemittel_laden(txn)?)
    })
}

#[get("/bestellungen?<limit>")]
fn bestellungen_laden(
    conn: State<Mutex<Connection>>,
    limit: Limit,
) -> Result<Json<Vec<modell::Bestellung>>> {
    anfrage_verarbeiten(&conn, |txn| {
        Ok(datenbank::bestellungen_laden(txn, limit.limit)?)
    })
}

#[post("/bestellungen?<limit>", data = "<bestellung>")]
fn bestellung_versenden(
    conn: State<Mutex<Connection>>,
    bestellung: Json<modell::Bestellung>,
    limit: Limit,
) -> Result<Json<Vec<modell::Bestellung>>> {
    anfrage_verarbeiten(&conn, |txn| {
        let bestellung =
            datenbank::bestellung_speichern(txn, bestellung.into_inner(), get_time().sec)?;
        versenden::bestellung_versenden(txn, bestellung)?;
        Ok(datenbank::bestellungen_laden(txn, limit.limit)?)
    })
}

#[derive(Clone, Copy, FromForm)]
struct Limit {
    limit: Option<u32>,
}

fn anfrage_verarbeiten<T, F: FnOnce(&Transaction) -> Result<T>>(
    conn: &Mutex<Connection>,
    f: F,
) -> Result<Json<T>> {
    let mut conn = conn.lock().unwrap();
    let txn = conn.transaction()?;

    let t = f(&txn)?;

    txn.commit()?;

    Ok(Json(t))
}
