defmodule MintyTest do
  use ExUnit.Case
  doctest Minty

  test "greets the world" do
    assert Minty.hello() == :world
  end
end
