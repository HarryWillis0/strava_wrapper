defmodule StravaWrapper.FilterEngine do
  alias StravaWrapper.Activity

  @spec apply([%Activity{}], map()) :: [%Activity{}]
  def apply(activities, filters) do
    activities
    |> maybe_filter_gear(Map.get(filters, :gear_id, :not_set))
    |> maybe_filter_type(Map.get(filters, :type, :not_set))
    |> maybe_sort(Map.get(filters, :sort_by), Map.get(filters, :sort_dir))
  end

  defp maybe_filter_gear(activities, :not_set), do: activities
  defp maybe_filter_gear(activities, nil), do: Enum.filter(activities, &is_nil(&1.gear_id))

  defp maybe_filter_gear(activities, gear_id),
    do: Enum.filter(activities, &(&1.gear_id == gear_id))

  defp maybe_filter_type(activities, :not_set), do: activities
  defp maybe_filter_type(activities, type), do: Enum.filter(activities, &(&1.type == type))

  defp maybe_sort(activities, nil, _dir), do: activities
  defp maybe_sort(activities, _field, nil), do: activities

  defp maybe_sort(activities, field, :asc) do
    Enum.sort_by(activities, &Map.get(&1, field), fn
      nil, _ -> false
      _, nil -> true
      a, b -> compare_values(a, b) != :gt
    end)
  end

  defp maybe_sort(activities, field, :desc) do
    Enum.sort_by(activities, &Map.get(&1, field), fn
      nil, _ -> false
      _, nil -> true
      a, b -> compare_values(a, b) == :gt
    end)
  end

  defp compare_values(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b)
  defp compare_values(a, b) when a < b, do: :lt
  defp compare_values(a, b) when a > b, do: :gt
  defp compare_values(_, _), do: :eq

  @spec stats([%Activity{}]) :: map()
  def stats(activities) do
    Enum.reduce(
      activities,
      %{
        total_count: 0,
        total_distance: 0.0,
        total_duration: 0,
        first_date: nil,
        type_breakdown: %{}
      },
      fn activity, acc ->
        %{
          total_count: acc.total_count + 1,
          total_distance: acc.total_distance + (activity.distance || 0),
          total_duration: acc.total_duration + (activity.duration || 0),
          first_date: earliest_date(acc.first_date, activity.date),
          type_breakdown: Map.update(acc.type_breakdown, activity.type, 1, &(&1 + 1))
        }
      end
    )
  end

  defp earliest_date(nil, date), do: date
  defp earliest_date(acc, nil), do: acc
  defp earliest_date(acc, date), do: if(DateTime.compare(date, acc) == :lt, do: date, else: acc)
end
