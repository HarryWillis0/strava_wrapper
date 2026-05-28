defmodule StravaWrapper.StravaClient do
  alias StravaWrapper.Activity

  @base_url Application.compile_env!(:strava_wrapper, [:strava, :base_url])
  @per_page 200

  @spec fetch_activities(String.t()) :: [%Activity{}]
  def fetch_activities(access_token) do
    fetch_page(access_token, 1, [])
  end

  defp fetch_page(access_token, page, accumulated) do
    response =
      Req.get!(
        "#{@base_url}/athlete/activities",
        auth: {:bearer, access_token},
        params: [per_page: @per_page, page: page]
      )

    activities = Enum.map(response.body, &parse_activity/1)

    case length(activities) do
      @per_page ->
        fetch_page(access_token, page + 1, accumulated ++ activities)

      _ ->
        accumulated ++ activities
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
