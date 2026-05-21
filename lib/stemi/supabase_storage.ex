defmodule Stemi.SupabaseStorage do
  @moduledoc """
  Uploads files to Supabase Storage for persistent image storage.
  Images survive Gigalixir redeploys since they're stored externally.
  """

  @bucket "case-images"

  defp supabase_url do
    System.get_env("SUPABASE_URL") || "https://qmlxbyywhccawiwrhrrv.supabase.co"
  end

  defp supabase_key do
    System.get_env("SUPABASE_KEY") || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtbHhieXl3aGNjYXdpd3JocnJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2NTU4NTksImV4cCI6MjA5MzIzMTg1OX0.q4JmdxqdebdS3UQtjxtf1yM0VUFNta-GKZbRG8LLKWY"
  end

  @doc "Upload a file and return the public URL"
  def upload(file_path, file_name) do
    content_type = MIME.from_path(file_name)
    body = File.read!(file_path)

    url = "#{supabase_url()}/storage/v1/object/#{@bucket}/#{file_name}"

    case Req.post(url,
      body: body,
      headers: [
        {"authorization", "Bearer #{supabase_key()}"},
        {"apikey", supabase_key()},
        {"content-type", content_type},
        {"x-upsert", "true"}
      ]
    ) do
      {:ok, %{status: status}} when status in [200, 201] ->
        public_url = "#{supabase_url()}/storage/v1/object/public/#{@bucket}/#{file_name}"
        {:ok, public_url}

      {:ok, resp} ->
        {:error, "Upload failed: #{inspect(resp.body)}"}

      {:error, err} ->
        {:error, "Upload error: #{inspect(err)}"}
    end
  end
end
