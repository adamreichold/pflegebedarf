extern crate flate2;
extern crate rayon;

use std::fs::{read_dir, File};
use std::io::{stdout, Result, Write};
use std::os::unix::ffi::OsStrExt;
use std::process::Command;

use flate2::write::GzEncoder;
use flate2::Compression;
use rayon::prelude::*;

#[cfg(feature = "build-ui")]
fn main() -> Result<()> {
    const MODULES: &[&'static str] = &["Pflegemittel", "NeueBestellung"];

    for module in MODULES {
        let compiled = Command::new("node_modules/elm/bin/elm")
            .current_dir("ui")
            .arg("make")
            .arg("--optimize")
            .arg(&format!("--output=html/{}.html", module))
            .arg(&format!("{}.elm", module))
            .status()?;

        if !compiled.success() {
            panic!("Failed to compile UI module {}", module);
        }
    }

    MODULES.par_iter().map(|module| {
        let minified = Command::new("node")
            .current_dir("ui")
            .arg("node_modules/html-minifier/cli.js")
            .arg("--minify-js")
            .arg(r#"{"compress":{"pure_funcs":["F2","F3","F4","F5","F6","F7","F8","F9","A2","A3","A4","A5","A6","A7","A8","A9"],"pure_getters":true,"keep_fargs":false,"unsafe_comps":true,"unsafe":true}}"#)
            .arg(&format!("html/{}.html", module))
            .output()?;

        if !minified.status.success() {
            panic!("Failed to minify UI module {}", module);
        }

        let mut compressed =
            GzEncoder::new(File::create(format!("ui/html/{}.html.gz", module))?, Compression::best());
        compressed.write_all(&minified.stdout)?;
        compressed.finish()?;

        Ok(())
    }).find_any(Result::is_err).unwrap_or(Ok(()))?;

    for entry in read_dir("ui")? {
        let file_name = entry?.file_name();

        if file_name.as_bytes().ends_with(b".elm") {
            let mut stdout = stdout();
            stdout.write(b"cargo:rerun-if-changed=ui/")?;
            stdout.write(file_name.as_bytes())?;
            stdout.write(b"\n")?;
        }
    }

    Ok(())
}

#[cfg(not(feature = "build-ui"))]
fn main() {}
