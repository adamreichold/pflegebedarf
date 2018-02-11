use std::process::{Command, Stdio};

use time::{at, strftime, Timespec};

use rusqlite::Transaction;

use ini::Ini;

use super::cgi::{die, Die};
use super::modell::{Bestellung, Posten};
use super::datenbank::posten_laden;

pub fn bestellung_versenden(txn: &Transaction, bestellung: Bestellung) {
    use std::io::Write;

    let mut config = Ini::load_from_file("/usr/lib/pflegebedarf/versenden.ini")
        .die(500, "Konnte Konfiguration für Versand nicht verarbeiten.");

    let config = config.general_section_mut();

    let datum = strftime(
        "%d.%m.%Y",
        &at(Timespec::new(bestellung.zeitstempel.unwrap(), 0)),
    ).unwrap();

    let betreff = config.remove("betreff").unwrap().replace("{datum}", &datum);

    let von = config.remove("von").unwrap();
    let antwort = config.remove("antwort").unwrap();
    let kopien = config.remove("kopien").unwrap();

    if !bestellung.nachricht.contains("{posten}") {
        die(
            400,
            "Die Nachricht muss den Platzhalter {posten} enthalten.",
        );
    }

    let posten = posten_formatieren(txn, bestellung.posten);
    let nachricht = bestellung.nachricht.replace("{posten}", &posten);

    let mut sendmail = Command::new("sendmail")
        .arg("-t")
        .stdin(Stdio::piped())
        .spawn()
        .unwrap();

    {
        let stdin = sendmail.stdin.as_mut().unwrap();

        write!(stdin, "To: {}", bestellung.empfaenger).unwrap();
        write!(stdin, "\r\nFrom: {}", von).unwrap();
        write!(stdin, "\r\nReply-To: {}", antwort).unwrap();

        for kopie in kopien.split(',') {
            write!(stdin, "\r\nCc: {}", kopie).unwrap();
        }

        write!(stdin, "\r\nSubject: {}", betreff).unwrap();

        write!(stdin, "\r\n\r\n{}", nachricht).unwrap();
    }

    if !sendmail.wait().unwrap().success() {
        die(500, "Konnte Bestellung nicht versenden.");
    }
}

fn posten_formatieren(txn: &Transaction, posten: Vec<Posten>) -> String {
    use std::fmt::Write;

    let mut stichpunkte = String::new();
    let mut anstrich = "*";

    for (p, pm) in posten_laden(txn, posten) {
        if p.menge < 1 {
            continue;
        }

        write!(
            &mut stichpunkte,
            "{} {} {} {}",
            &anstrich, p.menge, pm.einheit, pm.bezeichnung
        ).unwrap();

        let hersteller_und_produkt_gesetzt = !pm.hersteller_und_produkt.is_empty();
        let pzn_oder_ref_gesetzt = !pm.pzn_oder_ref.is_empty();

        if hersteller_und_produkt_gesetzt && pzn_oder_ref_gesetzt {
            write!(
                &mut stichpunkte,
                " ({} {})",
                pm.hersteller_und_produkt, pm.pzn_oder_ref
            ).unwrap();
        } else if hersteller_und_produkt_gesetzt {
            write!(&mut stichpunkte, " ({})", pm.hersteller_und_produkt).unwrap();
        } else if pzn_oder_ref_gesetzt {
            write!(&mut stichpunkte, " ({})", pm.pzn_oder_ref).unwrap();
        }

        anstrich = "\n\n*";
    }

    stichpunkte
}
