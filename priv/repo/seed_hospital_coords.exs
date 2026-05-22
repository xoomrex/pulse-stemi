# Populate lat/lng for hospitals by parsing Google Maps URLs.
# Only works for direct coordinate URLs like:
#   https://www.google.com/maps/place/24.768675,46.789471
# Short URLs (goo.gl, maps.app.goo.gl) are skipped — they need manual entry.
alias Stemi.Repo
alias Stemi.Hospitals.Hospital
import Ecto.Query

hospitals = Repo.all(Hospital)

parse_coords = fn url ->
  case Regex.run(~r|/place/(-?\d+\.\d+),(-?\d+\.\d+)|, url || "") do
    [_, lat_str, lng_str] ->
      {lat, _} = Float.parse(lat_str)
      {lng, _} = Float.parse(lng_str)
      {lat, lng}
    _ -> nil
  end
end

{updated, skipped} =
  Enum.reduce(hospitals, {0, 0}, fn h, {u, s} ->
    case parse_coords.(h.map_url) do
      {lat, lng} ->
        Repo.update_all(
          from(x in Hospital, where: x.id == ^h.id),
          set: [lat: lat, lng: lng]
        )
        {u + 1, s}
      nil ->
        {u, s + 1}
    end
  end)

IO.puts("Updated #{updated} hospitals with coordinates.")
IO.puts("Skipped #{skipped} (short URLs or missing map_url).")
