defmodule Lume.Media do
  @moduledoc """
  Media file handling utilities for images, audio, and other file types.
  """

  @supported_image_types ~w(.jpg .jpeg .png .gif .webp .bmp)
  @supported_audio_types ~w(.mp3 .wav .m4a .aac .ogg .flac)

  @doc """
  Read and encode a local file for AI processing.
  Supports images and audio files. Returns base64 encoded content.
  """
  def read_file(file_path) when is_binary(file_path) do
    cond do
      image_file?(file_path) -> read_image(file_path)
      audio_file?(file_path) -> read_audio(file_path)
      true -> {:error, :unsupported_file_type}
    end
  end

  @doc """
  Read and encode an image file to base64.
  """
  def read_image(file_path) when is_binary(file_path) do
    with true <- File.exists?(file_path),
         true <- image_file?(file_path),
         {:ok, binary_data} <- File.read(file_path) do
      base64_data = Base.encode64(binary_data)
      mime_type = MIME.from_path(file_path)
      {:ok, "data:#{mime_type};base64,#{base64_data}"}
    else
      false -> {:error, :file_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Read and encode an audio file to base64.
  """
  def read_audio(file_path) when is_binary(file_path) do
    with true <- File.exists?(file_path),
         true <- audio_file?(file_path),
         {:ok, binary_data} <- File.read(file_path) do
      base64_data = Base.encode64(binary_data)
      mime_type = MIME.from_path(file_path)
      {:ok, "data:#{mime_type};base64,#{base64_data}"}
    else
      false -> {:error, :file_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Check if a file path points to a supported image file.
  """
  def image_file?(file_path) do
    extension = Path.extname(file_path) |> String.downcase()
    extension in @supported_image_types
  end

  @doc """
  Check if a file path points to a supported audio file.
  """
  def audio_file?(file_path) do
    extension = Path.extname(file_path) |> String.downcase()
    extension in @supported_audio_types
  end

  @doc """
  Check if content is already base64 encoded (starts with data: prefix).
  """
  def base64_encoded?(content) when is_binary(content) do
    String.starts_with?(content, "data:")
  end

  @doc """
  Smart content processing - reads file if it's a local path, otherwise passes through URLs and binary strings.
  """
  def process_content(content) when is_binary(content) do
    cond do
      # Already base64 encoded data
      base64_encoded?(content) ->
        {:ok, content}

      # HTTP/HTTPS URL
      String.starts_with?(content, "http") ->
        {:ok, content}

      # Local file path
      File.exists?(content) and (image_file?(content) or audio_file?(content)) ->
        read_file(content)

      # Binary string or unknown format - pass through
      true ->
        {:ok, content}
    end
  end
end
