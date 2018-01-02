#![ feature( conservative_impl_trait ) ]

extern crate time;
extern crate url;
extern crate rusqlite;
extern crate serde;
#[ macro_use ]
extern crate serde_derive;
extern crate serde_json;


use std::io::prelude::*;

use std::io::{ stdout, stdin };
use std::env::var;

use time::get_time;

use rusqlite::{ Connection, Transaction, Statement, Row };
use rusqlite::types::ToSql;

use serde::Serialize;
use serde_json::{ to_writer, from_reader };


#[ derive( Serialize, Deserialize ) ]
struct Pflegemittel {
    id: Option< i64 >,
    bezeichnung: String,
    einheit: String,
    hersteller_und_produkt: String,
    pzn_oder_ref: String,
    geplanter_verbrauch: u32,
    vorhandene_menge: u32,
    wird_verwendet: bool
}

#[ derive( Serialize, Deserialize ) ]
struct Bestellung {
    id: Option< i64 >,
    empfaenger: String,
    nachricht: String,
    posten: Vec< Posten >
}

#[ derive( Serialize, Deserialize ) ]
struct Posten {
    pflegemittel_id: i64,
    menge: u32
}

#[ derive( Serialize, Deserialize ) ]
struct Bestand {
    zeitstempel: i64,
    geplanter_verbrauch: u32,
    vorhandene_menge: u32
}

#[ derive( Serialize, Deserialize ) ]
struct Menge {
    zeitstempel: i64,
    menge: u32
}


