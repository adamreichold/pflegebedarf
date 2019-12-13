use std::error::Error;
use std::fs::{read_dir, File};
use std::io::{stdout, Write};
use std::os::unix::ffi::OsStrExt;
use std::process::Command;

use flate2::{write::GzEncoder, Compression};
use rayon::prelude::*;

#[cfg(feature = "build-ui")]
fn main() -> Result<(), Box<dyn Error + Send + Sync>> {
    const MODULES: &[&str] = &["Pflegemittel", "NeueBestellung"];

    for module in MODULES {
        let compiled = Command::new("node_modules/elm/bin/elm")
            .arg("make")
            .arg("--optimize")
            .arg(&format!("--output=target/html/{}.html", module))
            .arg(&format!("src/{}.elm", module))
            .status()?;

        if !compiled.success() {
            return Err(format!("Failed to compile UI module {}", module).into());
        }
    }

    MODULES.par_iter().try_for_each(|module| -> Result<(), Box<dyn Error + Send + Sync>> {
        let minified = Command::new("node")
            .arg("node_modules/html-minifier/cli.js")
            .arg("--minify-js")
            .arg(r#"{"compress":{"pure_funcs":["F2","F3","F4","F5","F6","F7","F8","F9","A2","A3","A4","A5","A6","A7","A8","A9"],"pure_getters":true,"keep_fargs":false,"unsafe_comps":true,"unsafe":true}}"#)
            .arg(&format!("target/html/{}.html", module))
            .output()?;

        if !minified.status.success() {
            return Err(format!("Failed to minify UI module {}", module).into());
        }

        let mut compressed =
            GzEncoder::new(File::create(format!("target/html/{}.html.gz", module))?, Compression::best());
        compressed.write_all(&minified.stdout)?;
        compressed.finish()?;

        Ok(())
    })?;

    for entry in read_dir("src")? {
        let file_name = entry?.file_name();

        if file_name.as_bytes().ends_with(b".elm") {
            let mut stdout = stdout();
            stdout.write_all(b"cargo:rerun-if-changed=src/")?;
            stdout.write_all(file_name.as_bytes())?;
            stdout.write_all(b"\n")?;
        }
    }

    Ok(())
}

#[cfg(not(feature = "build-ui"))]
fn main() {}
