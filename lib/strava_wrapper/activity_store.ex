defmodule StravaWrapper.ActivityStore do
  use GenServer

  alias StravaWrapper.{FilterEngine, GearResolver, StravaClient}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec put(String.t(), list()) :: :ok
  def put(user_id, activities) do
    store_for_user(user_id, activities)
  end

  @spec load_for_user(String.t(), String.t()) :: :ok
  def load_for_user(athlete_id, token) do
    activities =
      token
      |> StravaClient.fetch_activities()
      |> then(&GearResolver.resolve(token, &1))

    store_for_user(athlete_id, activities)
  end

  @spec query(String.t(), map()) :: list()
  def query(user_id, filter_map) do
    activities =
      case :ets.whereis(:activities) do
        :undefined ->
          []

        _ ->
          :ets.match_object(:activities, {{user_id, :_}, :_})
          |> Enum.map(fn {_key, activity} -> activity end)
      end

    FilterEngine.apply(activities, filter_map)
  end

  @impl true
  def init(_opts) do
    :ets.new(:activities, [:set, :public, :named_table])
    {:ok, %{}}
  end

  defp store_for_user(user_id, activities) do
    Enum.each(activities, fn activity ->
      :ets.insert(:activities, {{user_id, activity.id}, activity})
    end)
  end
end
