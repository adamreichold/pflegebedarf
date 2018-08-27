use std::fs::{read_dir, write};
use std::io::{stdout, Result, Write};
use std::os::unix::ffi::OsStrExt;
use std::process::Command;

const MODULES: &[&'static str] = &["Pflegemittel", "NeueBestellung"];

fn main() -> Result<()> {
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

        write(&format!("ui/html/{}.html", module), &minified.stdout)?;

        let compressed = Command::new("gzip")
            .current_dir("ui/html")
            .arg("--best")
            .arg("--force")
            .arg(&format!("{}.html", module))
            .status()?;

        if !compressed.success() {
            panic!("Failed to compress UI module {}", module);
        }
    }

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
