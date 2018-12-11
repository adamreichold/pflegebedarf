use std::fmt::Write;
use std::fs::File;

use serde_derive::Deserialize;
use serde_json::from_reader;

use lettre::smtp::authentication::Credentials;
use lettre::smtp::SmtpTransport;
use lettre::EmailTransport;
use lettre_email::{EmailBuilder, Mailbox};

use rusqlite::{Transaction, NO_PARAMS};

use time::{at, strftime, Timespec};

use crate::datenbank::posten_laden;
use crate::errors::{Result, ResultExt};
use crate::modell::{Bestellung, Posten};

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

pub fn bestellung_versenden(txn: &Transaction, bestellung: Bestellung) -> Result<()> {
    if !bestellung.nachricht.contains("{posten}") {
        return Err("Die Nachricht muss den Platzhalter {posten} enthalten.".into());
    }

    let config: Config = from_reader(File::open("versenden.json")?)?;

    let datum = strftime(
        "%d.%m.%Y",
        &at(Timespec::new(bestellung.zeitstempel.unwrap(), 0)),
    )
    .unwrap();

    let posten = posten_formatieren(txn, bestellung.posten)?;

    let mut email = EmailBuilder::new()
        .to(parse_mailbox(bestellung.empfaenger))
        .from(parse_mailbox(config.von))
        .reply_to(parse_mailbox(config.antwort));

    for kopie in config.kopien {
        email.add_cc(parse_mailbox(kopie));
    }

    email.set_subject(config.betreff.replace("{datum}", &datum));
    email.set_text(bestellung.nachricht.replace("{posten}", &posten));

    let mut smtp = SmtpTransport::simple_builder(&config.smtp.domain)
        .chain_err(|| "Konnte SMTP-Verbindung nicht aufbauen.")?
        .credentials(Credentials::new(config.smtp.username, config.smtp.password))
        .build();

    smtp.send(
        &email
            .build()
            .chain_err(|| "Konnte E-Mail nicht erstellen.")?,
    )
    .chain_err(|| "Konnte E-Mail nicht versenden.")?;

    txn.execute("UPDATE pflegemittel SET wurde_gezaehlt = 0", NO_PARAMS)?;

    Ok(())
}

fn posten_formatieren(txn: &Transaction, posten: Vec<Posten>) -> Result<String> {
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

fn parse_mailbox(mbox: String) -> Mailbox {
    if let Some(begin) = mbox.find('<') {
        if let Some(end) = mbox.rfind('>') {
            if begin < end {
                let name = mbox[..begin].trim();
                let addr = mbox[begin + 1..end].trim();

                if !name.is_empty() && !addr.is_empty() {
                    return Mailbox::new_with_name(name.to_string(), addr.to_string());
                }
            }
        }
    }

    Mailbox::new(mbox)
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
            Mailbox::new("foo@bar.org".to_string()),
            parse_mailbox("foo@bar.org".to_string())
        );
    }

    #[test]
    fn check_mailbox_with_alias() {
        assert_eq!(
            Mailbox::new_with_name("foobar".to_string(), "foo@bar.org".to_string()),
            parse_mailbox("foobar <foo@bar.org>".to_string())
        );
    }
}
