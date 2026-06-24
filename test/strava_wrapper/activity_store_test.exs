defmodule StravaWrapper.ActivityStoreTest do
  use ExUnit.Case, async: false

  alias StravaWrapper.{Activity, ActivityStore}

  @activity %Activity{
    id: 1,
    name: "Morning Run",
    date: nil,
    type: "Run",
    distance: 5000.0,
    duration: 1800,
    gear_id: "b1",
    gear_name: "Nike Pegasus"
  }

  @activity2 %Activity{
    id: 2,
    name: "Afternoon Ride",
    date: nil,
    type: "Ride",
    distance: 20_000.0,
    duration: 3600,
    gear_id: "b2",
    gear_name: "Specialized"
  }

  test "starts with no activities" do
    start_supervised!(ActivityStore)
    assert ActivityStore.query("any_athlete", %{}) == []
  end

  describe "with seeded activities" do
    setup do
      start_supervised!(ActivityStore)
      ActivityStore.put("default", [@activity, @activity2])
      :ok
    end

    test "query/2 with empty map returns all activities for the user" do
      result = ActivityStore.query("default", %{})
      assert is_list(result)
      assert length(result) == 2
    end

    test "query/2 returns empty list for an unknown user" do
      assert ActivityStore.query("unknown_user", %{}) == []
    end

    test "query/2 filters by gear_id" do
      result = ActivityStore.query("default", %{gear_id: "b1"})
      assert length(result) == 1
      assert hd(result).gear_id == "b1"
    end

    test "query/2 returns empty list when no activities match the filter" do
      assert ActivityStore.query("default", %{gear_id: "b_missing"}) == []
    end
  end
end
