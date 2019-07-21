use std::fs::{read_dir, File};
use std::io::{stdout, Write};
use std::os::unix::ffi::OsStrExt;
use std::process::Command;

use failure::{ensure, Fallible};
use flate2::{write::GzEncoder, Compression};
use rayon::prelude::*;

#[cfg(feature = "build-ui")]
fn main() -> Fallible<()> {
    const MODULES: &[&'static str] = &["Pflegemittel", "NeueBestellung"];

    for module in MODULES {
        let compiled = Command::new("node_modules/elm/bin/elm")
            .arg("make")
            .arg("--optimize")
            .arg(&format!("--output=target/html/{}.html", module))
            .arg(&format!("src/{}.elm", module))
            .status()?;

        ensure!(compiled.success(), "Failed to compile UI module {}", module);
    }

    MODULES.par_iter().try_for_each(|module| {
        let minified = Command::new("node")
            .arg("node_modules/html-minifier/cli.js")
            .arg("--minify-js")
            .arg(r#"{"compress":{"pure_funcs":["F2","F3","F4","F5","F6","F7","F8","F9","A2","A3","A4","A5","A6","A7","A8","A9"],"pure_getters":true,"keep_fargs":false,"unsafe_comps":true,"unsafe":true}}"#)
            .arg(&format!("target/html/{}.html", module))
            .output()?;

        ensure!(minified.status.success(), "Failed to minify UI module {}", module);

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
            stdout.write(b"cargo:rerun-if-changed=src/")?;
            stdout.write(file_name.as_bytes())?;
            stdout.write(b"\n")?;
        }
    }

    Ok(())
}

#[cfg(not(feature = "build-ui"))]
fn main() {}
