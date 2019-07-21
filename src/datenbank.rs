use failure::Fallible;
use rusqlite::{
    types::ToSql, Connection, Result as SqlResult, Row, Statement, Transaction, NO_PARAMS,
};

use crate::modell::{Anbieter, Bestellung, Pflegemittel, Posten};

trait FromRow: Sized {
    fn from_row(row: &Row) -> SqlResult<Self>;
}

impl FromRow for Anbieter {
    fn from_row(row: &Row) -> SqlResult<Self> {
        Ok(Self {
            id: Some(row.get("id")?),
            bezeichnung: row.get("bezeichnung")?,
        })
    }
}

impl FromRow for Pflegemittel {
    fn from_row(row: &Row) -> SqlResult<Self> {
        Ok(Self {
            id: Some(row.get("id")?),
            anbieter_id: row.get("anbieter_id")?,
            zeitstempel: row.get("zeitstempel")?,
            bezeichnung: row.get("bezeichnung")?,
            einheit: row.get("einheit")?,
            hersteller_und_produkt: row.get("hersteller_und_produkt")?,
            pzn_oder_ref: row.get("pzn_oder_ref")?,
            geplanter_verbrauch: row.get("geplanter_verbrauch")?,
            vorhandene_menge: row.get("vorhandene_menge")?,
            wird_verwendet: row.get("wird_verwendet")?,
            wurde_gezaehlt: row.get("wurde_gezaehlt")?,
        })
    }
}

impl FromRow for Bestellung {
    fn from_row(row: &Row) -> SqlResult<Self> {
        Ok(Self {
            id: Some(row.get("id")?),
            anbieter_id: row.get("anbieter_id")?,
            zeitstempel: row.get("zeitstempel")?,
            empfaenger: row.get("empfaenger")?,
            nachricht: row.get("nachricht")?,
            posten: Vec::new(),
        })
    }
}

impl FromRow for Posten {
    fn from_row(row: &Row) -> SqlResult<Self> {
        Ok(Self {
            pflegemittel_id: row.get("pflegemittel_id")?,
            menge: row.get("menge")?,
        })
    }
}

fn collect_rows<T: FromRow>(stmt: &mut Statement, params: &[&dyn ToSql]) -> Fallible<Vec<T>> {
    let mut rows = Vec::new();

    for row in stmt.query_map(params, T::from_row)? {
        rows.push(row?);
    }

    Ok(rows)
}

pub fn schema_anlegen() -> Fallible<Connection> {
    let mut conn = Connection::open("datenbank.sqlite")?;

    let user_version: u32 = conn.query_row("PRAGMA user_version", NO_PARAMS, |row| row.get(0))?;

    if user_version < 6 {
        let txn = conn.transaction()?;

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
        )?;

        txn.commit()?;
    }

    if user_version < 7 {
        let txn = conn.transaction()?;

        txn.execute_batch(
            r#"
ALTER TABLE pflegemittel ADD COLUMN wurde_gezaehlt INTEGER NOT NULL DEFAULT 0;

PRAGMA user_version = 7;
            "#,
        )?;

        txn.commit()?;
    }

    if user_version < 8 {
        let txn = conn.transaction()?;

        txn.execute_batch(
            r#"
CREATE TABLE anbieter (
    id INTEGER PRIMARY KEY,
    bezeichnung TEXT NOT NULL
);

INSERT INTO anbieter (id, bezeichnung) VALUES (0, "nicht zutreffend");

ALTER TABLE pflegemittel ADD COLUMN anbieter_id INTEGER NOT NULL DEFAULT 0 REFERENCES anbieter (id);

ALTER TABLE bestellungen ADD COLUMN anbieter_id INTEGER NOT NULL DEFAULT 0 REFERENCES anbieter (id);

PRAGMA user_version = 8;
            "#,
        )?;

        txn.commit()?;
    }

    Ok(conn)
}

pub fn anbieter_laden(txn: &Transaction) -> Fallible<Vec<Anbieter>> {
    let mut stmt = txn.prepare(
        r#"
SELECT a.* FROM anbieter a
        "#,
    )?;

    collect_rows(&mut stmt, &[])
}

