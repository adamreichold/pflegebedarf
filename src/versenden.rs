use std::fmt::Write;
use std::fs::File;

use chrono::{Local, TimeZone};
use lettre::{
    smtp::{authentication::Credentials, SmtpClient, SmtpTransport},
    Transport,
};
use lettre_email::{EmailBuilder, Mailbox};
use rusqlite::{Transaction, NO_PARAMS};
use serde_derive::Deserialize;
use serde_json::from_reader;

use crate::{
    datenbank::posten_laden,
    modell::{Bestellung, Posten},
    Fallible,
};

#[derive(Deserialize)]
struct SmtpConfig {
    domain: String,
    username: String,
    password: String,
}

#[derive(Deserialize)]
struct Config {
    smtp: SmtpConfig,
    betreff: String,
    von: String,
    antwort: String,
    kopien: Vec<String>,
}

pub fn bestellung_versenden(txn: &Transaction, bestellung: Bestellung) -> Fallible<()> {
    if !bestellung.nachricht.contains("{posten}") {
        return Err("Die Nachricht muss den Platzhalter {posten} enthalten.".into());
    }

    let config: Config = from_reader(File::open("versenden.json")?)?;

    let datum = Local
        .timestamp(bestellung.zeitstempel.unwrap(), 0)
        .format("%d.%m.%Y")
        .to_string();

    let posten = posten_formatieren(txn, bestellung.posten)?;

    let mut email = EmailBuilder::new()
        .to(parse_mailbox(&bestellung.empfaenger))
        .from(parse_mailbox(&config.von))
        .reply_to(parse_mailbox(&config.antwort));

    for kopie in &config.kopien {
        email = email.cc(parse_mailbox(kopie));
    }

    if bestellung.empfangsbestaetigung {
        email = email.header(("Disposition-Notification-To", config.antwort));
    }

    email = email
        .subject(config.betreff.replace("{datum}", &datum))
        .text(bestellung.nachricht.replace("{posten}", &posten));

    let email = email
        .build()
        .map_err(|err| format!("Konnte E-Mail nicht erstellen: {}", err))?
        .into();

    let smtp_client = SmtpClient::new_simple(&config.smtp.domain)
        .map_err(|err| format!("Konnte SMTP-Verbindung nicht aufbauen: {}", err))?
        .credentials(Credentials::new(config.smtp.username, config.smtp.password));

    SmtpTransport::new(smtp_client)
        .send(email)
        .map_err(|err| format!("Konnte E-Mail nicht versenden: {}", err))?;

    txn.execute("UPDATE pflegemittel SET wurde_gezaehlt = 0", NO_PARAMS)?;

    Ok(())
}

fn posten_formatieren(txn: &Transaction, posten: Vec<Posten>) -> Fallible<String> {
    let mut stichpunkte = String::new();
    let mut anstrich = "*";

    for (p, pm) in posten_laden(txn, posten)? {
        if p.menge < 1 {
            continue;
        }

        write!(
            &mut stichpunkte,
            "{} {} {} {}",
            &anstrich, p.menge, pm.einheit, pm.bezeichnung
        )
        .unwrap();

        let hersteller_und_produkt_gesetzt = !pm.hersteller_und_produkt.is_empty();
        let pzn_oder_ref_gesetzt = !pm.pzn_oder_ref.is_empty();

        if hersteller_und_produkt_gesetzt && pzn_oder_ref_gesetzt {
            write!(
                &mut stichpunkte,
                " ({} {})",
                pm.hersteller_und_produkt, pm.pzn_oder_ref
            )
            .unwrap();
        } else if hersteller_und_produkt_gesetzt {
            write!(&mut stichpunkte, " ({})", pm.hersteller_und_produkt).unwrap();
        } else if pzn_oder_ref_gesetzt {
            write!(&mut stichpunkte, " ({})", pm.pzn_oder_ref).unwrap();
        }

        anstrich = "\n\n*";
    }

    Ok(stichpunkte)
}

fn parse_mailbox(mbox: &str) -> Mailbox {
    if let Some(begin) = mbox.find('<') {
        if let Some(end) = mbox.rfind('>') {
            if begin < end {
                let name = mbox[..begin].trim();
                let addr = mbox[begin + 1..end].trim();

                if !name.is_empty() && !addr.is_empty() {
                    return Mailbox::new_with_name(name.to_owned(), addr.to_owned());
                }
            }
        }
    }

    Mailbox::new(mbox.to_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    use serde_json::from_str;

    #[test]
    fn check_config_format() {
        let config: Config = from_str(
            r#"{
    "smtp": {
        "domain": "smtp.foobar.org",
        "username": "foo",
        "password": "bar"
    },
    "betreff": "foobar",
    "von": "foo",
    "antwort": "bar",
    "kopien": [
        "foo",
        "bar"
    ]
}"#,
        )
        .unwrap();

        assert_eq!("smtp.foobar.org", config.smtp.domain);
        assert_eq!("foo", config.smtp.username);
        assert_eq!("bar", config.smtp.password);

        assert_eq!("foobar", config.betreff);
        assert_eq!("foo", config.von);
        assert_eq!("bar", config.antwort);
        assert_eq!(["foo", "bar"], &config.kopien[..]);
    }

    #[test]
    fn check_mailbox_without_alias() {
        assert_eq!(
            Mailbox::new("foo@bar.org".to_owned()),
            parse_mailbox("foo@bar.org")
        );
    }

    #[test]
    fn check_mailbox_with_alias() {
        assert_eq!(
            Mailbox::new_with_name("foobar".to_owned(), "foo@bar.org".to_owned()),
            parse_mailbox("foobar <foo@bar.org>")
        );
    }
}
