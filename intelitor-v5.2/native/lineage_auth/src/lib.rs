use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use rustler::{Binary, Error, NifResult};

#[rustler::nif]
fn verify_signature(pubkey_bin: Binary, message_bin: Binary, signature_bin: Binary) -> NifResult<bool> {
    // 1. Parse public key (32 bytes)
    let pubkey_bytes: [u8; 32] = match pubkey_bin.as_slice().try_into() {
        Ok(bytes) => bytes,
        Err(_) => return Err(Error::BadArg),
    };

    let verifying_key = match VerifyingKey::from_bytes(&pubkey_bytes) {
        Ok(key) => key,
        Err(_) => return Err(Error::BadArg),
    };

    // 2. Parse signature (64 bytes)
    let signature_bytes: [u8; 64] = match signature_bin.as_slice().try_into() {
        Ok(bytes) => bytes,
        Err(_) => return Err(Error::BadArg),
    };

    let signature = Signature::from_bytes(&signature_bytes);

    // 3. Verify
    match verifying_key.verify(message_bin.as_slice(), &signature) {
        Ok(_) => Ok(true),
        Err(_) => Ok(false),
    }
}

rustler::init!("Elixir.Indrajaal.Safety.LineageAuth");