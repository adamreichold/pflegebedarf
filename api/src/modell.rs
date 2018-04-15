#[derive(Serialize, Deserialize)]
pub struct Pflegemittel {
    pub id: Option<i64>,
    pub zeitstempel: Option<i64>,
    pub bezeichnung: String,
    pub einheit: String,
    pub hersteller_und_produkt: String,
    pub pzn_oder_ref: String,
    pub geplanter_verbrauch: u32,
    pub vorhandene_menge: u32,
    pub wird_verwendet: bool,
    pub wurde_gezaehlt: bool,
}

#[derive(Serialize, Deserialize)]
pub struct Bestellung {
    pub id: Option<i64>,
    pub zeitstempel: Option<i64>,
    pub empfaenger: String,
    pub nachricht: String,
    pub posten: Vec<Posten>,
}

#[derive(Serialize, Deserialize)]
pub struct Posten {
    pub pflegemittel_id: i64,
    pub menge: u32,
}

#[derive(Serialize, Deserialize)]
pub struct Bestand {
    pub zeitstempel: i64,
    pub geplanter_verbrauch: u32,
    pub vorhandene_menge: u32,
}

#[derive(Serialize, Deserialize)]
pub struct Menge {
    pub zeitstempel: i64,
    pub menge: u32,
}
