use std::io::{stdin, stdout, Write};

use serde::ser::Serialize;
use serde::de::DeserializeOwned;
use serde_json::{from_reader, to_writer};

pub fn write_to_stdout<T: Serialize>(value: &T) {
    let mut writer = stdout();

    writer
        .write_all(b"Content-Type: application/json; charset=utf8\r\n\r\n")
        .unwrap();

    to_writer(writer, value).unwrap();
}

pub fn read_from_stdin<T: DeserializeOwned>() -> T {
    from_reader(stdin()).die(400, "Konnte JSON-Darstellung nicht verarbeiten.")
}

pub trait Die<T> {
    fn die(self, status: i32, msg: &'static str) -> T;
}

impl<T> Die<T> for Option<T> {
    fn die(self, status: i32, msg: &'static str) -> T {
        match self {
            Some(t) => t,
            None => die(status, msg),
        }
    }
}

impl<V, E> Die<V> for Result<V, E> {
    fn die(self, status: i32, msg: &'static str) -> V {
        match self {
            Ok(v) => v,
            Err(_) => die(status, msg),
        }
    }
}

pub fn die(status: i32, msg: &'static str) -> ! {
    let mut writer = stdout();

    write!(
        &mut writer,
        "Content-Type: text/plain; charset=utf8\r\nStatus: {}\r\n\r\n{}",
        status, msg
    ).unwrap();

    panic!(msg)
}
