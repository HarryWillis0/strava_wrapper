defmodule StravaWrapperWeb.ActivityLive do
  use StravaWrapperWeb, :live_view

  alias StravaWrapper.{ActivityStore, FilterEngine}

  @page_size 20

  @impl true
  def mount(_params, session, socket) do
    case session do
      %{"athlete_id" => athlete_id} ->
        activities = ActivityStore.all(athlete_id)
        gear_counts = Enum.frequencies_by(activities, & &1.gear_id)

        gear_options =
          activities
          |> Enum.reject(&is_nil(&1.gear_id))
          |> Enum.uniq_by(& &1.gear_id)
          |> Enum.map(fn a -> {a.gear_id, a.gear_name, Map.get(gear_counts, a.gear_id, 0)} end)

        total_pages = max(1, ceil(length(activities) / @page_size))

        socket =
          socket
          |> assign(
            athlete_id: athlete_id,
            gear_options: gear_options,
            total_activities_count: length(activities),
            no_gear_count: Map.get(gear_counts, nil, 0),
            active_filter: "all",
            filter: %{},
            page: 1,
            total_pages: total_pages,
            stats: FilterEngine.stats(activities)
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
    |> assign(total_pages: total_pages, stats: FilterEngine.stats(activities))
    |> stream(:activities, page_activities, reset: true)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 class="text-2xl font-bold mb-6">Activities</h1>
      <details open class="mb-6 border border-base-300 rounded-xl group">
        <summary class="px-4 py-3 cursor-pointer font-medium select-none flex items-center justify-between">
          {stats_label(@active_filter, @gear_options)}
          <.icon name="hero-chevron-down" class="w-4 h-4 transition-transform group-open:rotate-180" />
        </summary>
        <div class="px-4 pb-4 pt-2 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div class="bg-base-200 rounded-lg p-3">
            <div class="text-base-content/50 text-xs uppercase tracking-wide mb-1">Activities</div>
            <div class="text-xl font-bold">{format_count(@stats.total_count)}</div>
          </div>
          <div class="bg-base-200 rounded-lg p-3">
            <div class="text-base-content/50 text-xs uppercase tracking-wide mb-1">Distance</div>
            <div class="text-xl font-bold">{format_distance(@stats.total_distance)}</div>
          </div>
          <div class="bg-base-200 rounded-lg p-3">
            <div class="text-base-content/50 text-xs uppercase tracking-wide mb-1">Time</div>
            <div class="text-xl font-bold">{format_total_duration(@stats.total_duration)}</div>
          </div>
          <div class="bg-base-200 rounded-lg p-3">
            <div class="text-base-content/50 text-xs uppercase tracking-wide mb-1">
              <%= if @active_filter not in ["all", "none"] do %>
                Started using
              <% else %>
                First activity
              <% end %>
            </div>
            <div class="text-xl font-bold">{format_date(@stats.first_date)}</div>
          </div>
        </div>
        <%= if map_size(@stats.type_breakdown) > 0 do %>
          <div class="px-4 pb-4 pt-3 border-t border-base-300 flex flex-wrap gap-2">
            <span
              :for={{type, count} <- @stats.type_breakdown}
              class="px-3 py-1 rounded-full bg-base-200 text-sm font-medium"
            >
              {pluralize(count, type)}
            </span>
          </div>
        <% end %>
      </details>
      <div class="flex gap-6">
        <aside class="w-56 shrink-0">
          <h2 class="font-semibold mb-3 text-sm uppercase tracking-wide text-base-content/50">
            Filter by Gear
          </h2>
          <div class="flex flex-col gap-0.5">
            <button
              phx-click="filter_gear"
              phx-value-gear_id="all"
              class={[
                "text-left px-3 py-2 rounded-lg text-sm flex items-center justify-between",
                @active_filter == "all" && "bg-primary text-primary-content font-medium",
                @active_filter != "all" && "hover:bg-base-200"
              ]}
            >
              <span>All activities</span>
              <span class="text-xs tabular-nums opacity-60">{@total_activities_count}</span>
            </button>
            <button
              phx-click="filter_gear"
              phx-value-gear_id="none"
              class={[
                "text-left px-3 py-2 rounded-lg text-sm flex items-center justify-between",
                @active_filter == "none" && "bg-primary text-primary-content font-medium",
                @active_filter != "none" && "hover:bg-base-200"
              ]}
            >
              <span>No gear</span>
              <span class="text-xs tabular-nums opacity-60">{@no_gear_count}</span>
            </button>
            <%= if @gear_options != [] do %>
              <div class="border-t border-base-300 my-2"></div>
              <p class="px-3 mb-1 text-xs uppercase tracking-wide text-base-content/40">Gear</p>
            <% end %>
            <button
              :for={{gear_id, gear_name, count} <- @gear_options}
              phx-click="filter_gear"
              phx-value-gear_id={gear_id}
              class={[
                "text-left px-3 py-2 rounded-lg text-sm flex items-center justify-between",
                @active_filter == gear_id && "bg-primary text-primary-content font-medium",
                @active_filter != gear_id && "hover:bg-base-200"
              ]}
            >
              <span class="truncate">{gear_name || gear_id}</span>
              <span class="text-xs tabular-nums opacity-60 ml-2 shrink-0">{count}</span>
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

  defp stats_label("all", _gear_options), do: "Stats for all activities"
  defp stats_label("none", _gear_options), do: "Stats for untagged activities"

  defp stats_label(gear_id, gear_options) do
    name = Enum.find_value(gear_options, gear_id, fn {id, name, _} -> id == gear_id && name end)
    "Stats for #{name}"
  end

  defp pluralize(count, word), do: "#{count} #{word}#{if count != 1, do: "s"}"

  defp format_count(n) when n >= 1_000 do
    "#{div(n, 1_000)},#{String.pad_leading("#{rem(n, 1_000)}", 3, "0")}"
  end

  defp format_count(n), do: "#{n}"

  defp format_date(nil), do: "—"

  defp format_date(%DateTime{} = dt) do
    "#{Calendar.strftime(dt, "%b")} #{dt.day}, #{dt.year}"
  end

  defp format_date(other), do: to_string(other)

  defp format_distance(nil), do: "—"
  defp format_distance(metres), do: "#{Float.round(metres / 1000, 1)} km"

  defp format_duration(nil), do: "—"

  defp format_duration(seconds) do
    hours = div(seconds, 3_600)
    minutes = div(rem(seconds, 3_600), 60)
    secs = rem(seconds, 60)

    if hours > 0 do
      "#{hours}:#{String.pad_leading("#{minutes}", 2, "0")}:#{String.pad_leading("#{secs}", 2, "0")}"
    else
      "#{minutes}:#{String.pad_leading("#{secs}", 2, "0")}"
    end
  end

  defp format_total_duration(nil), do: "—"

  defp format_total_duration(seconds) do
    hours = div(seconds, 3_600)
    minutes = div(rem(seconds, 3_600), 60)

    cond do
      hours > 0 -> "#{hours}h #{minutes}m"
      minutes > 0 -> "#{minutes}m"
      true -> "#{seconds}s"
    end
  end
end
