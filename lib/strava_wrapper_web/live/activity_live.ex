defmodule StravaWrapperWeb.ActivityLive do
  use StravaWrapperWeb, :live_view

  alias StravaWrapper.ActivityStore

  @page_size 20

  @impl true
  def mount(_params, session, socket) do
    case session do
      %{"athlete_id" => athlete_id} ->
        activities = ActivityStore.all(athlete_id)

        gear_options =
          activities
          |> Enum.map(fn a -> {a.gear_id, a.gear_name} end)
          |> Enum.reject(fn {id, _} -> is_nil(id) end)
          |> Enum.uniq_by(fn {id, _} -> id end)

        total_pages = max(1, ceil(length(activities) / @page_size))

        socket =
          socket
          |> assign(
            athlete_id: athlete_id,
            gear_options: gear_options,
            active_filter: "all",
            filter: %{},
            page: 1,
            total_pages: total_pages
          )
          |> stream(:activities, Enum.take(activities, @page_size))

        {:ok, socket}

      _ ->
        {:ok, push_navigate(socket, to: ~p"/auth/strava")}
    end
  end

  @impl true
  def handle_event("filter_gear", %{"gear_id" => "all"}, socket) do
    socket =
      socket
      |> assign(active_filter: "all", filter: %{}, page: 1)
      |> stream_page()

    {:noreply, socket}
  end

  def handle_event("filter_gear", %{"gear_id" => "none"}, socket) do
    socket =
      socket
      |> assign(active_filter: "none", filter: %{gear_id: nil}, page: 1)
      |> stream_page()

    {:noreply, socket}
  end

  def handle_event("filter_gear", %{"gear_id" => gear_id}, socket) do
    socket =
      socket
      |> assign(active_filter: gear_id, filter: %{gear_id: gear_id}, page: 1)
      |> stream_page()

    {:noreply, socket}
  end

  def handle_event("prev_page", _, socket) do
    socket =
      socket
      |> assign(page: max(1, socket.assigns.page - 1))
      |> stream_page()

    {:noreply, socket}
  end

  def handle_event("next_page", _, socket) do
    socket =
      socket
      |> assign(page: min(socket.assigns.total_pages, socket.assigns.page + 1))
      |> stream_page()

    {:noreply, socket}
  end

  defp stream_page(socket) do
    %{athlete_id: athlete_id, filter: filter, page: page} = socket.assigns

    activities =
      case filter do
        %{} = f when map_size(f) == 0 -> ActivityStore.all(athlete_id)
        f -> ActivityStore.filter(athlete_id, f)
      end

    total_pages = max(1, ceil(length(activities) / @page_size))
    page_activities = activities |> Enum.drop((page - 1) * @page_size) |> Enum.take(@page_size)

    socket
    |> assign(total_pages: total_pages)
    |> stream(:activities, page_activities, reset: true)
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
          <div class="flex items-center justify-between mt-4">
            <button
              phx-click="prev_page"
              disabled={@page == 1}
              class="px-3 py-1 rounded text-sm border disabled:opacity-40"
            >
              &larr; Prev
            </button>
            <span class="text-sm text-base-content/60">Page {@page} of {@total_pages}</span>
            <button
              phx-click="next_page"
              disabled={@page == @total_pages}
              class="px-3 py-1 rounded text-sm border disabled:opacity-40"
            >
              Next &rarr;
            </button>
          </div>
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
