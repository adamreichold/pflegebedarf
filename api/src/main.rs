extern crate ini;
extern crate rusqlite;
extern crate serde;
#[macro_use]
extern crate serde_derive;
extern crate serde_json;
extern crate time;
extern crate url;

mod cgi;
mod datenbank;
mod modell;
mod versenden;

use std::env::var;

use time::get_time;

use rusqlite::{Connection, Transaction};

use cgi::{die, read_from_stdin, write_to_stdout, Die};

use datenbank::{
    bestand_laden, bestellung_speichern, bestellungen_laden, create_schema, menge_laden,
    pflegemittel_laden, pflegemittel_speichern,
};

use versenden::bestellung_versenden;

fn main() {
    let method = var("REQUEST_METHOD").unwrap();
    let path = var("PATH_INFO").unwrap();

    let params = parse_params();

    let mut conn = Connection::open("/usr/lib/pflegebedarf/datenbank.sqlite")
        .die(500, "Konnte Datenbank nicht öffnen!");

    create_schema(&mut conn);

    let txn = conn.transaction().unwrap();

    match (method.as_str(), path.as_str()) {
        ("GET", "/pflegemittel") => get_pflegemittel(&txn),

        ("POST", "/pflegemittel") => post_pflegemittel(&txn),

        ("GET", "/bestellungen") => get_bestellungen(&txn, &params),

        ("POST", "/bestellungen") => post_bestellungen(&txn, &params),

        ("GET", "/pflegemittel_bestand") => get_bestand(&txn, &params),

        ("GET", "/bestellungen_menge") => get_menge(&txn, &params),

        _ => die(404, "Methode oder Pfad werden nicht unterstützt!"),
    };

    txn.commit().unwrap();
}

fn get_pflegemittel(txn: &Transaction) {
    write_to_stdout(&pflegemittel_laden(txn))
}

fn post_pflegemittel(txn: &Transaction) {
    pflegemittel_speichern(txn, read_from_stdin(), get_time().sec);

    get_pflegemittel(txn);
}

fn get_bestellungen(txn: &Transaction, params: &Params) {
    write_to_stdout(&bestellungen_laden(txn, params.limit))
}

fn post_bestellungen(txn: &Transaction, params: &Params) {
    bestellung_versenden(
        txn,
        bestellung_speichern(txn, read_from_stdin(), get_time().sec),
    );

    get_bestellungen(txn, params);
}

fn get_bestand(txn: &Transaction, params: &Params) {
    write_to_stdout(&bestand_laden(txn, params.id))
}

fn get_menge(txn: &Transaction, params: &Params) {
    write_to_stdout(&menge_laden(txn, params.id))
}

struct Params {
    id: Option<i64>,
    limit: Option<u32>,
}

fn parse_params() -> Params {
    let mut params = Params {
        id: None,
        limit: None,
    };

    var("QUERY_STRING").ok().map(|query| {
        url::form_urlencoded::parse(query.as_bytes()).for_each(|(key, value)| {
            match key.as_ref() {
                "id" => {
                    params.id = value.parse().ok();
                }

                "limit" => {
                    params.limit = value.parse().ok();
                }

                _ => {}
            };
        })
    });

    params
}
