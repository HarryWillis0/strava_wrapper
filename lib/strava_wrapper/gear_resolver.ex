defmodule StravaWrapper.GearResolver do
  alias StravaWrapper.Activity

  @base_url Application.compile_env!(:strava_wrapper, [:strava, :base_url])

  @spec resolve(String.t(), [%Activity{}]) :: [%Activity{}]
  def resolve(_token, []), do: []

  def resolve(token, activities) do
    gear_ids =
      activities
      |> Enum.map(& &1.gear_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    gear_map = fetch_gear_map(token, gear_ids)

    Enum.map(activities, fn %Activity{} = activity ->
      %Activity{activity | gear_name: Map.get(gear_map, activity.gear_id)}
    end)
  end

  defp fetch_gear_map(_token, []), do: %{}

  defp fetch_gear_map(token, gear_ids) do
    req = build_req(token)

    gear_ids
    |> Task.async_stream(fn id -> {id, fetch_name(req, id)} end, timeout: :infinity)
    |> Enum.into(%{}, fn {:ok, pair} -> pair end)
  end

  defp build_req(token) do
    opts = Application.get_env(:strava_wrapper, :gear_resolver_req_options, [])
    Req.new([base_url: @base_url, auth: {:bearer, token}] ++ opts)
  end

  defp fetch_name(req, gear_id) do
    case Req.get(req, url: "/gear/#{gear_id}") do
      {:ok, %{status: 200, body: body}} -> body["name"]
      _ -> gear_id
    end
  end
end
