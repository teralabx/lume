defmodule Lume.Gemini do
  @moduledoc """
  Gemini provider shortcuts for easy model access.
  """

  def flash(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.Gemini)
    |> Lume.model("gemini-2.5-flash")
  end

  def pro(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.Gemini)
    |> Lume.model("gemini-2.5-pro")
  end

  def flash_2_0(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.Gemini)
    |> Lume.model("gemini-2.0-flash")
  end

  def flash_1_5(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.Gemini)
    |> Lume.model("gemini-1.5-flash")
  end

  def pro_1_5(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.Gemini)
    |> Lume.model("gemini-1.5-pro")
  end
end
