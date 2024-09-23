defmodule PredicateTest do
  use ExUnit.Case, async: true

  describe "get_nested/2 (fetch nested fields)" do
    test "existent paths" do
      assert Predicate.get_nested(%{"age" => 20}, ["age"]) == 20
      assert Predicate.get_nested(%{age: 20}, [:age]) == 20

      assert Predicate.get_nested(
               %{"doc" => %{"age" => 20}},
               ["doc", "age"]
             ) == 20

      assert Predicate.get_nested(
               %{"doc" => %{"age" => 20}},
               "doc.age"
             ) == 20

      assert Predicate.get_nested(
               %{"doc" => %{"age" => %{"year" => 1981, "month" => 12}}},
               "doc.age.year"
             ) == 1981
    end

    test "nonexistent paths" do
      assert Predicate.get_nested(%{"age" => 20}, ["year"]) == nil
      assert Predicate.get_nested(%{age: 20}, [:year]) == nil

      assert Predicate.get_nested(
               %{"doc" => %{"age" => 20}},
               ["doc", "year"]
             ) == nil

      assert Predicate.get_nested(
               %{"doc" => %{"age" => 20}},
               ["xdoc", "year"]
             ) == nil

      assert Predicate.get_nested(
               %{"doc" => %{"age" => 20}},
               "xdoc.age"
             ) == nil

      assert Predicate.get_nested(
               %{"doc" => %{"age" => %{"year" => 1981, "month" => 12}}},
               "doc.age.yearx"
             ) == nil

      assert Predicate.get_nested(
               %{"doc" => %{"age" => %{"year" => 1981, "month" => 12}}},
               "doc.agex.year"
             ) == nil
    end
  end

  describe "eval/2" do
    test "predicate :in" do
      obj = %{age: 25}
      assert Predicate.eval({:age, :in, [25, 30]}, obj)
      refute Predicate.eval({:age, :in, [30, 40]}, obj)
    end

    test "predicate :nin" do
      obj = %{age: 25}
      assert Predicate.eval({:age, :nin, [30, 40]}, obj)
      refute Predicate.eval({:age, :nin, [25, 30]}, obj)
    end

    test "predicate :gt" do
      obj = %{age: 25}
      assert Predicate.eval({:age, :gt, 20}, obj)
      refute Predicate.eval({:age, :gt, 30}, obj)
    end

    test "predicate :gte" do
      obj = %{age: 25}
      assert Predicate.eval({:age, :gte, 25}, obj)
      assert Predicate.eval({:age, :gte, 20}, obj)
      refute Predicate.eval({:age, :gte, 30}, obj)
    end

    test "predicate :lt" do
      obj = %{age: 25}
      assert Predicate.eval({:age, :lt, 30}, obj)
      refute Predicate.eval({:age, :lt, 20}, obj)
    end

    test "predicate :lte" do
      obj = %{age: 25}
      assert Predicate.eval({:age, :lte, 25}, obj)
      assert Predicate.eval({:age, :lte, 30}, obj)
      refute Predicate.eval({:age, :lte, 20}, obj)
    end

    test "predicate :ne" do
      obj = %{age: 25}
      assert Predicate.eval({:age, :ne, 30}, obj)
      refute Predicate.eval({:age, :ne, 25}, obj)
    end

    test "predicate :exists" do
      obj = %{age: 25}
      assert Predicate.eval({:age, :exists}, obj)
      refute Predicate.eval({:name, :exists}, obj)
    end

    test "predicate :regex" do
      obj = %{name: "John Doe"}
      assert Predicate.eval({:name, :regex, "John"}, obj)
      refute Predicate.eval({:name, :regex, "Jane"}, obj)
    end

    test "predicate :elem" do
      obj = %{list: [10, 20, 30]}
      assert Predicate.eval({:list, :elem, 1}, obj)
      refute Predicate.eval({:list, :elem, 3}, obj)
    end

    test "predicate :size" do
      obj = %{list: [1, 2, 3]}
      assert Predicate.eval({:list, :size, 3}, obj)
      refute Predicate.eval({:list, :size, 2}, obj)
    end

    test "predicate :mod" do
      obj = %{num: 10}
      assert Predicate.eval({:num, :mod, {2, 0}}, obj)
      refute Predicate.eval({:num, :mod, {3, 0}}, obj)
    end
  end

  describe "parser/1" do
    test "parses :in predicate" do
      assert Predicate.parse("age:in:25,30,35") == {:age, :in, [25, 30, 35]}
    end

    test "parses :nin predicate" do
      assert Predicate.parse("age:nin:25,30,35") == {:age, :nin, [25, 30, 35]}
    end

    test "parses :gt predicate" do
      assert Predicate.parse("age:gt:25") == {:age, :gt, 25}
    end

    test "parses :gte predicate" do
      assert Predicate.parse("age:gte:25") == {:age, :gte, 25}
    end

    test "parses :lt predicate" do
      assert Predicate.parse("age:lt:25") == {:age, :lt, 25}
    end

    test "parses :lte predicate" do
      assert Predicate.parse("age:lte:25") == {:age, :lte, 25}
    end

    test "parses :ne predicate" do
      assert Predicate.parse("age:ne:25") == {:age, :ne, 25}
    end

    test "parses :exists predicate" do
      assert Predicate.parse("age:exists") == {:age, :exists}
    end

    test "parses :regex predicate" do
      assert Predicate.parse("name:regex:^John") == {:name, :regex, "^John"}
    end

    test "parses :elem predicate" do
      assert Predicate.parse("list:elem:1") == {:list, :elem, 1}
    end

    test "parses :size predicate" do
      assert Predicate.parse("list:size:3") == {:list, :size, 3}
    end

    test "parses :mod predicate" do
      assert Predicate.parse("num:mod:2:0") == {:num, :mod, {2, 0}}
    end

    test "raises ArgumentError for invalid predicate" do
      assert_raise ArgumentError, "Invalid predicate -->invalid_predicate<--", fn ->
        Predicate.parse("invalid_predicate")
      end
    end
  end

  describe "combine/1" do
    test "empty list of actions" do
      assert Predicate.combine_actions([]).(%{age: 25})
      assert Predicate.combine_actions([]).(nil)
    end

    test "single action" do
      assert Predicate.combine_actions([{:age, :ne, 30}]).(%{age: 20})
    end

    test "multiple action" do
      assert Predicate.combine_actions([{:age, :ne, 30}, {:age, :gte, 20}]).(%{age: 20})

      assert Predicate.combine_actions([{:age, :ne, 30}, {:age, :gte, 20}, {:age, :mod, {5, 0}}]).(
               %{age: 20}
             )

      refute Predicate.combine_actions([{:age, :ne, 30}, {:age, :gte, 20}, {:age, :mod, {5, 1}}]).(
               %{age: 20}
             )
    end
  end
end
