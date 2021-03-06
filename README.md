# PlugByteServe [![hex.pm version](https://img.shields.io/hexpm/v/plug_byte_serve.svg)](https://hex.pm/packages/plug_byte_serve) [![hex.pm downloads](https://img.shields.io/hexpm/dt/plug_byte_serve.svg)](https://hex.pm/packages/plug_byte_serve)

This is a Plug module for adding [HTTP Content-Range][rfc-content-range] to a set of routes. Only single byte ranges are currently supported.
Wikipedia entry on [HTTP Byte Serving][wiki-byte-serving] for more information.

## Installation

Add `plug_byte_serve` to the `deps` function in your project's `mix.exs` file:

```elixir
defp deps do
  [{:plug_byte_serve, "~> 0.3.0"}]
end
```

Then run `mix do deps.get, deps.compile` inside your project's directory.

## Usage

PlugByteServe can be used just as any other Plug. Add Plug.ByteServe after all of the other plugs you want to happen using the `plug` function.

### When you know which file you want to serve
```elixir
defmodule GetServed do
  import Plug.Conn
  use Plug.Router

  plug PlugByteServe, path: "/tmp", file: "/tmp/file"
  plug :match
  plug :dispatch

  get "/" do
    conn
    |> send_resp()
  end
end
```

### When the file is dynamically found
``` elixir
defmodule GetServed do
  import Plug.Conn
  use Plug.Router

  plug :match
  plug :dispatch

  get "/:file" do
    path = "/path/to/files/"
    conn
    |> PlugByteServe.call([path: path, file: file])
    |> send_resp()
  end
end
```

## TODO

- [x] Plug-ify byte serving code
- [x] Proper handling of invalid range requests
- [x] Use `sendfile` for efficiency
- [ ] Support multipart range requests

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Plug.BasicAuth uses the same license as Plug and the Elixir programming language. See the [license file](https://raw.githubusercontent.com/masteinhauser/plug_byte_serve/master/LICENSE) for more information.

[wiki-byte-serving]: http://en.wikipedia.org/wiki/Byte_serving "Wikipedia - HTTP Byte Serving"
[rfc-content-range]: http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.16 "RFC2616 - Content-Range"
