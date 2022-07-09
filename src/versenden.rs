use std::fmt::Write;
use std::fs::File;

use chrono::{Local, TimeZone};
use lettre::{
    message::{
        header::{ContentType, Header, HeaderName, HeaderValue},
        Mailbox, MessageBuilder, SinglePart,
    },
    transport::smtp::authentication::Credentials,
    SmtpTransport, Transport,
};
use rusqlite::{params, Transaction};
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

    let mut email = MessageBuilder::new()
        .to(bestellung.empfaenger.parse()?)
        .from(config.von.parse()?)
        .reply_to(config.antwort.parse()?);

    for kopie in &config.kopien {
        email = email.cc(kopie.parse()?);
    }

    if bestellung.empfangsbestaetigung {
        email = email.header(DispositionNotificationTo::parse(&config.antwort)?);
    }

    let email = email
        .subject(config.betreff.replace("{datum}", &datum))
        .singlepart(
            SinglePart::builder()
                .header(ContentType::TEXT_PLAIN)
                .body(bestellung.nachricht.replace("{posten}", &posten)),
        )
        .map_err(|err| format!("Konnte E-Mail nicht erstellen: {}", err))?;

    SmtpTransport::relay(&config.smtp.domain)?
        .credentials(Credentials::new(config.smtp.username, config.smtp.password))
        .build()
        .send(&email)
        .map_err(|err| format!("Konnte E-Mail nicht versenden: {}", err))?;

    txn.execute(
        "UPDATE pflegemittel SET wurde_gezaehlt = 0 WHERE anbieter_id = ?",
        params![bestellung.anbieter_id],
    )?;

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

#[derive(Clone)]
struct DispositionNotificationTo(Mailbox);

impl Header for DispositionNotificationTo {
    fn name() -> HeaderName {
        HeaderName::new_from_ascii_str("Disposition-Notification-To")
    }

    fn parse(mailbox: &str) -> Fallible<Self> {
        Ok(Self(mailbox.parse()?))
    }

    fn display(&self) -> HeaderValue {
        HeaderValue::new(Self::name(), self.0.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    use lettre::Address;
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
            Mailbox::new(None, Address::new("foo", "bar.org").unwrap()),
            "foo@bar.org".parse::<Mailbox>().unwrap(),
        );
    }

    #[test]
    fn check_mailbox_with_alias() {
        assert_eq!(
            Mailbox::new(
                Some("foobar".to_owned()),
                Address::new("foo", "bar.org").unwrap()
            ),
            "foobar <foo@bar.org>".parse::<Mailbox>().unwrap(),
        );
    }
}
