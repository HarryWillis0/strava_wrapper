defmodule StravaWrapper.StravaClient do
  alias StravaWrapper.Activity

  @base_url Application.compile_env!(:strava_wrapper, [:strava, :base_url])
  @oauth_url "https://www.strava.com/oauth/token"
  @per_page 200

  @spec exchange_code(String.t()) ::
          {:ok, %{access_token: String.t(), athlete_id: integer()}} | {:error, String.t()}
  def exchange_code(code) do
    config = Application.get_env(:strava_wrapper, :strava, [])

    form = [
      client_id: Keyword.get(config, :client_id),
      client_secret: Keyword.get(config, :client_secret),
      code: code,
      grant_type: "authorization_code"
    ]

    opts = Application.get_env(:strava_wrapper, :strava_client_req_options, [])

    case Req.post(Req.new(opts), url: @oauth_url, form: form) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, %{access_token: body["access_token"], athlete_id: body["athlete"]["id"]}}

      {:ok, %{body: body}} ->
        {:error, body["message"] || "token exchange failed"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  @spec fetch_activities(String.t()) :: [%Activity{}]
  def fetch_activities(access_token) do
    req = build_req(access_token)
    fetch_page(req, 1, [])
  end

  defp build_req(token) do
    opts = Application.get_env(:strava_wrapper, :strava_client_req_options, [])
    Req.new([base_url: @base_url, auth: {:bearer, token}] ++ opts)
  end

  defp fetch_page(req, page, accumulated) do
    response =
      Req.get!(req, url: "/athlete/activities", params: [per_page: @per_page, page: page])

    case response.body do
      body when is_list(body) ->
        activities = Enum.map(body, &parse_activity/1)

        case length(activities) do
          @per_page -> fetch_page(req, page + 1, accumulated ++ activities)
          _ -> accumulated ++ activities
        end

      %{"message" => message, "errors" => errors} ->
        raise "Strava API error: #{message} — #{inspect(errors)}"

      other ->
        raise "Unexpected Strava response: #{inspect(other)}"
    end
  end

  defp parse_activity(raw) do
    %Activity{
      id: raw["id"],
      name: raw["name"],
      date: parse_date(raw["start_date_local"]),
      type: raw["sport_type"],
      distance: raw["distance"],
      duration: raw["moving_time"],
      gear_id: raw["gear_id"],
      gear_name: nil
    }
  end

  defp parse_date(nil), do: nil

  defp parse_date(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end
end
