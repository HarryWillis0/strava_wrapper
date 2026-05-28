defmodule StravaWrapper.FilterEngine do
  alias StravaWrapper.Activity

  @spec apply([%Activity{}], map()) :: [%Activity{}]
  def apply(activities, filters) do
    activities
    |> maybe_filter_gear(Map.get(filters, :gear_id, :not_set))
    |> maybe_filter_type(Map.get(filters, :type, :not_set))
  end

  defp maybe_filter_gear(activities, :not_set), do: activities
  defp maybe_filter_gear(activities, nil), do: Enum.filter(activities, &is_nil(&1.gear_id))

  defp maybe_filter_gear(activities, gear_id),
    do: Enum.filter(activities, &(&1.gear_id == gear_id))

  defp maybe_filter_type(activities, :not_set), do: activities
  defp maybe_filter_type(activities, type), do: Enum.filter(activities, &(&1.type == type))
end
