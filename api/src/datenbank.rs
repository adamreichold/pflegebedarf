use rusqlite::types::ToSql;
use rusqlite::{Connection, Row, Statement, Transaction};

use super::cgi::Die;
use super::modell::{Bestand, Bestellung, Menge, Pflegemittel, Posten};

trait FromRow {
    fn from_row(row: &Row) -> Self;
}

impl FromRow for Pflegemittel {
    fn from_row(row: &Row) -> Self {
        Self {
            id: Some(row.get("id")),
            zeitstempel: row.get("zeitstempel"),
            bezeichnung: row.get("bezeichnung"),
            einheit: row.get("einheit"),
            hersteller_und_produkt: row.get("hersteller_und_produkt"),
            pzn_oder_ref: row.get("pzn_oder_ref"),
            geplanter_verbrauch: row.get("geplanter_verbrauch"),
            vorhandene_menge: row.get("vorhandene_menge"),
            wird_verwendet: row.get("wird_verwendet"),
            wurde_gezaehlt: row.get("wurde_gezaehlt"),
        }
    }
}

impl FromRow for Bestellung {
    fn from_row(row: &Row) -> Self {
        Self {
            id: Some(row.get("id")),
            zeitstempel: row.get("zeitstempel"),
            empfaenger: row.get("empfaenger"),
            nachricht: row.get("nachricht"),
            posten: Vec::new(),
        }
    }
}

impl FromRow for Posten {
    fn from_row(row: &Row) -> Self {
        Self {
            pflegemittel_id: row.get("pflegemittel_id"),
            menge: row.get("menge"),
        }
    }
}

impl FromRow for Bestand {
    fn from_row(row: &Row) -> Self {
        Bestand {
            zeitstempel: row.get("zeitstempel"),
            geplanter_verbrauch: row.get("geplanter_verbrauch"),
            vorhandene_menge: row.get("vorhandene_menge"),
        }
    }
}

impl FromRow for Menge {
    fn from_row(row: &Row) -> Self {
        Menge {
            zeitstempel: row.get("zeitstempel"),
            menge: row.get("menge"),
        }
    }
}

fn collect_rows<T: FromRow>(stmt: &mut Statement, params: &[&ToSql]) -> Vec<T> {
    stmt.query_map(params, T::from_row)
        .unwrap()
        .filter_map(Result::ok)
        .collect()
}

pub fn create_schema(conn: &mut Connection) {
    let user_version: u32 = conn
        .query_row("PRAGMA user_version", &[], |row| row.get(0))
        .unwrap();

    if user_version < 6 {
        let txn = conn.transaction().unwrap();

        txn.execute_batch(
            r#"
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
            "#,
        ).unwrap();

        txn.commit().unwrap();
    }

    if user_version < 7 {
        let txn = conn.transaction().unwrap();

        txn.execute_batch(
            r#"
ALTER TABLE pflegemittel ADD COLUMN wurde_gezaehlt INTEGER NOT NULL DEFAULT 0;

PRAGMA user_version = 7;
            "#,
        ).unwrap();

        txn.commit().unwrap();
    }
}

pub fn pflegemittel_laden(txn: &Transaction) -> Vec<Pflegemittel> {
    let mut stmt = txn
        .prepare(
            r#"
WITH groesste_zeitstempel AS (
    SELECT pflegemittel_id, MAX(zeitstempel) AS zeitstempel
    FROM pflegemittel_bestand GROUP BY pflegemittel_id
)
SELECT pm.*, pmb.zeitstempel, pmb.geplanter_verbrauch, pmb.vorhandene_menge
FROM pflegemittel pm, pflegemittel_bestand pmb, groesste_zeitstempel gzs
WHERE pm.id = pmb.pflegemittel_id
AND pmb.pflegemittel_id = gzs.pflegemittel_id AND pmb.zeitstempel = gzs.zeitstempel
        "#,
        ).unwrap();

    collect_rows(&mut stmt, &[])
}

