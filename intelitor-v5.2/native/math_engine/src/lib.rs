use rustler::{Atom, NifResult};

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
fn calculate_entropy(data: String) -> NifResult<f64> {
    if data.is_empty() {
        return Ok(0.0);
    }

    let bytes = data.as_bytes();
    let mut counts = [0usize; 256];
    for &byte in bytes {
        counts[byte as usize] += 1;
    }

    let total = bytes.len() as f64;
    let mut entropy = 0.0;

    for &count in counts.iter() {
        if count > 0 {
            let p = count as f64 / total;
            entropy -= p * p.log2();
        }
    }

    Ok(entropy)
}

#[rustler::nif]
fn optimize_jitter(base_load: f64, node_count: i32) -> NifResult<f64> {
    // Ported from math_oracle.py symbolic logic
    // Simplified optimization formula for the NIF reification
    let jitter = (base_load * node_count as f64).sqrt() / 10.0;
    Ok(jitter)
}

rustler::init!("Elixir.Indrajaal.Analysis.MathNif");
