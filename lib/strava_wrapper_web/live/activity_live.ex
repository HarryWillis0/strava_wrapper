defmodule StravaWrapperWeb.ActivityLive do
  use StravaWrapperWeb, :live_view

  alias StravaWrapper.ActivityStore

  @impl true
  def mount(_params, _session, socket) do
    activities = ActivityStore.all("default")
    socket = stream(socket, :activities, activities)
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 class="text-2xl font-bold mb-6">Activities</h1>
      <div class="overflow-x-auto">
        <table class="table w-full">
          <thead>
            <tr>
              <th>Name</th>
              <th>Date</th>
              <th>Type</th>
              <th>Distance</th>
              <th>Duration</th>
              <th>Gear</th>
            </tr>
          </thead>
          <tbody id="activities" phx-update="stream">
            <tr :for={{dom_id, activity} <- @streams.activities} id={dom_id}>
              <td>{activity.name}</td>
              <td>{format_date(activity.date)}</td>
              <td>{activity.type}</td>
              <td>{format_distance(activity.distance)}</td>
              <td>{format_duration(activity.duration)}</td>
              <td>{activity.gear_name || "—"}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end

  defp format_date(nil), do: "—"
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
  defp format_date(other), do: to_string(other)

  defp format_distance(nil), do: "—"
  defp format_distance(metres), do: "#{Float.round(metres / 1000, 1)} km"

  defp format_duration(nil), do: "—"

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading("#{secs}", 2, "0")}"
  end
end
