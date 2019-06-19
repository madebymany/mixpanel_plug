# MixpanelPlug

A plug-based approach to Mixpanel tracking with Elixir. Use MixpanelPlug to:

- Track events with useful context like referrer, user agent information, and UTM properties
- Keep user profiles up to date on every request

MixpanelPlug respects the ‘Do Not Track’ request header. When this is set, no tracking calls will be made.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `mixpanel_plug` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mixpanel_plug, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/mixpanel_plug](https://hexdocs.pm/mixpanel_plug).

## Configuration

Add configuration for `mixpanel_api_ex` to your `config/config.exs` file:

```elixir
config :mixpanel_api_ex, config: [token: "your_mixpanel_token"]
```

## Usage

In a Phoenix application, register the MixpanelPlug plug in `router.ex`:

```diff
defmodule Example.Router do
  use Example, :router

  pipeline :browser do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
+   plug MixpanelPlug
  end
end
```

If the ‘Do Not Track’ (`dnt`) has been set to `1`, the property `do_not_track: true` will be assigned to the connection. Additionally, a call to `MixpanelPlug.update_profile/2` will be made with the value of `current_user` from the connection, if ‘Do Not Track’ is not set. For more information, please see the module documentation.

For making tracking calls, use `MixpanelPlug.track_event`:

```elixir
defmodule Example.UserController do
  use Example, :controller

  import MixpanelPlug, only: [track_event: 3]

  def create(conn, %{"email" => email}) do
    conn
    |> track_event("Example User Created", %{"email" => email})
    |> render("user_created.html")
  end
end
```

The properties added to the tracking call include the following, where appropriate:

```elixir
%{
  "email" => "email@example.com",
  "Current Path" => "/users",
  "$browser" => "Mobile Safari",
  "$browser_version" => "10.0",
  "$device" => "iPhone",
  "$os" => "iOS 10.3.1",
  "utm_campaign" => "campaign",
  "utm_content" => "content",
  "utm_medium" => "medium",
  "utm_source" => "source",
  "utm_term" => "term"
}
```
