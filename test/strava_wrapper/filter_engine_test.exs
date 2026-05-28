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

  describe "apply/2 with multiple filters" do
    test "composes multiple criteria — result is the intersection" do
      match = make_activity(id: 1, gear_id: "b1", type: "Run")
      wrong_gear = make_activity(id: 2, gear_id: "b2", type: "Run")
      wrong_type = make_activity(id: 3, gear_id: "b1", type: "Ride")
      activities = [match, wrong_gear, wrong_type]
      assert FilterEngine.apply(activities, %{gear_id: "b1", type: "Run"}) == [match]
    end
  end
end
