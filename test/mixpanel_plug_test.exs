defmodule MixpanelPlugTest do
  use ExUnit.Case
  use Plug.Test

  describe "call" do
    test "assigns 'do not track' flag" do
      conn = conn(:get, "/")

      conn =
        conn
        |> put_req_header("dnt", "1")
        |> MixpanelPlug.call(%{})

      assert %{assigns: %{do_not_track: true}} = conn
    end

    test "records the profile of the current user when set with minimum properties" do
      conn = conn(:get, "/")

      conn =
        conn
        |> assign(:current_user, %{id: 1, name: "Callum", email: "callum@example.com"})
        |> MixpanelPlug.call(%{})

      refute is_nil(get_in(conn.assigns, [:analytics, :profile]))
    end
  end

  describe "tracking_disabled?" do
    test "returns true when the 'dnt' header is set to '1'" do
      conn = conn(:get, "/")
      conn = put_req_header(conn, "dnt", "1")

      assert MixpanelPlug.tracking_disabled?(conn) === true
    end
  end

  describe "track" do
    test "does nothing if 'do not track' is set" do
      conn = conn(:get, "/")

      conn =
        conn
        |> assign(:do_not_track, true)
        |> MixpanelPlug.track("test")

      refute Map.has_key?(conn.assigns, :analytics)
    end

    test "sets properties related to the current user" do
      conn = conn(:get, "/")

      conn =
        conn
        |> assign(:current_user, %{id: 1, name: "Callum", email: "callum@example.com"})
        |> MixpanelPlug.track("test")

      {_event, _properties, opts} =
        List.first(get_in(conn.assigns, [:analytics, :tracked_events]))

      assert Access.get(opts, :distinct_id) === 1
    end

    test "sets properties related to the request location" do
      conn = conn(:get, "/some_page_url")
      conn = MixpanelPlug.track(conn, "test")

      {_event, properties, _opts} =
        List.first(get_in(conn.assigns, [:analytics, :tracked_events]))

      assert Map.get(properties, "Current Path") === "/some_page_url"
    end

    test "sets properties related to the referrer" do
      conn = conn(:get, "/")

      conn =
        conn
        |> put_req_header("referrer", "http://example.com/example")
        |> MixpanelPlug.track("test")

      {_event, properties, _opts} =
        List.first(get_in(conn.assigns, [:analytics, :tracked_events]))

      assert Map.get(properties, "$referrer", "http://example.com/example")
      assert Map.get(properties, "$referrer_domain", "example.com")
    end

    test "sets properties related to the user agent" do
      conn =
        conn(
          :get,
          "/pooing?utm_source=source&utm_medium=medium&utm_campaign=campaign&utm_content=content&utm_term=term"
        )

      conn =
        conn
        |> put_req_header(
          "user-agent",
          "Mozilla/5.0 (iPhone; CPU iPhone OS 10_3_1 like Mac OS X) AppleWebKit/603.1.30 (KHTML, like Gecko) Version/10.0 Mobile/14E304 Safari/602.1"
        )
        |> put_req_header("referrer", "http://example.com/example")
        |> fetch_query_params()
        |> MixpanelPlug.track("test", %{"fuuuck" => "fuuuck"})

      {_event, properties, _opts} =
        List.first(get_in(conn.assigns, [:analytics, :tracked_events]))

      IO.inspect(properties)

      assert Map.has_key?(properties, "$os")
      assert Map.has_key?(properties, "$browser")
      assert Map.has_key?(properties, "$browser_version")
      assert Map.has_key?(properties, "$device")
    end

    test "sets utm properties" do
      conn =
        conn(
          :get,
          "/?utm_source=source&utm_medium=medium&utm_campaign=campaign&utm_content=content&utm_term=term"
        )

      conn =
        conn
        |> fetch_query_params()
        |> MixpanelPlug.track("test")

      {_event, properties, _opts} =
        List.first(get_in(conn.assigns, [:analytics, :tracked_events]))

      assert Map.get(properties, "utm_source") === "source"
      assert Map.get(properties, "utm_medium") === "medium"
      assert Map.get(properties, "utm_campaign") === "campaign"
      assert Map.get(properties, "utm_content") === "content"
      assert Map.get(properties, "utm_term") === "term"
    end

    test "does not set utm properties when they do not have a value" do
      conn = conn(:get, "/")

      conn =
        conn
        |> fetch_query_params()
        |> MixpanelPlug.track("test")

      {_event, properties, _opts} =
        List.first(get_in(conn.assigns, [:analytics, :tracked_events]))

      refute Map.has_key?(properties, "utm_source")
      refute Map.has_key?(properties, "utm_medium")
      refute Map.has_key?(properties, "utm_campaign")
      refute Map.has_key?(properties, "utm_content")
      refute Map.has_key?(properties, "utm_term")
    end
  end

  describe "update_profile" do
    test "does nothing if 'do not track' is set" do
      conn = conn(:get, "/")

      conn =
        conn
        |> assign(:do_not_track, true)
        |> MixpanelPlug.update_profile(%{id: 1, name: "Callum", email: "callum@example.com"})

      refute Map.has_key?(conn.assigns, :analytics)
    end

    test "records user profile" do
      user = %{id: 1, name: "Callum", email: "callum@example.com"}

      conn = conn(:get, "/")
      conn = MixpanelPlug.update_profile(conn, user)

      assert get_in(conn.assigns, [:analytics, :profile, "ID"]) === 1
      assert get_in(conn.assigns, [:analytics, :profile, "$name"]) === "Callum"
      assert get_in(conn.assigns, [:analytics, :profile, "$email"]) === "callum@example.com"
    end
  end
end
