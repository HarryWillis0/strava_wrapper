defmodule StravaWrapperWeb.AuthController do
  use StravaWrapperWeb, :controller

  alias StravaWrapper.{ActivityStore, StravaClient}

  @strava_auth_url "https://www.strava.com/oauth/authorize"

  def request(conn, _params) do
    client_id = Application.get_env(:strava_wrapper, :strava, []) |> Keyword.get(:client_id)
    redirect_uri = StravaWrapperWeb.Endpoint.url() <> ~p"/auth/strava/callback"

    query =
      URI.encode_query(%{
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: "code",
        scope: "activity:read"
      })

    redirect(conn, external: @strava_auth_url <> "?" <> query)
  end

  def callback(conn, %{"code" => code}) do
    case StravaClient.exchange_code(code) do
      {:ok, %{access_token: token, athlete_id: athlete_id}} ->
        athlete_id = to_string(athlete_id)
        ActivityStore.load_for_user(athlete_id, token)

        conn
        |> put_session(:access_token, token)
        |> put_session(:athlete_id, athlete_id)
        |> redirect(to: ~p"/")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Strava authentication failed: #{reason}")
        |> redirect(to: ~p"/auth/strava")
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Strava authentication was cancelled.")
    |> redirect(to: ~p"/auth/strava")
  end
end
