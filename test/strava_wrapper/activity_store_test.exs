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
    gear_id: nil,
    gear_name: nil
  }

  setup do
    start_supervised!({ActivityStore, activities: [@activity]})
    :ok
  end

  test "all/1 returns a list of activities for the default user" do
    result = ActivityStore.all("default")
    assert is_list(result)
    assert length(result) == 1
  end

  test "all/1 returns empty list for an unknown user" do
    assert ActivityStore.all("unknown_user") == []
  end
end