pub fn pflegemittel_laden(txn: &Transaction) -> Fallible<Vec<Pflegemittel>> {
    let mut stmt = txn.prepare(
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
    )?;

    collect_rows(&mut stmt, &[])
}

pub fn pflegemittel_speichern(
    txn: &Transaction,
    pflegemittel: Vec<Pflegemittel>,
    zeitstempel: i64,
) -> Fallible<()> {
    let mut pm_stmt =
        txn.prepare("INSERT OR REPLACE INTO pflegemittel VALUES (?, ?, ?, ?, ?, ?, ?, ?)")?;

    let mut pmb_stmt = txn.prepare("INSERT INTO pflegemittel_bestand VALUES (?, ?, ?, ?)")?;

    for mut pm in pflegemittel {
        pm_stmt.execute(&[
            &pm.id as &dyn ToSql,
            &pm.bezeichnung,
            &pm.einheit,
            &pm.hersteller_und_produkt,
            &pm.pzn_oder_ref,
            &pm.wird_verwendet,
            &pm.wurde_gezaehlt,
            &pm.anbieter_id,
        ])?;

        pm.id = Some(txn.last_insert_rowid());
        pm.zeitstempel = Some(zeitstempel);

        pmb_stmt.execute(&[
            &pm.id as &dyn ToSql,
            &pm.zeitstempel,
            &pm.geplanter_verbrauch,
            &pm.vorhandene_menge,
        ])?;
    }

    Ok(())
}

pub fn bestellungen_laden(
    txn: &Transaction,
    anbieter: i64,
    bis_zu: u32,
) -> Fallible<Vec<Bestellung>> {
    let mut b_stmt =
        txn.prepare("SELECT b.* FROM bestellungen b WHERE b.anbieter_id = ? ORDER BY b.zeitstempel DESC LIMIT ?")?;

    let mut bp_stmt = txn.prepare("SELECT bp.pflegemittel_id, bp.menge FROM bestellungen_posten bp WHERE bp.bestellung_id = ?")?;

    let mut bestellungen: Vec<Bestellung> = collect_rows(&mut b_stmt, &[&anbieter, &bis_zu])?;

    for mut bestellung in &mut bestellungen {
        bestellung.posten = collect_rows(&mut bp_stmt, &[&bestellung.id])?;
    }

    Ok(bestellungen)
}

pub fn bestellung_speichern(
    txn: &Transaction,
    mut bestellung: Bestellung,
    zeitstempel: i64,
) -> Fallible<Bestellung> {
    let mut b_stmt = txn.prepare("INSERT INTO bestellungen VALUES (?, ?, ?, ?, ?)")?;

    let mut bp_stmt = txn.prepare("INSERT INTO bestellungen_posten VALUES (?, ?, ?)")?;

    bestellung.id = None;
    bestellung.zeitstempel = Some(zeitstempel);

    b_stmt.execute(&[
        &bestellung.id as &dyn ToSql,
        &bestellung.zeitstempel,
        &bestellung.empfaenger,
        &bestellung.nachricht,
        &bestellung.anbieter_id,
    ])?;

    bestellung.id = Some(txn.last_insert_rowid());

    for posten in &bestellung.posten {
        bp_stmt.execute(&[
            &bestellung.id as &dyn ToSql,
            &posten.pflegemittel_id,
            &posten.menge,
        ])?;
    }

    Ok(bestellung)
}

pub fn posten_laden(
    txn: &Transaction,
    posten: Vec<Posten>,
) -> Fallible<Vec<(Posten, Pflegemittel)>> {
    let mut stmt = txn.prepare(
        r#"
SELECT pm.*, pmb.zeitstempel, pmb.geplanter_verbrauch, pmb.vorhandene_menge
FROM pflegemittel pm, pflegemittel_bestand pmb
WHERE pm.id = ? AND pm.id = pmb.pflegemittel_id
ORDER BY pmb.zeitstempel DESC LIMIT 1
        "#,
    )?;

    let mut ppm = Vec::new();

    for p in posten {
        let pm = stmt.query_row(&[&p.pflegemittel_id], Pflegemittel::from_row)?;

        ppm.push((p, pm));
    }

    Ok(ppm)
}
