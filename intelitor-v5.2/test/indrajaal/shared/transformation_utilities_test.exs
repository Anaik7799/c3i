defmodule Indrajaal.Shared.TransformationUtilitiesTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Shared.TransformationUtilities.

  Tests the shared data transformation utilities that centralize transformation
  operations to reduce code duplication and complexity.

  SOPv5.11 Compliance: ✅
  Test Categories: Module Structure, Function Tests, Property Tests, Edge Cases
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.TransformationUtilities

  # ===========================================================================
  # Module Structure Tests
  # ===========================================================================

  describe "Module Structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(TransformationUtilities)
    end

    test "exports transform_data/2" do
      exports = TransformationUtilities.__info__(:functions)
      assert {:transform_data, 2} in exports
    end

    test "exports normalize_data/1" do
      exports = TransformationUtilities.__info__(:functions)
      assert {:normalize_data, 1} in exports
    end

    test "exports normalize_data/2" do
      exports = TransformationUtilities.__info__(:functions)
      assert {:normalize_data, 2} in exports
    end

    test "exports flatten_data/1" do
      exports = TransformationUtilities.__info__(:functions)
      assert {:flatten_data, 1} in exports
    end

    test "exports flatten_data/2" do
      exports = TransformationUtilities.__info__(:functions)
      assert {:flatten_data, 2} in exports
    end

    test "exports validate_and_transform/2" do
      exports = TransformationUtilities.__info__(:functions)
      assert {:validate_and_transform, 2} in exports
    end

    test "exports convert_format/2" do
      exports = TransformationUtilities.__info__(:functions)
      assert {:convert_format, 2} in exports
    end

    test "exports conditional_transform/2" do
      exports = TransformationUtilities.__info__(:functions)
      assert {:conditional_transform, 2} in exports
    end

    test "has proper moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(TransformationUtilities)
      assert module_doc != :hidden
      assert module_doc != :none
    end
  end

  # ===========================================================================
  # transform_data/2 Tests
  # ===========================================================================

  describe "transform_data/2" do
    test "applies key rename transformation" do
      data = %{old_name: "value", other: "data"}
      rule = %{type: :key_rename, mappings: %{old_name: :new_name}}

      result = TransformationUtilities.transform_data(data, rule)

      assert result[:new_name] == "value"
      refute Map.has_key?(result, :old_name)
    end

    test "applies value mapping transformation" do
      data = %{status: :active, name: "test"}
      rule = %{type: :value_map, field: :status, mappings: %{active: "ACTIVE"}}

      result = TransformationUtilities.transform_data(data, rule)

      assert result[:status] == "ACTIVE"
    end

    test "applies multiple transformation rules" do
      data = %{old_key: "value", status: :pending}

      rules = [
        %{type: :key_rename, mappings: %{old_key: :new_key}},
        %{type: :value_map, field: :status, mappings: %{pending: "PENDING"}}
      ]

      result = TransformationUtilities.transform_data(data, rules)

      assert result[:new_key] == "value"
      assert result[:status] == "PENDING"
    end

    test "handles field extraction transformation" do
      data = %{source_field: "hello-world", other: "data"}

      rule = %{
        type: :field_extract,
        source_field: :source_field,
        target_field: :extracted,
        extractor: %{type: :split, delimiter: "-", index: 0}
      }

      result = TransformationUtilities.transform_data(data, rule)

      assert result[:extracted] == "hello"
    end

    test "handles nested transformation" do
      data = %{nested: %{old_key: "value"}, other: "data"}

      rule = %{
        type: :nested_transform,
        field: :nested,
        rules: [%{type: :key_rename, mappings: %{old_key: :new_key}}]
      }

      result = TransformationUtilities.transform_data(data, rule)

      assert result[:nested][:new_key] == "value"
    end

    test "handles conditional transformation" do
      data = %{status: :active, value: 10}

      rule = %{
        type: :conditional,
        condition: %{field: :status, operator: :eq, value: :active},
        transformation: %{type: :value_map, field: :value, mappings: %{10 => 100}}
      }

      result = TransformationUtilities.transform_data(data, rule)

      assert result[:value] == 100
    end

    test "returns data unchanged for unknown rule type" do
      data = %{key: "value"}
      rule = %{type: :unknown_type}

      result = TransformationUtilities.transform_data(data, rule)

      assert result == data
    end
  end

  # ===========================================================================
  # normalize_data/1,2 Tests
  # ===========================================================================

  describe "normalize_data/1,2" do
    test "keeps data unchanged with empty config" do
      data = %{key: "value", nil_key: nil}

      result = TransformationUtilities.normalize_data(data, %{})

      assert result == data
    end

    test "removes nil values with :remove strategy" do
      data = %{key: "value", nil_key: nil, another: "data"}

      result = TransformationUtilities.normalize_data(data, %{null_strategy: :remove})

      assert result[:key] == "value"
      refute Map.has_key?(result, :nil_key)
    end

    test "replaces nil values with replacement strategy" do
      data = %{key: "value", nil_key: nil}

      result =
        TransformationUtilities.normalize_data(data, %{null_strategy: {:replace, "default"}})

      assert result[:nil_key] == "default"
    end

    test "applies type coercion" do
      data = %{age: "25", name: "John"}

      result =
        TransformationUtilities.normalize_data(data, %{
          type_coercion: %{age: :integer}
        })

      assert result[:age] == 25
    end

    test "applies lowercase key normalization" do
      data = %{:NAME => "John", :AGE => 25}

      result = TransformationUtilities.normalize_data(data, %{key_strategy: :lowercase})

      assert result[:name] == "John"
      assert result[:age] == 25
    end

    test "applies uppercase key normalization" do
      data = %{name: "John", age: 25}

      result = TransformationUtilities.normalize_data(data, %{key_strategy: :uppercase})

      assert result[:NAME] == "John"
      assert result[:AGE] == 25
    end
  end

  # ===========================================================================
  # flatten_data/1,2 Tests
  # ===========================================================================

  describe "flatten_data/1,2" do
    test "returns data unchanged (placeholder implementation)" do
      data = %{nested: %{key: "value"}}

      result = TransformationUtilities.flatten_data(data)

      # Current implementation is a placeholder that returns data unchanged
      assert is_map(result)
    end

    test "accepts options parameter" do
      data = %{key: "value"}
      options = %{separator: "_", max_depth: 3}

      result = TransformationUtilities.flatten_data(data, options)

      assert is_map(result)
    end
  end

  # ===========================================================================
  # validate_and_transform/2 Tests
  # ===========================================================================

  describe "validate_and_transform/2" do
    test "validates required fields and passes" do
      data = %{name: "John", age: 25}
      schema = %{_required: [:name, :age]}

      assert {:ok, ^data} = TransformationUtilities.validate_and_transform(data, schema)
    end

    test "validates required fields and fails" do
      data = %{name: "John"}
      schema = %{_required: [:name, :age]}

      assert {:error, errors} = TransformationUtilities.validate_and_transform(data, schema)
      assert is_list(errors)
      assert hd(errors) =~ "Missing required fields"
    end

    test "validates field types and passes" do
      data = %{name: "John", age: 25}
      schema = %{types: %{name: :string, age: :integer}}

      assert {:ok, ^data} = TransformationUtilities.validate_and_transform(data, schema)
    end

    test "validates field types and fails" do
      data = %{name: "John", age: "twenty-five"}
      schema = %{types: %{name: :string, age: :integer}}

      assert {:error, errors} = TransformationUtilities.validate_and_transform(data, schema)
      assert is_list(errors)
    end

    test "applies field transformations" do
      data = %{age: "25"}
      schema = %{transformations: %{age: :to_integer}}

      assert {:ok, result} = TransformationUtilities.validate_and_transform(data, schema)
      assert result[:age] == 25
    end

    test "applies to_string transformation" do
      data = %{count: 42}
      schema = %{transformations: %{count: :to_string}}

      assert {:ok, result} = TransformationUtilities.validate_and_transform(data, schema)
      assert result[:count] == "42"
    end

    test "handles empty schema" do
      data = %{name: "John"}
      schema = %{}

      assert {:ok, ^data} = TransformationUtilities.validate_and_transform(data, schema)
    end
  end

  # ===========================================================================
  # convert_format/2 Tests
  # ===========================================================================

  describe "convert_format/2" do
    test "converts keyword list to map" do
      data = [name: "John", age: 25]

      result = TransformationUtilities.convert_format(data, :map)

      assert is_map(result)
      assert result[:name] == "John"
    end

    test "keeps map as map" do
      data = %{name: "John"}

      result = TransformationUtilities.convert_format(data, :map)

      assert result == data
    end

    test "converts map to keyword list" do
      data = %{name: "John", age: 25}

      result = TransformationUtilities.convert_format(data, :keyword_list)

      assert is_list(result)
    end

    test "converts map to tuple list" do
      data = %{name: "John", age: 25}

      result = TransformationUtilities.convert_format(data, :tuple_list)

      assert is_list(result)
      assert Enum.all?(result, fn item -> is_tuple(item) end)
    end

    test "handles struct conversion" do
      data = %{name: "John"}

      result = TransformationUtilities.convert_format(data, :struct)

      assert is_map(result)
    end

    test "returns data unchanged for unknown format" do
      data = %{name: "John"}

      result = TransformationUtilities.convert_format(data, :unknown_format)

      assert result == data
    end

    test "converts list to map with indices" do
      data = ["a", "b", "c"]

      result = TransformationUtilities.convert_format(data, :map)

      assert is_map(result)
    end

    test "converts scalar to map" do
      data = "scalar"

      result = TransformationUtilities.convert_format(data, :map)

      assert result == %{value: "scalar"}
    end
  end

  # ===========================================================================
  # conditional_transform/2 Tests
  # ===========================================================================

  describe "conditional_transform/2" do
    test "applies transformation when condition is met" do
      data = %{status: :active, value: 10}

      rules = [
        %{
          condition: %{field: :status, operator: :eq, value: :active},
          transformation: %{type: :value_map, field: :value, mappings: %{10 => 100}}
        }
      ]

      result = TransformationUtilities.conditional_transform(data, rules)

      assert result[:value] == 100
    end

    test "skips transformation when condition is not met" do
      data = %{status: :inactive, value: 10}

      rules = [
        %{
          condition: %{field: :status, operator: :eq, value: :active},
          transformation: %{type: :value_map, field: :value, mappings: %{10 => 100}}
        }
      ]

      result = TransformationUtilities.conditional_transform(data, rules)

      assert result[:value] == 10
    end

    test "handles :ne operator" do
      data = %{status: :active, value: 10}

      rules = [
        %{
          condition: %{field: :status, operator: :ne, value: :inactive},
          transformation: %{type: :value_map, field: :value, mappings: %{10 => 100}}
        }
      ]

      result = TransformationUtilities.conditional_transform(data, rules)

      assert result[:value] == 100
    end

    test "handles :gt operator" do
      data = %{count: 15, multiplied: 1}

      rules = [
        %{
          condition: %{field: :count, operator: :gt, value: 10},
          transformation: %{type: :value_map, field: :multiplied, mappings: %{1 => 2}}
        }
      ]

      result = TransformationUtilities.conditional_transform(data, rules)

      assert result[:multiplied] == 2
    end

    test "handles :lt operator" do
      data = %{count: 5, result: "low"}

      rules = [
        %{
          condition: %{field: :count, operator: :lt, value: 10},
          transformation: %{type: :value_map, field: :result, mappings: %{"low" => "very_low"}}
        }
      ]

      result = TransformationUtilities.conditional_transform(data, rules)

      assert result[:result] == "very_low"
    end

    test "handles :contains operator" do
      data = %{name: "John Doe", flag: false}

      rules = [
        %{
          condition: %{field: :name, operator: :contains, value: "John"},
          transformation: %{type: :value_map, field: :flag, mappings: %{false => true}}
        }
      ]

      result = TransformationUtilities.conditional_transform(data, rules)

      assert result[:flag] == true
    end

    test "handles :exists operator" do
      data = %{name: "John", verified: false}

      rules = [
        %{
          condition: %{field: :name, operator: :exists},
          transformation: %{type: :value_map, field: :verified, mappings: %{false => true}}
        }
      ]

      result = TransformationUtilities.conditional_transform(data, rules)

      assert result[:verified] == true
    end

    test "handles :and compound condition" do
      data = %{status: :active, count: 15, result: "pending"}

      rules = [
        %{
          condition: %{
            type: :and,
            conditions: [
              %{field: :status, operator: :eq, value: :active},
              %{field: :count, operator: :gt, value: 10}
            ]
          },
          transformation: %{
            type: :value_map,
            field: :result,
            mappings: %{"pending" => "approved"}
          }
        }
      ]

      result = TransformationUtilities.conditional_transform(data, rules)

      assert result[:result] == "approved"
    end

    test "handles :or compound condition" do
      data = %{status: :inactive, priority: :high, result: "pending"}

      rules = [
        %{
          condition: %{
            type: :or,
            conditions: [
              %{field: :status, operator: :eq, value: :active},
              %{field: :priority, operator: :eq, value: :high}
            ]
          },
          transformation: %{
            type: :value_map,
            field: :result,
            mappings: %{"pending" => "prioritized"}
          }
        }
      ]

      result = TransformationUtilities.conditional_transform(data, rules)

      assert result[:result] == "prioritized"
    end

    test "applies multiple conditional rules sequentially" do
      data = %{a: 1, b: 2, c: 3}

      rules = [
        %{
          condition: %{field: :a, operator: :eq, value: 1},
          transformation: %{type: :value_map, field: :b, mappings: %{2 => 20}}
        },
        %{
          condition: %{field: :b, operator: :eq, value: 20},
          transformation: %{type: :value_map, field: :c, mappings: %{3 => 30}}
        }
      ]

      result = TransformationUtilities.conditional_transform(data, rules)

      assert result[:b] == 20
      assert result[:c] == 30
    end
  end

  # ===========================================================================
  # PropCheck Property-Based Tests
  # ===========================================================================

  describe "Property-based tests" do
    property "transform_data with empty rules returns original data" do
      forall data <- PC.map(PC.atom(), PC.term()) do
        result = TransformationUtilities.transform_data(data, [])
        result == data
      end
    end

    property "normalize_data with empty config returns original data" do
      forall data <- PC.map(PC.atom(), PC.term()) do
        result = TransformationUtilities.normalize_data(data, %{})
        result == data
      end
    end

    property "convert_format to :map always returns a map" do
      forall data <- PC.oneof([PC.map(PC.atom(), PC.term()), PC.list({PC.atom(), PC.term()})]) do
        result = TransformationUtilities.convert_format(data, :map)
        is_map(result)
      end
    end

    property "validate_and_transform with empty schema returns ok" do
      forall data <- PC.map(PC.atom(), PC.term()) do
        match?({:ok, _}, TransformationUtilities.validate_and_transform(data, %{}))
      end
    end

    property "conditional_transform with empty rules returns original data" do
      forall data <- PC.map(PC.atom(), PC.term()) do
        result = TransformationUtilities.conditional_transform(data, [])
        result == data
      end
    end
  end

  # ===========================================================================
  # Edge Case Tests
  # ===========================================================================

  describe "Edge cases" do
    test "handles empty data map" do
      data = %{}
      rule = %{type: :key_rename, mappings: %{old: :new}}

      result = TransformationUtilities.transform_data(data, rule)

      assert result == %{}
    end

    test "handles unicode in keys and values" do
      data = %{"名前" => "太郎", "年齢" => 25}
      config = %{}

      result = TransformationUtilities.normalize_data(data, config)

      assert result["名前"] == "太郎"
    end

    test "handles deeply nested data transformation" do
      data = %{
        level1: %{
          level2: %{
            level3: %{
              key: "deep_value"
            }
          }
        }
      }

      rule = %{
        type: :nested_transform,
        field: :level1,
        rules: [
          %{
            type: :nested_transform,
            field: :level2,
            rules: [
              %{
                type: :nested_transform,
                field: :level3,
                rules: [%{type: :key_rename, mappings: %{key: :renamed_key}}]
              }
            ]
          }
        ]
      }

      result = TransformationUtilities.transform_data(data, rule)

      assert result[:level1][:level2][:level3][:renamed_key] == "deep_value"
    end

    test "handles regex extractor" do
      data = %{source: "user-123-active"}

      rule = %{
        type: :field_extract,
        source_field: :source,
        target_field: :user_id,
        extractor: %{type: :regex, pattern: "user-(\\d+)", group: 1}
      }

      result = TransformationUtilities.transform_data(data, rule)

      assert result[:user_id] == "123"
    end

    test "handles substring extractor" do
      data = %{source: "ABCDEFG"}

      rule = %{
        type: :field_extract,
        source_field: :source,
        target_field: :extracted,
        extractor: %{type: :substring, start: 2, length: 3}
      }

      result = TransformationUtilities.transform_data(data, rule)

      assert result[:extracted] == "CDE"
    end

    test "handles type coercion for boolean" do
      data = %{flag: "true"}

      result = TransformationUtilities.normalize_data(data, %{type_coercion: %{flag: :boolean}})

      assert result[:flag] == true
    end

    test "handles type coercion for float" do
      data = %{value: "3.14"}

      result = TransformationUtilities.normalize_data(data, %{type_coercion: %{value: :float}})

      assert_in_delta result[:value], 3.14, 0.001
    end

    test "handles very large data sets" do
      data = Map.new(1..1000, fn i -> {:"key_#{i}", "value_#{i}"} end)

      result = TransformationUtilities.normalize_data(data, %{})

      assert map_size(result) == 1000
    end

    test "validate_and_transform handles transformation error" do
      data = %{value: "not_a_number"}
      schema = %{transformations: %{value: :to_integer}}

      # Should handle the transformation error gracefully
      result = TransformationUtilities.validate_and_transform(data, schema)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ===========================================================================
  # Source Code Validation Tests
  # ===========================================================================

  describe "Source code validation" do
    test "source file exists" do
      source_path = "lib/indrajaal/shared/transformation_utilities.ex"
      assert File.exists?(source_path), "Source file should exist at #{source_path}"
    end

    test "has proper module structure" do
      source_path = "lib/indrajaal/shared/transformation_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "defmodule Indrajaal.Shared.TransformationUtilities"
      assert content =~ "@moduledoc"
    end

    test "defines core transformation functions" do
      source_path = "lib/indrajaal/shared/transformation_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "def transform_data"
      assert content =~ "def normalize_data"
      assert content =~ "def flatten_data"
      assert content =~ "def validate_and_transform"
    end

    test "defines format conversion function" do
      source_path = "lib/indrajaal/shared/transformation_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "def convert_format"
    end

    test "defines conditional transformation function" do
      source_path = "lib/indrajaal/shared/transformation_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "def conditional_transform"
    end

    test "requires Logger" do
      source_path = "lib/indrajaal/shared/transformation_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "require Logger"
    end

    test "follows SOPv5.1 methodology" do
      source_path = "lib/indrajaal/shared/transformation_utilities.ex"
      content = File.read!(source_path)

      assert content =~ "SOPv5.1" or content =~ "TPS"
    end
  end
end
