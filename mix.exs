defmodule MixpanelPlug.MixProject do
  use Mix.Project

  def project do
    [
      app: :mixpanel_plug,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "A plug-based approach to Mixpanel tracking with Elixir",
      source_url: "https://github.com/madebymany/mixpanel_plug",
      docs: [
        main: "readme",
        extras: ["README.md": [title: "README", filename: "readme"]]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mixpanel_api_ex]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.0"},
      {:mixpanel_api_ex, "~> 1.0.1"},
      {:ua_parser, "~> 1.7"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
    [
      licenses: ["Apache 2.0"],
      maintainers: ["Callum Jefferies"],
      links: %{"GitHub" => "https://github.com/madebymany/mixpanel_plug"}
    ]
  end
end
