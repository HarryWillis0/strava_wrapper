defmodule StravaWrapper.ActivityStore do
  use GenServer

  alias StravaWrapper.{FilterEngine, GearResolver, StravaClient}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec all(String.t()) :: list()
  def all(user_id) do
    case :ets.whereis(:activities) do
      :undefined ->
        []

      _ ->
        :ets.match_object(:activities, {{user_id, :_}, :_})
        |> Enum.map(fn {_key, activity} -> activity end)
    end
  end

  @spec filter(String.t(), map()) :: list()
  def filter(user_id, filter_map) do
    user_id
    |> all()
    |> FilterEngine.apply(filter_map)
  end

  @impl true
  def init(opts) do
    :ets.new(:activities, [:set, :public, :named_table])
    activities = load(opts)
    store_for_user("default", activities)
    {:ok, %{}}
  end

  defp load(opts) do
    case Keyword.get(opts, :activities) do
      nil ->
        token = get_token()

        token
        |> StravaClient.fetch_activities()
        |> then(&GearResolver.resolve(token, &1))

      preloaded ->
        preloaded
    end
  end

  defp get_token do
    Application.get_env(:strava_wrapper, :strava, [])
    |> Keyword.get(:access_token, "")
  end

  defp store_for_user(user_id, activities) do
    Enum.each(activities, fn activity ->
      :ets.insert(:activities, {{user_id, activity.id}, activity})
    end)
  end
end
