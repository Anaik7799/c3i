# NIF for Indrajaal.Safety.LineageAuth

## To build the NIF module:

- Your NIF will now build along with your project.

## To load the NIF:

```elixir
defmodule Indrajaal.Safety.LineageAuth do
  use Rustler, otp_app: :indrajaal, crate: "lineage_auth"

  # When your NIF is loaded, it will override this function.
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
```

## Examples

[This](https://github.com/rusterlium/NifIo) is a complete example of a NIF written in Rust.
