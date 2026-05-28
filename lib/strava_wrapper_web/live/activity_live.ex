defmodule StravaWrapperWeb.ActivityLive do
  use StravaWrapperWeb, :live_view

  alias StravaWrapper.ActivityStore

  @impl true
  def mount(_params, _session, socket) do
    activities = ActivityStore.all("default")

    gear_options =
      activities
      |> Enum.map(fn a -> {a.gear_id, a.gear_name} end)
      |> Enum.reject(fn {id, _} -> is_nil(id) end)
      |> Enum.uniq_by(fn {id, _} -> id end)

    socket =
      socket
      |> assign(gear_options: gear_options, active_filter: "all")
      |> stream(:activities, activities)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_gear", %{"gear_id" => "all"}, socket) do
    activities = ActivityStore.all("default")
    socket = stream(socket, :activities, activities, reset: true)
    {:noreply, assign(socket, active_filter: "all")}
  end

  def handle_event("filter_gear", %{"gear_id" => "none"}, socket) do
    activities = ActivityStore.filter("default", %{gear_id: nil})
    socket = stream(socket, :activities, activities, reset: true)
    {:noreply, assign(socket, active_filter: "none")}
  end

  def handle_event("filter_gear", %{"gear_id" => gear_id}, socket) do
    activities = ActivityStore.filter("default", %{gear_id: gear_id})
    socket = stream(socket, :activities, activities, reset: true)
    {:noreply, assign(socket, active_filter: gear_id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 class="text-2xl font-bold mb-6">Activities</h1>
      <div class="flex gap-6">
        <aside class="w-48 shrink-0">
          <h2 class="font-semibold mb-3 text-sm uppercase tracking-wide">Filter by Gear</h2>
          <div class="flex flex-col gap-1">
            <button
              phx-click="filter_gear"
              phx-value-gear_id="all"
              class={[
                "text-left px-3 py-2 rounded text-sm",
                @active_filter == "all" && "bg-primary text-primary-content font-medium"
              ]}
            >
              All activities
            </button>
            <button
              phx-click="filter_gear"
              phx-value-gear_id="none"
              class={[
                "text-left px-3 py-2 rounded text-sm",
                @active_filter == "none" && "bg-primary text-primary-content font-medium"
              ]}
            >
              No gear
            </button>
            <button
              :for={{gear_id, gear_name} <- @gear_options}
              phx-click="filter_gear"
              phx-value-gear_id={gear_id}
              class={[
                "text-left px-3 py-2 rounded text-sm",
                @active_filter == gear_id && "bg-primary text-primary-content font-medium"
              ]}
            >
              {gear_name || gear_id}
            </button>
          </div>
        </aside>
        <div class="flex-1 overflow-x-auto">
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
