# SSL Configuration for Container Environment
import Config

config :ex_doc, :http_options,
  ssl: [
    cacertfile:
      "/nix/store/07nr6sfx0nwikcsw3r1zmrb4plj6mzzi-git-aware-elixir-env/etc/ssl/certs/ca-bundle.crt",
    verify: :verify_peer,
    depth: 10
  ]

config :hex, :http_options,
  ssl: [
    cacertfile:
      "/nix/store/07nr6sfx0nwikcsw3r1zmrb4plj6mzzi-git-aware-elixir-env/etc/ssl/certs/ca-bundle.crt",
    verify: :verify_peer,
    depth: 10
  ]

config :mix, :ssl_options,
  cacertfile:
    "/nix/store/07nr6sfx0nwikcsw3r1zmrb4plj6mzzi-git-aware-elixir-env/etc/ssl/certs/ca-bundle.crt",
  verify: :verify_peer,
  depth: 10
