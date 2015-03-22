defmodule PlugByteServe.Mixfile do
  use Mix.Project

  def project do
    [app: :plug_byte_serve,
     version: "0.3.2",
     elixir: "~> 1.0.3",
     deps: deps,
     package: package,
     name: "Plug Byte Serve",
     source_url: "https://github.com/masteinhauser/plug_byte_serve",
     homepage_url: "https://github.com/masteinhauser/plug_byte_serve",
     description: "A Plug for using HTTP Byte Serving in Plug applications.",
     docs: [readme: true, main: "README"]]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [
      {:plug, "~> 0.11.1"},
      {:ex_doc, "~> 0.6.2",  only: [:docs]},
      {:cowboy, "~> 1.0.0", only: [:test, :dev]}
    ]
  end

  defp package do
    [
      contributors: ["Myles Steinhauser"],
      licenses: ["Apache 2"],
      links: %{"Github" => "https://github.com/masteinhauser/plug_byte_serve"}
    ]
  end
end
