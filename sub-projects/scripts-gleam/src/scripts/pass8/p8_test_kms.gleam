//// scripts/pass8/p8_test_kms — smoke test for the battle-hardened KMS layer.
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import scripts/common/kms

pub fn main() -> Nil {
  io.println("=== KMS robust layer smoke test ===")

  // 1. Health
  case kms.health() {
    Ok(j) -> io.println("health: " <> j)
    Error(e) -> io.println_error("health FAIL: " <> kms.error_to_string(e))
  }

  // 2. Scalar count holons
  case kms.count("holons", "") {
    Ok(n) -> io.println("holons_total = " <> int.to_string(n))
    Error(e) -> io.println_error("count FAIL: " <> kms.error_to_string(e))
  }

  // 3. Scalar count embeddings
  case kms.count("holon_embeddings", "") {
    Ok(n) -> io.println("embeddings_total = " <> int.to_string(n))
    Error(e) -> io.println_error("embed FAIL: " <> kms.error_to_string(e))
  }

  // 4. Query with params: model_pricing tier='cheap'
  case kms.query(
    "SELECT model_id, provider, input_per_million FROM model_pricing WHERE tier=? ORDER BY input_per_million LIMIT 5",
    ["cheap"],
  ) {
    Ok(qr) -> {
      io.println("cheap models (5):")
      list.each(qr.rows, fn(row) {
        io.println("  " <> row_to_string(row))
      })
    }
    Error(e) -> io.println_error("query FAIL: " <> kms.error_to_string(e))
  }

  // 5. Exec: create + drop test table
  case kms.exec("CREATE TABLE IF NOT EXISTS _smoke_pass8 (k TEXT PRIMARY KEY, v INTEGER)", []) {
    Ok(_) -> io.println("create ok")
    Error(e) -> io.println_error("create FAIL: " <> kms.error_to_string(e))
  }
  case kms.exec("INSERT OR REPLACE INTO _smoke_pass8 (k, v) VALUES (?, ?)", ["ping", "1"]) {
    Ok(n) -> io.println("insert rows=" <> int.to_string(n))
    Error(e) -> io.println_error("insert FAIL: " <> kms.error_to_string(e))
  }
  case kms.scalar("SELECT v FROM _smoke_pass8 WHERE k=?", ["ping"]) {
    Ok(v) -> io.println("read back: " <> v)
    Error(e) -> io.println_error("read FAIL: " <> kms.error_to_string(e))
  }
  case kms.exec("DROP TABLE _smoke_pass8", []) {
    Ok(_) -> io.println("drop ok")
    Error(e) -> io.println_error("drop FAIL: " <> kms.error_to_string(e))
  }

  io.println("=== DONE ===")
}

fn row_to_string(row: kms.Row) -> String {
  row
  |> list.map(fn(pair) {
    let #(k, v) = pair
    k <> "=" <> v
  })
  |> string.join(", ")
}
