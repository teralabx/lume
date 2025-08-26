defmodule LumeTest do
  use ExUnit.Case, async: true
  doctest Lume

  test "creates new Lume instance" do
    lume = Lume.new()
    assert %Lume{} = lume
    assert lume.messages == []
    assert lume.cost == 0.0
    assert lume.tokens_used == 0
  end
end
