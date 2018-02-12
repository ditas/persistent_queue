defmodule PerQTest do
  use ExUnit.Case
  doctest PerQ

  test "greets the world" do
    assert PerQ.hello() == :world
  end
end
