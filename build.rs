use std::error::Error;
use std::fs::read_dir;
use std::io::{stdout, Write};
use std::os::unix::ffi::OsStrExt;
use std::process::Command;

#[cfg(feature = "build-ui")]
fn main() -> Result<(), Box<dyn Error + Send + Sync>> {
    for module in ["Pflegemittel", "NeueBestellung"] {
        let compiled = Command::new("elm")
            .arg("make")
            .arg("--optimize")
            .arg(&format!("--output=target/html/{}.html", module))
            .arg(&format!("src/{}.elm", module))
            .status()?;

        if !compiled.success() {
            return Err(format!("Failed to compile UI module {}", module).into());
        }

        let compressed = Command::new("gzip")
            .arg("--force")
            .arg("--best")
            .arg(format!("target/html/{}.html", module))
            .status()?;

        if !compressed.success() {
            return Err(format!("Failed to compress UI module {}", module).into());
        }
    }

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
