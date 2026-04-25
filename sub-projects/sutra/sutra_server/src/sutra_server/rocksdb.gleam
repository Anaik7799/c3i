//// rocksdb — Persistent key-value storage via Rust NIF.
//// Provides tuwunel-parity persistence for Sutra Matrix server.
////
//// Column families match tuwunel's RocksDB schema:
////   users, rooms, events, tokens, media, device_keys,
////   one_time_keys, cross_signing_keys, account_data,
////   receipts, presence, push_rules, room_state,
////   typing, to_device, aliases
////
//// STAMP: SC-SUTRA-ROCKS-001

/// Open the RocksDB database at the given path.
@external(erlang, "rocksdb_ffi", "db_open")
pub fn open(path: String) -> Result(String, String)

/// Put a key-value pair in a column family.
@external(erlang, "rocksdb_ffi", "db_put")
pub fn put(cf: String, key: String, value: String) -> Result(String, String)

/// Get a value by key from a column family.
@external(erlang, "rocksdb_ffi", "db_get")
pub fn get(cf: String, key: String) -> Result(String, String)

/// Delete a key from a column family.
@external(erlang, "rocksdb_ffi", "db_delete")
pub fn delete(cf: String, key: String) -> Result(String, String)

/// Scan keys with a prefix. Returns up to limit (key, value) pairs.
@external(erlang, "rocksdb_ffi", "db_scan")
pub fn scan(cf: String, prefix: String, limit: Int) -> Result(List(#(String, String)), String)

/// Check if the database is open.
@external(erlang, "rocksdb_ffi", "db_is_open")
pub fn is_open() -> Bool

/// Flush all pending writes to disk.
@external(erlang, "rocksdb_ffi", "db_flush")
pub fn flush() -> Result(String, String)

/// Get database size in bytes.
@external(erlang, "rocksdb_ffi", "db_size_on_disk")
pub fn size_on_disk() -> Result(Int, String)
