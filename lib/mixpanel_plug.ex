defmodule MixpanelPlug do
  @moduledoc """
  Mixpanel tracking as a plug.

  - Track events with useful context like referrer, user agent information, and UTM properties
  - Keep user profiles up to date on every request
  - Respects ‘Do Not Track’ request headers
  """

  import Plug.Conn

  @type user :: %{id: number | String.t(), name: String.t(), email: String.t()}

  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @doc """
  Checks for the ‘Do Not Track’ request header and if it exists, assigns its
  value to the connection. In the case that tracking is permitted,
  `update_profile` will be called with the value of an assign named
  `current_user` from the connection. The value of `current_user` must pattern
  match the type `t:user/0`. If this is not matched, the user’s profile will not
  be updated.
  """
  @spec call(Plug.Conn.t(%{assigns: %{current_user: user()}}), Plug.opts()) :: Plug.Conn.t()
  def call(%{assigns: %{current_user: current_user}} = conn, _opts) do
    conn
    |> put_do_not_track()
    |> update_profile(current_user)
  end

  def call(conn, _opts), do: put_do_not_track(conn)

  @doc """
  Checks whether the 'Do Not Track' header has been set on the connection

  ## Examples

      iex> MixpanelPlug.tracking_disabled?(conn)
      true

  """
  @spec tracking_disabled?(Plug.Conn.t()) :: boolean
  def tracking_disabled?(conn) do
    conn
    |> get_req_header("dnt")
    |> Enum.member?("1")
  end

  @doc """
  Updates a user profile in Mixpanel. This method pattern matches the value of
  the `user` struct against the type `t:user/0`. If this is not matched, the
  user’s profile will not be updated.

  This is a noop if the ‘Do Not Track’ header is set.

  ## Examples

      MixpanelPlug.update_profile(conn, %{id: 1, name: "Callum", email: "callum@example.com"})

  """
  @spec update_profile(Plug.Conn.t(), user :: user()) :: Plug.Conn.t()
  def update_profile(%{assigns: %{do_not_track: true}} = conn, _user), do: conn

  def update_profile(conn, %{id: id, name: name, email: email} = _user) do
    properties = %{
      "$name" => name,
      "$email" => email,
      "ID" => id
    }

    conn
    |> engage(id, "$set", properties)
    |> put_analytics(:profile, properties)
  end

  def update_profile(conn, _user), do: conn

  @doc """
  Tracks an event in Mixpanel.

  This is a noop if the ‘Do Not Track’ header is set.

  ## Examples

      MixpanelPlug.track(conn, "Added To Wishlist")
      MixpanelPlug.track(conn, "Discount Code Used", %{"Value" => "10"})

  """
  @spec track(Plug.Conn.t(), event :: String.t(), properties :: struct) :: Plug.Conn.t()
  def track(conn, event, properties \\ %{})

  def track(%{assigns: %{do_not_track: true}} = conn, _event, _properties), do: conn

  def track(conn, event, properties) do
    properties = get_properties(conn, properties)
    opts = get_opts(conn)

    Mixpanel.track(event, properties, opts)

    conn
    |> update_analytics(:tracked_events, &[{event, properties, opts} | &1 || []])
  end

  defp engage(conn, distinct_id, operation, properties) do
    Mixpanel.engage(distinct_id, operation, properties, ip: conn.remote_ip)
    conn
  end

  defp get_properties(conn, properties) do
    properties
    |> put_page_properties(conn)
    |> put_referrer_properties(conn)
    |> put_user_agent_properties(conn)
    |> put_utm_properties(conn)
  end

  defp put_do_not_track(conn) do
    if tracking_disabled?(conn) do
      assign(conn, :do_not_track, true)
    else
      conn
    end
  end

  defp put_page_properties(properties, conn) do
    Map.put(properties, "Current Path", conn.request_path)
  end

  defp put_referrer_properties(properties, conn) do
    case List.first(get_req_header(conn, "referer")) do
      nil ->
        properties

      referrer ->
        properties
        |> Map.put_new("$referrer", referrer)
        |> Map.put_new("$referring_domain", URI.parse(referrer).host)
    end
  end

  defp put_user_agent_properties(properties, conn) do
    with ua <- get_req_header(conn, "user-agent"),
         ua when is_binary(ua) <- List.first(ua),
         ua <- UAParser.parse(ua) do
      properties
      |> Map.put_new("$os", to_string(ua.os))
      |> Map.put_new("$browser", to_string(ua.family))
      |> Map.put_new("$browser_version", to_string(ua.version))
      |> Map.put_new(
        "$device",
        case ua.device do
          %{family: nil} -> nil
          device -> to_string(device)
        end
      )
    else
      _ -> properties
    end
  end

  defp put_utm_properties(properties, %{query_params: query_params}) do
    properties
    |> put_utm_property(query_params, "utm_source")
    |> put_utm_property(query_params, "utm_medium")
    |> put_utm_property(query_params, "utm_campaign")
    |> put_utm_property(query_params, "utm_content")
    |> put_utm_property(query_params, "utm_term")
  end

  defp put_utm_property(properties, query_params, property_key) do
    case Map.get(query_params, property_key) do
      nil ->
        properties

      property_value ->
        Map.put_new(properties, property_key, property_value)
    end
  end

  defp get_opts(%{assigns: %{current_user: %{id: id}}} = conn) do
    [ip: conn.remote_ip, distinct_id: id]
  end

  defp get_opts(conn) do
    [ip: conn.remote_ip]
  end

  defp put_analytics(%{assigns: assigns} = conn, key, value) do
    assigns =
      assigns
      |> Map.put_new(:analytics, %{})
      |> put_in([:analytics, key], value)

    %{conn | assigns: assigns}
  end

  defp update_analytics(%{assigns: assigns} = conn, key, fun) do
    assigns =
      assigns
      |> Map.put_new(:analytics, %{})
      |> update_in([:analytics, key], fun)

    %{conn | assigns: assigns}
  end
end
