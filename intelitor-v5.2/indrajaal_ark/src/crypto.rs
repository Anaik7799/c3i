use anyhow::Result;
use blake3::Hasher;
use std::io::Read;
use std::fs::File;
use std::path::Path;

pub fn calculate_hash(path: &Path) -> Result<String> {
    let mut file = File::open(path)?;
    let mut hasher = Hasher::new();
    let mut buffer = [0; 4096];

    loop {
        let count = file.read(&mut buffer)?;
        if count == 0 { break; }
        hasher.update(&buffer[..count]);
    }

    Ok(hasher.finalize().to_hex().to_string())
}

pub fn verify_shard(data: &[u8], expected_hash: &str) -> bool {
    let hash = blake3::hash(data);
    hash.to_hex().to_string() == expected_hash
}
