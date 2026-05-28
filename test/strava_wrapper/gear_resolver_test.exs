defmodule StravaWrapper.GearResolverTest do
  use ExUnit.Case, async: false

  alias StravaWrapper.{Activity, GearResolver}

  defp make_activity(overrides \\ []) do
    [
      id: 1,
      name: "Test Activity",
      date: nil,
      type: "Run",
      distance: 0.0,
      duration: 0,
      gear_id: nil
    ]
    |> Keyword.merge(overrides)
    |> then(&struct(Activity, &1))
  end

  test "returns empty list for empty activities" do
    assert GearResolver.resolve("token", []) == []
  end

  test "leaves gear_name nil when activity has no gear_id" do
    activity = make_activity(gear_id: nil)
    [result] = GearResolver.resolve("token", [activity])
    assert is_nil(result.gear_name)
  end

  test "populates gear_name from API for activity with gear_id" do
    Req.Test.stub(StravaWrapper.GearResolver, fn conn ->
      Req.Test.json(conn, %{"id" => "b123", "name" => "Road Bike"})
    end)

    activity = make_activity(gear_id: "b123")
    [result] = GearResolver.resolve("token", [activity])
    assert result.gear_name == "Road Bike"
  end

  test "makes exactly one API call per unique gear_id" do
    agent = start_supervised!({Agent, fn -> 0 end})

    Req.Test.stub(StravaWrapper.GearResolver, fn conn ->
      Agent.update(agent, &(&1 + 1))
      Req.Test.json(conn, %{"name" => "Shared Gear"})
    end)

    a1 = make_activity(id: 1, gear_id: "b123")
    a2 = make_activity(id: 2, gear_id: "b123")
    [r1, r2] = GearResolver.resolve("token", [a1, a2])

    assert Agent.get(agent, & &1) == 1
    assert r1.gear_name == "Shared Gear"
    assert r2.gear_name == "Shared Gear"
  end

  test "falls back to gear_id string when API call fails" do
    Req.Test.stub(StravaWrapper.GearResolver, fn conn ->
      Plug.Conn.send_resp(conn, 404, "Not Found")
    end)

    activity = make_activity(gear_id: "b_unknown")
    [result] = GearResolver.resolve("token", [activity])
    assert result.gear_name == "b_unknown"
  end

  test "handles mix of activities with and without gear_id" do
    Req.Test.stub(StravaWrapper.GearResolver, fn conn ->
      Req.Test.json(conn, %{"name" => "Mountain Bike"})
    end)

    tagged = make_activity(id: 1, gear_id: "b456")
    untagged = make_activity(id: 2, gear_id: nil)
    [r_tagged, r_untagged] = GearResolver.resolve("token", [tagged, untagged])

    assert r_tagged.gear_name == "Mountain Bike"
    assert is_nil(r_untagged.gear_name)
  end
end