pub fn pflegemittel_speichern(
    txn: &Transaction,
    pflegemittel: Vec<Pflegemittel>,
    zeitstempel: i64,
) {
    let mut pm_stmt = txn
        .prepare("INSERT OR REPLACE INTO pflegemittel VALUES (?, ?, ?, ?, ?, ?, ?)")
        .unwrap();

    let mut pmb_stmt = txn
        .prepare("INSERT INTO pflegemittel_bestand VALUES (?, ?, ?, ?)")
        .unwrap();

    for mut pm in pflegemittel {
        pm_stmt
            .execute(&[
                &pm.id,
                &pm.bezeichnung,
                &pm.einheit,
                &pm.hersteller_und_produkt,
                &pm.pzn_oder_ref,
                &pm.wird_verwendet,
                &pm.wurde_gezaehlt,
            ]).unwrap();

        pm.id = Some(txn.last_insert_rowid());
        pm.zeitstempel = Some(zeitstempel);

        pmb_stmt
            .execute(&[
                &pm.id,
                &pm.zeitstempel,
                &pm.geplanter_verbrauch,
                &pm.vorhandene_menge,
            ]).unwrap();
    }
}

pub fn bestellungen_laden(txn: &Transaction, limit: Option<u32>) -> Vec<Bestellung> {
    let limit = limit.unwrap_or(1);

    let mut b_stmt = txn
        .prepare("SELECT b.* FROM bestellungen b ORDER BY b.zeitstempel DESC LIMIT ?")
        .unwrap();

    let mut bp_stmt = txn.prepare("SELECT bp.pflegemittel_id, bp.menge FROM bestellungen_posten bp WHERE bp.bestellung_id = ?").unwrap();

    let mut bestellungen: Vec<Bestellung> = collect_rows(&mut b_stmt, &[&limit]);

    for mut bestellung in &mut bestellungen {
        bestellung.posten = collect_rows(&mut bp_stmt, &[&bestellung.id]);
    }

    bestellungen
}

pub fn bestellung_speichern(
    txn: &Transaction,
    mut bestellung: Bestellung,
    zeitstempel: i64,
) -> Bestellung {
    let mut b_stmt = txn
        .prepare("INSERT INTO bestellungen VALUES (?, ?, ?, ?)")
        .unwrap();

    let mut bp_stmt = txn
        .prepare("INSERT INTO bestellungen_posten VALUES (?, ?, ?)")
        .unwrap();

    bestellung.id = None;
    bestellung.zeitstempel = Some(zeitstempel);

    b_stmt
        .execute(&[
            &bestellung.id,
            &bestellung.zeitstempel,
            &bestellung.empfaenger,
            &bestellung.nachricht,
        ]).unwrap();

    bestellung.id = Some(txn.last_insert_rowid());

    for posten in &bestellung.posten {
        bp_stmt
            .execute(&[&bestellung.id, &posten.pflegemittel_id, &posten.menge])
            .unwrap();
    }

    bestellung
}

pub fn posten_laden(txn: &Transaction, posten: Vec<Posten>) -> Vec<(Posten, Pflegemittel)> {
    let mut stmt = txn
        .prepare(
            r#"
SELECT pm.*, pmb.zeitstempel, pmb.geplanter_verbrauch, pmb.vorhandene_menge
FROM pflegemittel pm, pflegemittel_bestand pmb
WHERE pm.id = ? AND pm.id = pmb.pflegemittel_id
ORDER BY pmb.zeitstempel DESC LIMIT 1
        "#,
        ).unwrap();

    posten
        .into_iter()
        .map(|p| {
            let pm = stmt
                .query_row(&[&p.pflegemittel_id], Pflegemittel::from_row)
                .unwrap();

            (p, pm)
        }).collect()
}

pub fn bestand_laden(txn: &Transaction, id: Option<i64>) -> Vec<Bestand> {
    let id = id.die(
        400,
        "Der Parameter id fehlt oder konnte nicht verarbeitet werden.",
    );

    let mut stmt = txn.prepare("SELECT zeitstempel, geplanter_verbrauch, vorhandene_menge FROM pflegemittel_bestand WHERE pflegemittel_id = ? ORDER BY zeitstempel").unwrap();

    collect_rows(&mut stmt, &[&id])
}

pub fn menge_laden(txn: &Transaction, id: Option<i64>) -> Vec<Menge> {
    let id = id.die(
        400,
        "Der Parameter id fehlt oder konnte nicht verarbeitet werden.",
    );

    let mut stmt = txn
        .prepare(
            r#"
SELECT b.zeitstempel, bp.menge
FROM bestellungen b, bestellungen_posten bp
WHERE bp.bestellung_id = b.id AND bp.pflegemittel_id = ?
ORDER BY b.zeitstempel
        "#,
        ).unwrap();

    collect_rows(&mut stmt, &[&id])
}
