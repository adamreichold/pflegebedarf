#![ feature( conservative_impl_trait ) ]

extern crate time;
extern crate url;
extern crate rusqlite;
extern crate serde;
#[ macro_use ]
extern crate serde_derive;
extern crate serde_json;
extern crate ini;


use std::io::{ stdout, stdin };
use std::env::var;
use std::process::{ Command, Stdio };

use time::{ Timespec, get_time, at, strftime };

use rusqlite::{ Connection, Transaction, Statement, Row };
use rusqlite::types::ToSql;

use serde::Serialize;
use serde_json::{ to_writer, from_reader };

use ini::Ini;


#[ derive( Serialize, Deserialize ) ]
struct Pflegemittel {
    id: Option< i64 >,
    zeitstempel: Option< i64 >,
    bezeichnung: String,
    einheit: String,
    hersteller_und_produkt: String,
    pzn_oder_ref: String,
    geplanter_verbrauch: u32,
    vorhandene_menge: u32,
    wird_verwendet: bool
}

impl Pflegemittel {

    fn from_row( row: &Row ) -> Pflegemittel {

        Pflegemittel {
            id: Some( row.get( "id" ) ),
            zeitstempel: row.get( "zeitstempel" ),
            bezeichnung: row.get( "bezeichnung" ),
            einheit: row.get( "einheit" ),
            hersteller_und_produkt: row.get( "hersteller_und_produkt" ),
            pzn_oder_ref: row.get( "pzn_oder_ref" ),
            geplanter_verbrauch: row.get( "geplanter_verbrauch" ),
            vorhandene_menge: row.get( "vorhandene_menge" ),
            wird_verwendet: row.get( "wird_verwendet" )
        }
    }
}

#[ derive( Serialize, Deserialize ) ]
struct Bestellung {
    id: Option< i64 >,
    zeitstempel: Option< i64 >,
    empfaenger: String,
    nachricht: String,
    posten: Vec< Posten >
}

impl Bestellung {

    fn from_row( row: &Row ) -> Bestellung {

        Bestellung{
            id: Some( row.get( "id" ) ),
            zeitstempel: row.get( "zeitstempel" ),
            empfaenger: row.get( "empfaenger" ),
            nachricht: row.get( "nachricht" ),
            posten: Vec::new()
        }
    }
}

#[ derive( Serialize, Deserialize ) ]
struct Posten {
    pflegemittel_id: i64,
    menge: u32
}

impl Posten {

    fn from_row( row: &Row ) -> Posten {

        Posten{
            pflegemittel_id: row.get( "pflegemittel_id" ),
            menge: row.get( "menge" )
        }
    }
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
            die( 500, "Unbekannte Version der Datenbank!" );
        }

    };
}

trait Die< T > {

    fn die( self, status: i32, msg: &'static str ) -> T;
}

impl< T > Die< T > for Option< T > {

    fn die( self, status: i32, msg: &'static str ) -> T {

        match self {

            Some( t ) => t,

            None => die( status, msg )
        }
    }
}

impl< V, E > Die< V > for Result< V, E > {

