defmodule Lume.OpenAI do
  @moduledoc """
  OpenAI provider shortcuts for easy model access.
  """

  def gpt4o(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.OpenAI)
    |> Lume.model("gpt-4o")
  end

  def gpt4o_mini(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.OpenAI)
    |> Lume.model("gpt-4o-mini")
  end

  def o1(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.OpenAI)
    |> Lume.model("o1-preview")
  end

  def o1_mini(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.OpenAI)
    |> Lume.model("o1-mini")
  end

  def gpt4_turbo(lume \\ nil) do
    (lume || Lume.new())
    |> Lume.provider(Lume.Providers.OpenAI)
    |> Lume.model("gpt-4-turbo")
  end
end
