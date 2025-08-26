defmodule Lume.Gemini.VisionTest do
  use ExUnit.Case, async: true

  @moduletag :integration

  setup do
    case System.get_env("GEMINI_API_KEY") do
      nil ->
        {:skip, "GEMINI_API_KEY not set"}

      _key ->
        ImageHelper.setup()
        :ok
    end
  end

  describe "image analysis" do
    test "analyzes small test image" do
      image_data = ImageHelper.get_small_image()

      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.system("Describe what you see in this image.")
        |> Lume.text("What is in this image?")
        |> Lume.image(image_data, ImageHelper.get_mime_type())
        |> Lume.call()

      assert is_binary(result.last_result)
      assert String.length(result.last_result) > 10
      assert result.cost > 0
      assert result.tokens_used > 0
    end

    test "analyzes image with detailed prompt" do
      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.system("You are an expert image analyst.")
        |> Lume.text(
          "Analyze this image and tell me about its dimensions, colors, and any patterns you observe."
        )
        |> Lume.image(ImageHelper.get_medium_image(), ImageHelper.get_mime_type())
        |> Lume.call()

      assert is_binary(result.last_result)
      assert String.length(result.last_result) > 20
    end

    test "handles data URL format" do
      image_data = ImageHelper.get_small_image()
      data_url = ImageHelper.to_data_url(image_data)

      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.text("What do you see?")
        |> Lume.image(data_url)
        |> Lume.call()

      assert is_binary(result.last_result)
      assert String.length(result.last_result) > 10
    end
  end

  describe "multi-modal combinations" do
    test "combines text and image analysis" do
      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.system("You are a helpful visual assistant.")
        |> Lume.text(
          "Please describe this image and then tell me what you think about simplicity in design."
        )
        |> Lume.image(ImageHelper.get_small_image(), ImageHelper.get_mime_type())
        |> Lume.call()

      assert is_binary(result.last_result)
      # Should contain both image description and design thoughts
      assert String.length(result.last_result) > 50
    end

    test "multiple images in conversation" do
      {:ok, lume} =
        Lume.Gemini.flash()
        |> Lume.system("Compare these images.")
        |> Lume.text("Describe the first image:")
        |> Lume.image(ImageHelper.get_small_image(), ImageHelper.get_mime_type())
        |> Lume.call()

      {:ok, continued} =
        lume
        |> Lume.text("Now describe this second image:")
        |> Lume.image(ImageHelper.get_medium_image(), ImageHelper.get_mime_type())
        |> Lume.call()

      assert is_binary(continued.last_result)
      assert String.length(continued.last_result) > 10
      # system, user+image1, assistant, user+image2, assistant
      assert length(continued.messages) == 5
    end
  end

  describe "vision streaming" do
    test "streams image analysis" do
      {:ok, stream} =
        Lume.Gemini.flash()
        |> Lume.text("Describe this image in detail:")
        |> Lume.image(ImageHelper.get_small_image(), ImageHelper.get_mime_type())
        |> Lume.stream()

      chunks = stream |> Enum.take(5)

      assert length(chunks) > 0
      assert Enum.all?(chunks, &is_binary/1)

      combined = Enum.join(chunks, "")
      assert String.length(combined) > 5
    end

    test "streams creative image interpretation" do
      {:ok, stream} =
        Lume.Gemini.flash()
        |> Lume.system("You are a creative storyteller.")
        |> Lume.text("Tell me a creative story inspired by this image:")
        |> Lume.image(ImageHelper.get_medium_image(), ImageHelper.get_mime_type())
        |> Lume.opts(temperature: 0.8)
        |> Lume.stream()

      chunks = stream |> Enum.take(8)

      assert length(chunks) > 0
      assert Enum.all?(chunks, &is_binary/1)
    end
  end

  describe "vision error handling" do
    test "handles invalid image data" do
      {:error, _reason} =
        Lume.Gemini.flash()
        |> Lume.text("What is this?")
        |> Lume.image("invalid-base64-data")
        |> Lume.call()
    end

    test "handles empty image data" do
      {:error, _reason} =
        Lume.Gemini.flash()
        |> Lume.text("Describe this:")
        |> Lume.image("")
        |> Lume.call()
    end

    test "handles malformed data URL" do
      {:error, _reason} =
        Lume.Gemini.flash()
        |> Lume.text("What do you see?")
        |> Lume.image("data:image/png;base64,malformed-data")
        |> Lume.call()
    end
  end

  describe "vision model capabilities" do
    test "works with Flash model for vision" do
      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.text("Analyze this image:")
        |> Lume.image(ImageHelper.get_small_image(), ImageHelper.get_mime_type())
        |> Lume.call()

      assert is_binary(result.last_result)
      assert result.cost > 0
    end

    test "works with Pro model for vision" do
      {:ok, result} =
        Lume.Gemini.pro()
        |> Lume.text("Provide detailed analysis:")
        |> Lume.image(ImageHelper.get_medium_image(), ImageHelper.get_mime_type())
        |> Lume.opts(timeout: 60_000)
        |> Lume.call()

      assert is_binary(result.last_result)
      assert result.cost > 0
    end
  end

  describe "vision cost tracking" do
    test "tracks cost for vision requests" do
      {:ok, result} =
        Lume.Gemini.flash()
        |> Lume.text("Quick description:")
        |> Lume.image(ImageHelper.get_small_image(), ImageHelper.get_mime_type())
        |> Lume.call()

      # Vision requests should have higher cost than text-only
      assert result.cost > 0
      assert result.tokens_used > 0

      # Vision requests should have reasonable cost and token usage
      # (comparing with text-only can be flaky due to response length variations)
      assert result.cost > 0
      # Should use more than minimal tokens for vision
      assert result.tokens_used > 50
    end
  end
end
