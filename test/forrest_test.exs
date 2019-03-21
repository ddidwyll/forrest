defmodule ForrestTest do
  use ExUnit.Case
  doctest Forrest

  test "greets the world" do
    assert Forrest.hello() == :world
  end
end
