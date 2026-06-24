defmodule StravaWrapper.FilterEngineTest do
  use ExUnit.Case, async: true

  alias StravaWrapper.{Activity, FilterEngine}

  defp make_activity(overrides \\ []) do
    [
      id: 1,
      name: "Run",
      date: nil,
      type: "Run",
      distance: 0.0,
      duration: 0,
      gear_id: nil,
      gear_name: nil
    ]
    |> Keyword.merge(overrides)
    |> then(&struct(Activity, &1))
  end

  describe "apply/2 with empty filter" do
    test "returns all activities unchanged" do
      a1 = make_activity(id: 1, gear_id: "b1")
      a2 = make_activity(id: 2, gear_id: nil)
      assert FilterEngine.apply([a1, a2], %{}) == [a1, a2]
    end

    test "returns empty list when no activities" do
      assert FilterEngine.apply([], %{}) == []
    end
  end

  describe "apply/2 with gear_id filter" do
    test "returns only activities matching the given gear_id" do
      match = make_activity(id: 1, gear_id: "b1")
      other = make_activity(id: 2, gear_id: "b2")
      assert FilterEngine.apply([match, other], %{gear_id: "b1"}) == [match]
    end

    test "returns empty list when no activities match" do
      a = make_activity(id: 1, gear_id: "b1")
      assert FilterEngine.apply([a], %{gear_id: "b_missing"}) == []
    end

    test "filters for untagged activities when gear_id is nil" do
      tagged = make_activity(id: 1, gear_id: "b1")
      untagged = make_activity(id: 2, gear_id: nil)
      assert FilterEngine.apply([tagged, untagged], %{gear_id: nil}) == [untagged]
    end
  end

  describe "stats/1" do
    test "returns zeroed map for empty list" do
      assert FilterEngine.stats([]) == %{
               total_count: 0,
               total_distance: 0.0,
               total_duration: 0,
               first_date: nil,
               type_breakdown: %{}
             }
    end

    test "counts activities and breaks down by type" do
      run1 = make_activity(id: 1, type: "Run", distance: 5000.0, duration: 1800)
      run2 = make_activity(id: 2, type: "Run", distance: 3000.0, duration: 1200)
      ride = make_activity(id: 3, type: "Ride", distance: 20_000.0, duration: 3600)

      stats = FilterEngine.stats([run1, run2, ride])

      assert stats.total_count == 3
      assert stats.total_distance == 28_000.0
      assert stats.total_duration == 6600
      assert stats.type_breakdown == %{"Run" => 2, "Ride" => 1}
    end

    test "picks the earliest date as first_date" do
      older = ~U[2024-01-01 00:00:00Z]
      newer = ~U[2024-06-01 00:00:00Z]
      a1 = make_activity(id: 1, date: newer)
      a2 = make_activity(id: 2, date: older)

      assert FilterEngine.stats([a1, a2]).first_date == older
    end

    test "treats nil distance and duration as 0" do
      a = make_activity(id: 1, distance: nil, duration: nil)
      stats = FilterEngine.stats([a])
      assert stats.total_distance == 0.0
      assert stats.total_duration == 0
    end
  end

  describe "apply/2 with multiple filters" do
    test "composes multiple criteria — result is the intersection" do
      match = make_activity(id: 1, gear_id: "b1", type: "Run")
      wrong_gear = make_activity(id: 2, gear_id: "b2", type: "Run")
      wrong_type = make_activity(id: 3, gear_id: "b1", type: "Ride")
      activities = [match, wrong_gear, wrong_type]
      assert FilterEngine.apply(activities, %{gear_id: "b1", type: "Run"}) == [match]
    end
  end

  describe "apply/2 sorting" do
    test "no-op when sort keys are absent" do
      a1 = make_activity(id: 1, name: "Bravo")
      a2 = make_activity(id: 2, name: "Alpha")
      assert FilterEngine.apply([a1, a2], %{}) == [a1, a2]
    end

    test "sorts by name ascending" do
      a1 = make_activity(id: 1, name: "Bravo")
      a2 = make_activity(id: 2, name: "Alpha")
      result = FilterEngine.apply([a1, a2], %{sort_by: :name, sort_dir: :asc})
      assert Enum.map(result, & &1.name) == ["Alpha", "Bravo"]
    end

    test "sorts by name descending" do
      a1 = make_activity(id: 1, name: "Alpha")
      a2 = make_activity(id: 2, name: "Bravo")
      result = FilterEngine.apply([a1, a2], %{sort_by: :name, sort_dir: :desc})
      assert Enum.map(result, & &1.name) == ["Bravo", "Alpha"]
    end

    test "sorts by date ascending" do
      older = ~U[2024-01-01 00:00:00Z]
      newer = ~U[2024-06-01 00:00:00Z]
      a1 = make_activity(id: 1, date: newer)
      a2 = make_activity(id: 2, date: older)
      result = FilterEngine.apply([a1, a2], %{sort_by: :date, sort_dir: :asc})
      assert Enum.map(result, & &1.date) == [older, newer]
    end

    test "sorts by date descending" do
      older = ~U[2024-01-01 00:00:00Z]
      newer = ~U[2024-06-01 00:00:00Z]
      a1 = make_activity(id: 1, date: older)
      a2 = make_activity(id: 2, date: newer)
      result = FilterEngine.apply([a1, a2], %{sort_by: :date, sort_dir: :desc})
      assert Enum.map(result, & &1.date) == [newer, older]
    end

    test "sorts by type ascending" do
      a1 = make_activity(id: 1, type: "Run")
      a2 = make_activity(id: 2, type: "Ride")
      result = FilterEngine.apply([a1, a2], %{sort_by: :type, sort_dir: :asc})
      assert Enum.map(result, & &1.type) == ["Ride", "Run"]
    end

    test "sorts by distance ascending" do
      a1 = make_activity(id: 1, distance: 10_000.0)
      a2 = make_activity(id: 2, distance: 5_000.0)
      result = FilterEngine.apply([a1, a2], %{sort_by: :distance, sort_dir: :asc})
      assert Enum.map(result, & &1.distance) == [5_000.0, 10_000.0]
    end

    test "sorts by distance descending" do
      a1 = make_activity(id: 1, distance: 5_000.0)
      a2 = make_activity(id: 2, distance: 10_000.0)
      result = FilterEngine.apply([a1, a2], %{sort_by: :distance, sort_dir: :desc})
      assert Enum.map(result, & &1.distance) == [10_000.0, 5_000.0]
    end

    test "sorts by duration ascending" do
      a1 = make_activity(id: 1, duration: 3600)
      a2 = make_activity(id: 2, duration: 1800)
      result = FilterEngine.apply([a1, a2], %{sort_by: :duration, sort_dir: :asc})
      assert Enum.map(result, & &1.duration) == [1800, 3600]
    end

    test "sorts by gear_name ascending" do
      a1 = make_activity(id: 1, gear_name: "Zoom Fly")
      a2 = make_activity(id: 2, gear_name: "Air Max")
      result = FilterEngine.apply([a1, a2], %{sort_by: :gear_name, sort_dir: :asc})
      assert Enum.map(result, & &1.gear_name) == ["Air Max", "Zoom Fly"]
    end

    test "nil values sort to the bottom regardless of direction (asc)" do
      a_nil = make_activity(id: 1, distance: nil)
      a_val = make_activity(id: 2, distance: 5_000.0)
      result = FilterEngine.apply([a_nil, a_val], %{sort_by: :distance, sort_dir: :asc})
      assert List.last(result).id == 1
    end

    test "nil values sort to the bottom regardless of direction (desc)" do
      a_nil = make_activity(id: 1, distance: nil)
      a_val = make_activity(id: 2, distance: 5_000.0)
      result = FilterEngine.apply([a_nil, a_val], %{sort_by: :distance, sort_dir: :desc})
      assert List.last(result).id == 1
    end
  end
end
