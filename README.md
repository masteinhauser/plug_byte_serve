# Plug.ByteServe

This is a Plug module for adding [HTTP Content-Range][rfc-content-range] to a set of routes. Only single byte ranges are currently supported.
Wikipedia entry on [HTTP Byte Serving][wiki-byte-serving] for more information.

## Installation

Add `plug-byte-serve` to the `deps` function in your project's `mix.exs` file:

```elixir
defp deps do
  [{:plug-byte-serve, "~> 0.1.0"}]
end
```

Then run `mix do deps.get, deps.compile` inside your project's directory.

## Usage

Plug.ByteServe can be used just as any other Plug. Add Plug.ByteServe after all of the other plugs you want to happen using the `plug` function.

```elixir
defmodule GetServed do
  import Plug.Conn
  use Plug.Router

  plug Plug.ByteServe,
  plug :match
  plug :dispatch

  get "/bytes" %{"file" => file} do
    conn
    |> send_resp()
  end
end
```

## Todo

[] Plug-ify byte serving code
[] Proper handling of invalid range requests
[] Support multipart range requests

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Plug.BasicAuth uses the same license as Plug and the Elixir programming language. See the [license file](https://raw.githubusercontent.com/masteinhauser/plug-byte-serve/master/LICENSE) for more information.

[wiki-byte-serving]: http://en.wikipedia.org/wiki/Byte_serving "Wikipedia - HTTP Byte Serving"
[rfc-content-range]: http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.16 "RFC2616 - Content-Range"
