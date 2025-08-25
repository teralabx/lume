defmodule LumeTest do
  use ExUnit.Case
  doctest Lume

  test "greets the world" do
    assert Lume.hello() == :world
  end
end
