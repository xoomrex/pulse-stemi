defmodule StemiWeb.EmsMapHelpers do
  @moduledoc "Shared EMS map toggle + location update handlers for all role views."

  defmacro __using__(_opts) do
    quote do
      # --- EMS Map Handlers ---

      @impl true
      def handle_info({:ems_location_updated, case_data}, socket) do
        if socket.assigns[:show_map] && socket.assigns[:selected_case] &&
             socket.assigns.selected_case.id == case_data.id do
          {:noreply,
           Phoenix.LiveView.push_event(socket, "update_ems_position", %{
             lat: case_data.ems_lat,
             lng: case_data.ems_lng
           })}
        else
          {:noreply, socket}
        end
      end

      @impl true
      def handle_event("toggle_map", _params, socket) do
        c = socket.assigns.selected_case

        if socket.assigns[:show_map] do
          {:noreply,
           socket
           |> Phoenix.Component.assign(:show_map, false)
           |> Phoenix.LiveView.push_event("hide_ems_map", %{})}
        else
          if c && c.ems_lat && c.ems_lng do
            label = "EMS — #{Stemi.Cases.Case.display_id(c)}"

            {:noreply,
             socket
             |> Phoenix.Component.assign(:show_map, true)
             |> Phoenix.LiveView.push_event("show_ems_map", %{
               lat: c.ems_lat,
               lng: c.ems_lng,
               label: label
             })}
          else
            {:noreply, Phoenix.LiveView.put_flash(socket, :info, "No EMS location data yet.")}
          end
        end
      end
    end
  end
end
