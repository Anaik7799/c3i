import gleam/erlang/process.{type Pid}

pub type Session

@external(erlang, "cepaf_gleam_ffi", "zenoh_open")
pub fn open(config_json: String) -> Result(Session, String)

@external(erlang, "cepaf_gleam_ffi", "zenoh_put")
pub fn put(
  session: Session,
  key: String,
  payload: String,
) -> Result(Nil, String)

@external(erlang, "cepaf_gleam_ffi", "zenoh_get")
pub fn get(session: Session, key: String) -> Result(String, String)

@external(erlang, "cepaf_gleam_ffi", "zenoh_subscribe")
pub fn subscribe(session: Session, key: String, pid: Pid) -> Result(Nil, String)