    fn die( self, status: i32, msg: &'static str ) -> V {

        match self {

            Ok( v ) => v,

            Err( _ ) => die( status, msg )
        }
    }
}

fn die( status: i32, msg: &'static str ) -> ! {

    use std::io::Write;

    let mut writer = stdout();

    write!( &mut writer, "Content-Type: text/plain; charset=utf8\r\nStatus: {}\r\n\r\n{}", status, msg ).unwrap();

    panic!( msg )
}

fn write_to_stdout< T >( value: &T ) where T: Serialize {

    use std::io::Write;

    let mut writer = stdout();

    writer.write_all( b"Content-Type: application/json; charset=utf8\r\n\r\n" ).unwrap();

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
SELECT pm.*, pmb.zeitstempel, pmb.geplanter_verbrauch, pmb.vorhandene_menge
FROM pflegemittel pm, pflegemittel_bestand pmb, groesste_zeitstempel gzs
WHERE pm.id = pmb.pflegemittel_id
AND pmb.pflegemittel_id = gzs.pflegemittel_id AND pmb.zeitstempel = gzs.zeitstempel
        "# ).unwrap();

    let pflegemittel = collect_rows( &mut stmt, &[], Pflegemittel::from_row );

    write_to_stdout( &pflegemittel );
}

fn pflegemittel_speichern( txn: &Transaction ) {

    let pflegemittel: Vec< Pflegemittel > = from_reader( stdin() ).die( 400, "Konnte JSON-Darstellung nicht verarbeiten." );

    let zeitstempel = get_time().sec;

    let mut pm_stmt = txn.prepare( "INSERT OR REPLACE INTO pflegemittel VALUES (?, ?, ?, ?, ?, ?)" ).unwrap();

    let mut pmb_stmt = txn.prepare( "INSERT INTO pflegemittel_bestand VALUES (?, ?, ?, ?)" ).unwrap();

    for mut pm in pflegemittel.into_iter() {

        pm_stmt.execute( &[ &pm.id, &pm.bezeichnung, &pm.einheit, &pm.hersteller_und_produkt, &pm.pzn_oder_ref, &pm.wird_verwendet ] ).unwrap();

        pm.id = Some( txn.last_insert_rowid() );
        pm.zeitstempel = Some( zeitstempel );

        pmb_stmt.execute( &[ &pm.id, &pm.zeitstempel, &pm.geplanter_verbrauch, &pm.vorhandene_menge ] ).unwrap();
    }

    pflegemittel_laden( txn );
}

fn bestellungen_laden( txn: &Transaction, limit: Option< u32 > ) {

    let limit = limit.unwrap_or( 1 );

    let mut b_stmt = txn.prepare( "SELECT b.* FROM bestellungen b ORDER BY b.zeitstempel DESC LIMIT ?" ).unwrap();

    let mut bp_stmt = txn.prepare( "SELECT bp.pflegemittel_id, bp.menge FROM bestellungen_posten bp WHERE bp.bestellung_id = ?" ).unwrap();

    let bestellungen = collect_rows( &mut b_stmt, &[ &limit ], | row | {

        let mut bestellung = Bestellung::from_row( row );

        bestellung.posten = collect_rows( &mut bp_stmt, &[ &bestellung.id ], Posten::from_row );

        bestellung

    } );

    write_to_stdout( &bestellungen );
}

fn bestellung_speichern( txn: &Transaction, limit: Option< u32 > ) {

    let mut bestellung: Bestellung = from_reader( stdin() ).die( 400, "Konnte JSON-Darstellung nicht verarbeiten." );

    let zeitstempel = get_time().sec;

    let mut b_stmt = txn.prepare( "INSERT INTO bestellungen VALUES (?, ?, ?, ?)" ).unwrap();

    let mut bp_stmt = txn.prepare( "INSERT INTO bestellungen_posten VALUES (?, ?, ?)" ).unwrap();

    bestellung.id = None;
    bestellung.zeitstempel = Some( zeitstempel );

    b_stmt.execute( &[ &bestellung.id, &bestellung.zeitstempel, &bestellung.empfaenger, &bestellung.nachricht ] ).unwrap();

    bestellung.id = Some( txn.last_insert_rowid() );

    for posten in bestellung.posten.iter() {

        bp_stmt.execute( &[ &bestellung.id, &posten.pflegemittel_id, &posten.menge ] ).unwrap();
    }

    bestellung_versenden( txn, bestellung );

    bestellungen_laden( txn, limit );
}

fn bestellung_versenden( txn: &Transaction, bestellung: Bestellung ) {

    use std::io::Write;

    let mut config = Ini::load_from_file( "/usr/lib/pflegebedarf/versenden.ini" ).die( 500, "Konnte Konfiguration für Versand nicht verarbeiten." );

    let config = config.general_section_mut();

    let datum = strftime( "%d.%m.%Y", &at( Timespec::new( bestellung.zeitstempel.unwrap(), 0 ) ) ).unwrap();
    let betreff = config.remove( "betreff" ).unwrap().replace( "{datum}", &datum );

    let von = config.remove( "von" ).unwrap();
    let antwort = config.remove( "antwort" ).unwrap();
    let kopien = config.remove( "kopien" ).unwrap();

    if !bestellung.nachricht.contains( "{posten}" ) {
        die( 400, "Die Nachricht muss den Platzhalter {posten} enthalten." );
    }

    let posten = posten_formatieren( txn, bestellung.posten );
    let nachricht = bestellung.nachricht.replace( "{posten}", &posten );

    let mut sendmail = Command::new( "sendmail" ).arg( bestellung.empfaenger ).stdin( Stdio::piped() ).spawn().unwrap();

    {
        let stdin = sendmail.stdin.as_mut().unwrap();

        write!( stdin, "From: {}", von ).unwrap();
        write!( stdin, "\r\nReply-To: {}", antwort ).unwrap();

        for kopie in kopien.split( ',' ) {
            write!( stdin, "\r\nCc: {}", kopie ).unwrap();
        }

        write!( stdin, "\r\nSubject: {}", betreff ).unwrap();

        write!( stdin, "\r\n\r\n{}", nachricht ).unwrap();
    }

    if !sendmail.wait().unwrap().success() {
        die( 500, "Konnte Bestellung nicht versenden." );
    }
}

fn posten_formatieren( txn: &Transaction, posten: Vec< Posten > ) -> String {

    use std::fmt::Write;

    let mut stichpunkte = String::new();

    let mut stmt = txn.prepare( r#"
SELECT pm.*, pmb.zeitstempel, pmb.geplanter_verbrauch, pmb.vorhandene_menge
FROM pflegemittel pm, pflegemittel_bestand pmb
WHERE pm.id = ? AND pm.id = pmb.pflegemittel_id
ORDER BY pmb.zeitstempel DESC LIMIT 1
        "# ).unwrap();

    let mut anstrich = "*";

    for p in posten.into_iter() {

        if p.menge < 1 {
            continue;
        }

        let pm = stmt.query_row( &[ &p.pflegemittel_id ], Pflegemittel::from_row ).unwrap();

        write!( &mut stichpunkte, "{} {} {} {}", &anstrich, p.menge, pm.einheit, pm.bezeichnung ).unwrap();

        let hersteller_und_produkt_gesetzt = !pm.hersteller_und_produkt.is_empty();
        let pzn_oder_ref_gesetzt = !pm.pzn_oder_ref.is_empty();

        if hersteller_und_produkt_gesetzt && pzn_oder_ref_gesetzt {
            write!( &mut stichpunkte, " ({} {})", pm.hersteller_und_produkt, pm.pzn_oder_ref ).unwrap();
        } else if hersteller_und_produkt_gesetzt {
            write!( &mut stichpunkte, " ({})", pm.hersteller_und_produkt ).unwrap();
        } else if pzn_oder_ref_gesetzt {
            write!( &mut stichpunkte, " ({})", pm.pzn_oder_ref ).unwrap();
        }

        anstrich = "\n\n*";
    }

    stichpunkte
}

fn bestand_laden( txn: &Transaction, id: Option< i64 > ) {

    let id = id.die( 400, "Der Parameter id fehlt oder konnte nicht verarbeitet werden." );

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

fn menge_laden( txn: &Transaction, id: Option< i64 > ) {

    let id = id.die( 400, "Der Parameter id fehlt oder konnte nicht verarbeitet werden." );

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

    let mut conn = Connection::open( "/usr/lib/pflegebedarf/datenbank.sqlite" ).die( 500, "Konnte Datenbank nicht öffnen!" );

    create_schema( &mut conn );

    let txn = conn.transaction().unwrap();

    match ( method.as_str(), path.as_str() ) {

        ( "GET", "/pflegemittel" ) => pflegemittel_laden( &txn ),

        ( "POST", "/pflegemittel" ) => pflegemittel_speichern( &txn ),

        ( "GET", "/bestellungen" ) => bestellungen_laden( &txn, params.limit ),

        ( "POST", "/bestellungen" ) => bestellung_speichern( &txn, params.limit ),

        ( "GET", "/pflegemittel_bestand" ) => bestand_laden( &txn, params.id ),

        ( "GET", "/bestellungen_menge" ) => menge_laden( &txn, params.id ),

        _ => die( 404, "Methode oder Pfad werden nicht unterstützt!" )

    };

    txn.commit().unwrap();
}
