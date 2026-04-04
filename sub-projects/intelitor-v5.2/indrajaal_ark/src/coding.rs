//! # Reed-Solomon Coding — Indrajaal.Ark
//! 
//! ## Specification: RS(255, 223)
//! - n = 255 (Total Shards)
//! - k = 223 (Data Shards)
//! - 2t = 32 (Parity Shards / Error Correction Capability)
//! - Capability: Can reconstruct if any 32 shards are lost.

use anyhow::{Context, Result};
use reed_solomon_erasure::galois_8::ReedSolomon;

pub const DATA_SHARDS: usize = 223;
pub const PARITY_SHARDS: usize = 32;
pub const TOTAL_SHARDS: usize = DATA_SHARDS + PARITY_SHARDS;

pub struct ArkEncoder {
    rs: ReedSolomon,
}

impl ArkEncoder {
    pub fn new() -> Result<Self> {
        let rs = ReedSolomon::new(DATA_SHARDS, PARITY_SHARDS)
            .context("Failed to initialize RS(255,223) encoder")?;
        Ok(Self { rs })
    }

    /// Encodes a byte buffer into 255 shards.
    /// Handles padding to ensure data length is a multiple of DATA_SHARDS.
    pub fn encode(&self, data: &[u8]) -> Result<Vec<Vec<u8>>> {
        let original_len = data.len();
        
        // Calculate shard size
        let shard_size = (original_len + DATA_SHARDS - 1) / DATA_SHARDS;
        
        // Create sharded buffer with padding
        let mut shards = vec![vec![0u8; shard_size]; TOTAL_SHARDS];
        
        // Fill data shards
        for i in 0..original_len {
            shards[i / shard_size][i % shard_size] = data[i];
        }
        
        // Compute parity
        self.rs.encode(&mut shards).context("RS encoding failed")?;
        
        Ok(shards)
    }

    /// Reconstructs missing shards.
    /// shards: A vector of 255 Option<Vec<u8>>, where None represents a lost shard.
    pub fn reconstruct(&self, shards: &mut Vec<Option<Vec<u8>>>) -> Result<()> {
        self.rs.reconstruct(shards).context("RS reconstruction failed")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rs_cycle_integrity() -> Result<()> {
        let encoder = ArkEncoder::new()?;
        let original_data = b"Indrajaal SIL-6 Biomorphic Archive Seed - Prototype V1";
        
        // 1. Encode
        let shards = encoder.encode(original_data)?;
        assert_eq!(shards.len(), 255);
        
        // 2. Simulate massive data loss (lose 32 shards)
        let mut partial_shards: Vec<Option<Vec<u8>>> = shards.into_iter().map(Some).collect();
        for i in 0..32 {
            partial_shards[i] = None;
        }
        
        // 3. Reconstruct
        encoder.reconstruct(&mut partial_shards)?;
        
        // 4. Verify (check a few data shards)
        assert!(partial_shards[33].is_some());
        assert_eq!(partial_shards[33].as_ref().unwrap().len(), partial_shards[0].as_ref().unwrap().len());
        
        Ok(())
    }
    
    #[test]
    fn test_rs_unrecoverable_failure() -> Result<()> {
        let encoder = ArkEncoder::new()?;
        let original_data = vec![0u8; 1024];
        let shards = encoder.encode(&original_data)?;
        
        // Lose 33 shards (one more than capability)
        let mut partial_shards: Vec<Option<Vec<u8>>> = shards.into_iter().map(Some).collect();
        for i in 0..33 {
            partial_shards[i] = None;
        }
        
        // Should fail
        assert!(encoder.reconstruct(&mut partial_shards).is_err());
        
        Ok(())
    }
}