fn create_schema( conn: &mut Connection ) {

    let user_version: u32 = conn.query_row( "PRAGMA user_version", &[], | row | row.get( 0 ) ).unwrap();

    match user_version {

        0 => {

            let txn = conn.transaction().unwrap();

            txn.execute_batch( r#"
CREATE TABLE pflegemittel (
    id INTEGER PRIMARY KEY,
    bezeichnung TEXT NOT NULL,
    einheit TEXT NOT NULL,
    hersteller_und_produkt TEXT NOT NULL,
    pzn_oder_ref TEXT NOT NULL,
    wird_verwendet INTEGER NOT NULL
);

CREATE TABLE pflegemittel_bestand (
    pflegemittel_id INTEGER,
    zeitstempel INTEGER,
    geplanter_verbrauch INTEGER NOT NULL,
    vorhandene_menge INTEGER NOT NULL,
    PRIMARY KEY (pflegemittel_id, zeitstempel),
    FOREIGN KEY (pflegemittel_id) REFERENCES pflegemittel (id)
);

CREATE TABLE bestellungen (
    id INTEGER PRIMARY KEY,
    zeitstempel INTEGER NOT NULL,
    empfaenger TEXT NOT NULL,
    nachricht TEXT NOT NULL
);

CREATE TABLE bestellungen_posten (
    bestellung_id INTEGER,
    pflegemittel_id INTEGER,
    menge INTEGER NOT NULL,
    PRIMARY KEY (bestellung_id, pflegemittel_id),
    FOREIGN KEY (bestellung_id) REFERENCES bestellungen (id),
    FOREIGN KEY (pflegemittel_id) REFERENCES pflegemittel (id)
);

PRAGMA user_version = 6;

                "# ).unwrap();

            txn.commit().unwrap();

        },

        6 => {
            return;
        }

        _ => {
            panic!( "Unsupported schema version!" );
        }

    };
}

fn write_to_stdout< T >( value: &T ) where T: Serialize {

    let mut writer = stdout();

    writer.write_all( b"Content-Type: application/json; charset=utf8\n\n" ).unwrap();

    to_writer( writer, value ).unwrap();
}

fn collect_rows< T, F >( stmt: &mut Statement, params: &[ &ToSql ], f: F ) -> Vec< T > where F: FnMut( &Row ) -> T {

    stmt.query_map( params, f ).unwrap().filter_map( Result::ok ).collect()
}


fn pflegemittel_laden( txn: &Transaction ) {

    let mut stmt = txn.prepare( r#"
WITH groesste_zeitstempel AS (
    SELECT pflegemittel_id, MAX(zeitstempel) AS zeitstempel
    FROM pflegemittel_bestand GROUP BY pflegemittel_id
)
SELECT pm.*, pmb.geplanter_verbrauch, pmb.vorhandene_menge
FROM pflegemittel pm, pflegemittel_bestand pmb, groesste_zeitstempel gzs
WHERE pm.id = pmb.pflegemittel_id
AND pmb.pflegemittel_id = gzs.pflegemittel_id AND pmb.zeitstempel = gzs.zeitstempel
        "# ).unwrap();

    let pflegemittel = collect_rows( &mut stmt, &[], | row | {

        Pflegemittel {
            id: Some( row.get( "id" ) ),
            bezeichnung: row.get( "bezeichnung" ),
            einheit: row.get( "einheit" ),
            hersteller_und_produkt: row.get( "hersteller_und_produkt" ),
            pzn_oder_ref: row.get( "pzn_oder_ref" ),
            geplanter_verbrauch: row.get( "geplanter_verbrauch" ),
            vorhandene_menge: row.get( "vorhandene_menge" ),
            wird_verwendet: row.get( "wird_verwendet" )
        }

    } );

    write_to_stdout( &pflegemittel );
}

fn pflegemittel_speichern( txn: &Transaction ) {

    let pflegemittel: Vec< Pflegemittel > = from_reader( stdin() ).unwrap();

    let zeitstempel = get_time().sec;

    let mut pm_stmt = txn.prepare( "INSERT OR REPLACE INTO pflegemittel VALUES (?, ?, ?, ?, ?, ?)" ).unwrap();

    let mut pmb_stmt = txn.prepare( "INSERT INTO pflegemittel_bestand VALUES (?, ?, ?, ?)" ).unwrap();

    for mut pm in pflegemittel.into_iter() {

        pm_stmt.execute( &[ &pm.id, &pm.bezeichnung, &pm.einheit, &pm.hersteller_und_produkt, &pm.pzn_oder_ref, &pm.wird_verwendet ] ).unwrap();

        pm.id = Some( txn.last_insert_rowid() );

        pmb_stmt.execute( &[ &pm.id, &zeitstempel, &pm.geplanter_verbrauch, &pm.vorhandene_menge ] ).unwrap();
    }

    pflegemittel_laden( txn );
}

fn bestellungen_laden( txn: &Transaction, limit: u32 ) {

    let mut b_stmt = txn.prepare( "SELECT b.* FROM bestellungen b ORDER BY b.zeitstempel DESC LIMIT ?" ).unwrap();

    let mut bp_stmt = txn.prepare( "SELECT bp.pflegemittel_id, bp.menge FROM bestellungen_posten bp WHERE bp.bestellung_id = ?" ).unwrap();

    let bestellungen = collect_rows( &mut b_stmt, &[ &limit ], | row | {

        let id: i64 = row.get( "id" );

        let posten = collect_rows( &mut bp_stmt, &[ &id ], | row | {

            Posten{
                pflegemittel_id: row.get( "pflegemittel_id" ),
                menge: row.get( "menge" )
            }

        } );

        Bestellung{
            id: Some( id ),
            empfaenger: row.get( "empfaenger" ),
            nachricht: row.get( "nachricht" ),
            posten: posten
        }

    } );

    write_to_stdout( &bestellungen );
}

fn bestellung_speichern( txn: &Transaction, limit: u32 ) {

    let mut bestellung: Bestellung = from_reader( stdin() ).unwrap();

    let zeitstempel = get_time().sec;

    let mut b_stmt = txn.prepare( "INSERT INTO bestellungen VALUES (?, ?, ?, ?)" ).unwrap();

    let mut bp_stmt = txn.prepare( "INSERT INTO bestellungen_posten VALUES (?, ?, ?)" ).unwrap();

    bestellung.id = None;

    b_stmt.execute( &[ &bestellung.id, &zeitstempel, &bestellung.empfaenger, &bestellung.nachricht ] ).unwrap();

    bestellung.id = Some( txn.last_insert_rowid() );

    for posten in bestellung.posten.iter() {

        bp_stmt.execute( &[ &bestellung.id, &posten.pflegemittel_id, &posten.menge ] ).unwrap();
    }

    // TODO: bestellung_versenden

    bestellungen_laden( txn, limit );
}

fn bestand_laden( txn: &Transaction, id: i64 ) {

    let mut stmt = txn.prepare( "SELECT zeitstempel, geplanter_verbrauch, vorhandene_menge FROM pflegemittel_bestand WHERE pflegemittel_id = ? ORDER BY zeitstempel" ).unwrap();

    let bestand = collect_rows( &mut stmt, &[ &id ], | row | {

        Bestand {
            zeitstempel: row.get( "zeitstempel" ),
            geplanter_verbrauch: row.get( "geplanter_verbrauch" ),
            vorhandene_menge: row.get( "vorhandene_menge" )
        }

    } );

    write_to_stdout( &bestand );
}

fn menge_laden( txn: &Transaction, id: i64 ) {

    let mut stmt = txn.prepare( r#"
SELECT b.zeitstempel, bp.menge
FROM bestellungen b, bestellungen_posten bp
WHERE bp.bestellung_id = b.id AND bp.pflegemittel_id = ?
ORDER BY b.zeitstempel
        "# ).unwrap();

    let menge = collect_rows( &mut stmt, &[ &id ], | row | {

        Menge{
            zeitstempel: row.get( "zeitstempel" ),
            menge: row.get( "menge" )
        }

    } );

    write_to_stdout( &menge );
}


struct Params {
    id: Option< i64 >,
    limit: Option< u32 >
}

fn parse_params() -> Params {

    let mut params = Params {
        id: None,
        limit: None
    };

    var( "QUERY_STRING" ).ok().map(
        | query | url::form_urlencoded::parse( query.as_bytes() ).for_each(
            | ( key, value ) | {
                match key.as_ref() {

                    "id" => {
                        params.id = value.parse().ok();
                    }

                    "limit" => {
                        params.limit = value.parse().ok();
                    }

                    _ => {}

                };
            }
        )
    );

    params
}

fn main() {

    let method = var( "REQUEST_METHOD" ).unwrap();
    let path = var( "PATH_INFO" ).unwrap();

    let params = parse_params();

    let mut conn = Connection::open( "/usr/lib/pflegebedarf/datenbank.sqlite" ).unwrap();

    create_schema( &mut conn );

    let txn = conn.transaction().unwrap();

    match ( method.as_str(), path.as_str() ) {

        ( "GET", "/pflegemittel" ) => pflegemittel_laden( &txn ),

        ( "POST", "/pflegemittel" ) => pflegemittel_speichern( &txn ),

        ( "GET", "/bestellungen" ) => bestellungen_laden( &txn, params.limit.unwrap_or( 1 ) ),

        ( "POST", "/bestellungen" ) => bestellung_speichern( &txn, params.limit.unwrap_or( 1 ) ),

        ( "GET", "/pflegemittel_bestand" ) => bestand_laden( &txn, params.id.unwrap() ),

        ( "GET", "/bestellungen_menge" ) => menge_laden( &txn, params.id.unwrap() ),

        _ => panic!( "Unsupported method or path!" )

    };

    txn.commit().unwrap();
}
