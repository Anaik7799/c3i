use anyhow::{Context, Result};
use std::fs::File;
use std::io::{Read, Write};
use std::path::Path;
use std::os::unix::fs::PermissionsExt;

// Level 1: The Atomic Foundation (Bitstream)
// Header script must be exactly 1024 bytes (padded)
const HEADER_SIZE: usize = 1024;

const SHELL_HEADER: &str = r###"#!/bin/sh
# INDRAJAAL ARK v21.2.0-SIL6
# CLASSIFICATION: BIOMORPHIC CRITICAL
#
# To extract: ./this_file
# Manual Recovery: tail -c +1025 "$0" | tar xz
#
# This file is a polyglot: Shell Script + ELF Binary + Zstd Archive
# It carries its own extraction logic.
#
SKIP=1024
# Find the marker just in case
marker=$(grep -a -b -o "|||BIOMORPH_SEP|||" "$0" | cut -d: -f1)
if [ ! -z "$marker" ]; then
    echo "[BOOTSTRAP] Header boundary detected at $marker"
fi

# Attempt binary execution
# We create a temp copy of the binary part if needed, or rely on memfd_create if available
echo "[BOOTSTRAP] Initiating Biomorphic Lysis..."
# (Simplified bootstrapping logic for v1)
exit 0
"###;

pub fn stitch(binary_path: &Path, output_path: &Path) -> Result<()> {
    let mut output = File::create(output_path).context("Failed to create output file")?;
    
    // 1. Write Shell Header
    let mut header = SHELL_HEADER.as_bytes().to_vec();
    // Pad to HEADER_SIZE
    if header.len() > HEADER_SIZE {
        anyhow::bail!("Header too long!");
    }
    header.resize(HEADER_SIZE, b' ');
    // Ensure newline at end of padding isn't strictly necessary for sh but good for viewing
    header[HEADER_SIZE - 1] = b'\n';
    
    output.write_all(&header).context("Failed to write header")?;
    
    // 2. Write Marker
    output.write_all(b"|||BIOMORPH_SEP|||").context("Failed to write separator")?;
    
    // 3. Write Binary
    let mut binary = File::open(binary_path).context("Failed to open binary")?;
    std::io::copy(&mut binary, &mut output).context("Failed to copy binary")?;
    
    // 4. Make executable
    let mut perms = output.metadata()?.permissions();
    perms.set_mode(0o755);
    output.set_permissions(perms)?;
    
    println!("✓ Polyglot stitching complete: {:?}", output_path);
    Ok(())
}
