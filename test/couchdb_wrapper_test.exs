defmodule CouchdbWrapperTest do
  use ExUnit.Case
  doctest CouchdbWrapper

  test "greets the world" do
    assert CouchdbWrapper.hello() == :world
  end
end
