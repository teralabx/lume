defmodule ImageHelper do
  @moduledoc """
  Test helper for downloading and managing test images.
  """

  @cache_dir "/tmp/lume_test_images"

  def setup do
    File.mkdir_p!(@cache_dir)
  end

  @doc """
  Downloads a test image from Lorem Picsum and returns base64 encoded data.
  Images are cached to avoid repeated downloads.
  """
  def get_test_image(width \\ 300, height \\ 200, seed \\ 42) do
    cache_file = Path.join(@cache_dir, "#{width}x#{height}_#{seed}.jpg")
    
    if File.exists?(cache_file) do
      cache_file
      |> File.read!()
      |> Base.encode64()
    else
      download_and_cache_image(width, height, seed, cache_file)
    end
  end

  @doc """
  Gets a small test image (suitable for quick tests)
  """
  def get_small_image do
    get_test_image(100, 100, 1)
  end

  @doc """
  Gets a medium test image (suitable for detailed analysis)
  """
  def get_medium_image do
    get_test_image(400, 300, 2)
  end

  @doc """
  Returns the MIME type for test images (always JPEG from Lorem Picsum)
  """
  def get_mime_type do
    "image/jpeg"
  end

  @doc """
  Creates a data URL for the image
  """
  def to_data_url(base64_data) do
    "data:#{get_mime_type()};base64,#{base64_data}"
  end

  defp download_and_cache_image(width, height, seed, cache_file) do
    url = "https://picsum.photos/#{width}/#{height}?random=#{seed}"
    
    case Req.get(url, redirect: true) do
      {:ok, %{status: 200, body: body}} ->
        File.write!(cache_file, body)
        Base.encode64(body)
      
      {:error, reason} ->
        raise "Failed to download test image: #{inspect(reason)}"
        
      {:ok, %{status: status}} ->
        raise "Failed to download test image, status: #{status}"
    end
  end

  @doc """
  Clean up cached images (for test cleanup)
  """
  def cleanup do
    if File.exists?(@cache_dir) do
      File.rm_rf!(@cache_dir)
    end
  end
end