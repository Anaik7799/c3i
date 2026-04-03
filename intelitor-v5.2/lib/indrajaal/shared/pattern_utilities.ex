defmodule Indrajaal.Shared.PatternUtilities do
  @moduledoc """
  Shared utility module for common pattern matching and recognition operations.

  Created by Claude Supervisor for Task 6.3.3 - Maximum Parallelization
  Methodology: SOPv5.1 with TPS 5 - Level RCA
  Purpose: Centralize pattern operations to reduce code duplication and complexity
  """

  require Logger

  @doc """
  Matches data against multiple pattern templates with priority ordering.

  Supports complex pattern matching with wildcards, guards, and type matching.
  """
  @spec match_patterns(any(), list(map())) :: {:ok, map()} | {:error, :no_match}
  def match_patterns(data, pattern_definitions) do
    sorted_patterns = Enum.sort_by(pattern_definitions, &Map.get(&1, :priority, 0), :desc)

    case find_matching_pattern(data, sorted_patterns) do
      {:ok, pattern} -> {:ok, pattern}
      :no_match -> {:error, :no_match}
    end
  end

  @doc """
  Extracts structured data using pattern - based extraction rules.

  Enables flexible data extraction from complex nested structures.
  """
  @spec extract_by_patterns(any(), list(map())) :: map()
  def extract_by_patterns(data, extraction_patterns) do
    Enum.reduce(extraction_patterns, %{}, fn pattern, acc ->
      case apply_extraction_pattern(data, pattern) do
        {:ok, extracted_value} ->
          field_name = Map.get(pattern, :field_name, :extracted)
          Map.put(acc, field_name, extracted_value)

        :no_match ->
          acc
      end
    end)
  end

  @doc """
  Validates data structure against pattern schemas with detailed error reporting.

  Provides comprehensive validation with pattern - based rules and constraints.
  """
  @spec validate_by_patterns(any(), map()) :: {:ok, any()} | {:error, list()}
  def validate_by_patterns(data, pattern_schema) do
    required_patterns = Map.get(pattern_schema, :_required, [])
    optional_patterns = Map.get(pattern_schema, :optional, [])
    structural_rules = Map.get(pattern_schema, :structural_rules, [])

    with :ok <- validate_required_patterns(data, required_patterns),
         :ok <- validate_optional_patterns(data, optional_patterns),
         :ok <- validate_structural_rules(data, structural_rules) do
      {:ok, data}
    end
  end

  @doc """
  Transforms data based on pattern - matching transformation rules.

  Applies transformations selectively based on pattern matching results.
  """
  @spec transform_by_patterns(any(), list(map())) :: any()
  def transform_by_patterns(data, transformation_patterns) do
    Enum.reduce(transformation_patterns, data, fn pattern, acc_data ->
      if pattern_matches?(acc_data, Map.get(pattern, :match_pattern)) do
        apply_transformation_template(acc_data, Map.get(pattern, :transformation))
      else
        acc_data
      end
    end)
  end

  @doc """
  Recognizes and classifies patterns within data with confidence scoring.

  Provides pattern recognition with confidence levels and classification.
  """
  @spec recognize_patterns(any(), map()) :: list(map())
  def recognize_patterns(data, recognition_config) do
    pattern_types = Map.get(recognition_config, :pattern_types, [:structural, :value, :sequence])
    min_confidence = Map.get(recognition_config, :min_confidence, 0.7)

    pattern_types
    |> Enum.flat_map(fn pattern_type ->
      recognize_pattern_type(data, pattern_type, recognition_config)
    end)
    |> Enum.filter(fn pattern ->
      Map.get(pattern, :confidence, 0) >= min_confidence
    end)
    |> Enum.sort_by(&Map.get(&1, :confidence, 0), :desc)
  end

  @doc """
  Compares two data structures for pattern - based similarity.

  Returns similarity score and structural differences.
  """
  @spec compare_patterns(any(), any(), map()) :: map()
  def compare_patterns(data1, data2, comparison_config) do
    include_metadata = Map.get(comparison_config, :include_metadata, true)
    deep_comparison = Map.get(comparison_config, :deep_comparison, true)

    base_similarity = calculate_data_similarity(data1, data2)
    structural_diff = if deep_comparison, do: get_structural_differences(data1, data2), else: []

    result = %{
      similarity_score: base_similarity,
      differences: structural_diff,
      is_match: base_similarity >= Map.get(comparison_config, :match_threshold, 0.9)
    }

    if include_metadata do
      Map.put(result, :metadata, %{
        type1: get_data_type(data1),
        type2: get_data_type(data2),
        comparison_depth: if(deep_comparison, do: :deep, else: :shallow),
        timestamp: DateTime.utc_now()
      })
    else
      result
    end
  end

  @doc """
  Generates pattern templates from example data for future matching.

  Creates reusable pattern definitions from provided examples.
  """
  @spec generate_pattern_template(list(any())) :: map()
  def generate_pattern_template(example_data) when is_list(example_data) do
    if length(example_data) > 0 do
      common_structure = identify_common_structure(example_data)
      field_patterns = analyze_field_patterns(example_data)
      value_patterns = analyze_value_patterns(example_data)

      %{
        pattern_type: :generated,
        structure: common_structure,
        fields: field_patterns,
        values: value_patterns,
        confidence: calculate_template_confidence(example_data),
        sample_size: length(example_data)
      }
    else
      %{pattern_type: :empty, error: :no_examples_provided}
    end
  end

  def generate_pattern_template(_data) do
    %{pattern_type: :invalid, error: :invalid_input_format}
  end

  # Private helper functions

  defp find_matching_pattern(_data, []), do: :no_match

  defp find_matching_pattern(data, [pattern | rest]) do
    if pattern_matches?(data, pattern) do
      {:ok, pattern}
    else
      find_matching_pattern(data, rest)
    end
  end

  defp pattern_matches?(data, pattern) do
    pattern_type = Map.get(pattern, :type, :exact)

    case pattern_type do
      :exact -> exact_match?(data, Map.get(pattern, :value))
      :regex -> regex_match?(data, Map.get(pattern, :regex))
      :type -> type_match?(data, Map.get(pattern, :expected_type))
      :structure -> structure_match?(data, Map.get(pattern, :structure))
      :range -> range_match?(data, Map.get(pattern, :range))
      :contains -> contains_match?(data, Map.get(pattern, :contains))
      :custom -> custom_match?(data, Map.get(pattern, :matcher))
      _ -> false
    end
  end

  defp exact_match?(data, expected_value), do: data == expected_value

  defp regex_match?(data, regex_pattern) when is_binary(data) do
    case Regex.compile(regex_pattern) do
      {:ok, regex} -> Regex.match?(regex, data)
      {:error, _} -> false
    end
  end

  defp regex_match?(_data, _pattern), do: false

  defp type_match?(data, expected_type) do
    actual_type = get_data_type(data)
    actual_type == expected_type
  end

  defp structure_match?(data, expected_structure)
       when is_map(data) and is_map(expected_structure) do
    Enum.all?(expected_structure, fn {key, expected_value} ->
      if Map.has_key?(data, key) do
        value = Map.get(data, key)
        type_match?(value, expected_value)
      else
        false
      end
    end)
  end

  defp structure_match?(_data, _structure), do: false

  defp range_match?(data, %{min: min, max: max}) when is_number(data) do
    data >= min and data <= max
  end

  defp range_match?(_data, _range), do: false

  defp contains_match?(data, search_value) when is_list(data) do
    Enum.member?(data, search_value)
  end

  defp contains_match?(data, search_value) when is_binary(data) and is_binary(search_value) do
    String.contains?(data, search_value)
  end

  defp contains_match?(_data, _value), do: false

  defp custom_match?(data, matcher_function) when is_function(matcher_function, 1) do
    try do
      matcher_function.(data)
    rescue
      _ -> false
    end
  end

  defp custom_match?(_data, _matcher), do: false

  defp apply_extraction_pattern(data, pattern) do
    extraction_type = Map.get(pattern, :extraction_type, :direct)

    case extraction_type do
      :direct -> extract_direct_value(data, pattern)
      :path -> extract_by_path(data, pattern)
      :regex -> extract_by_regex(data, pattern)
      :aggregate -> extract_by_aggregation(data, pattern)
      :conditional -> extract_by_condition(data, pattern)
      _ -> :no_match
    end
  end

  defp extract_direct_value(data, pattern) do
    field = Map.get(pattern, :field)

    if is_map(data) and Map.has_key?(data, field) do
      {:ok, Map.get(data, field)}
    else
      :no_match
    end
  end

  defp extract_by_path(data, pattern) do
    path = Map.get(pattern, :path, [])

    try do
      result =
        Enum.reduce(path, data, fn key, acc ->
          cond do
            is_map(acc) -> Map.get(acc, key)
            is_list(acc) and is_integer(key) -> Enum.at(acc, key)
            true -> nil
          end
        end)

      if result != nil, do: {:ok, result}, else: :no_match
    rescue
      _ -> :no_match
    end
  end

  defp extract_by_regex(data, pattern) when is_binary(data) do
    regex_pattern = Map.get(pattern, :regex)
    capture_group = Map.get(pattern, :capture_group, 0)

    case Regex.run(~r/#{regex_pattern}/, data) do
      nil -> :no_match
      matches -> {:ok, Enum.at(matches, capture_group)}
    end
  end

  defp extract_by_regex(_data, _pattern), do: :no_match

  defp extract_by_aggregation(data, pattern) when is_list(data) do
    aggregation_type = Map.get(pattern, :aggregation, :count)
    field = Map.get(pattern, :field)

    values =
      if field do
        Enum.map(data, &Map.get(&1, field, 0))
      else
        data
      end

    result =
      case aggregation_type do
        :count -> length(values)
        :sum -> Enum.sum(values)
        :avg -> if length(values) > 0, do: Enum.sum(values) / length(values), else: 0
        :max -> Enum.max(values, fn -> nil end)
        :min -> Enum.min(values, fn -> nil end)
        _ -> nil
      end

    if result != nil, do: {:ok, result}, else: :no_match
  end

  defp extract_by_aggregation(_data, _pattern), do: :no_match

  defp extract_by_condition(data, pattern) do
    condition = Map.get(pattern, :condition)
    then_extraction = Map.get(pattern, :then)
    else_extraction = Map.get(pattern, :else)

    if evaluate_extraction_condition(data, condition) do
      if then_extraction, do: apply_extraction_pattern(data, then_extraction), else: {:ok, true}
    else
      if else_extraction, do: apply_extraction_pattern(data, else_extraction), else: {:ok, false}
    end
  end

  defp evaluate_extraction_condition(data, condition) do
    case Map.get(condition, :type) do
      :has_field ->
        field = Map.get(condition, :field)
        is_map(data) and Map.has_key?(data, field)

      :field_equals ->
        field = Map.get(condition, :field)
        value = Map.get(condition, :value)
        is_map(data) and Map.get(data, field) == value

      :field_greater_than ->
        field = Map.get(condition, :field)
        value = Map.get(condition, :value)
        is_map(data) and is_number(Map.get(data, field, 0)) and Map.get(data, field) > value

      :all ->
        conditions = Map.get(condition, :conditions, [])
        Enum.all?(conditions, &evaluate_extraction_condition(data, &1))

      :any ->
        conditions = Map.get(condition, :conditions, [])
        Enum.any?(conditions, &evaluate_extraction_condition(data, &1))

      _ ->
        false
    end
  end

  defp validate_required_patterns(data, required_patterns) do
    errors =
      Enum.reduce(required_patterns, [], fn pattern, acc ->
        if pattern_matches?(data, pattern) do
          acc
        else
          [{:missing_required_pattern, Map.get(pattern, :name, :unnamed)} | acc]
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  defp validate_optional_patterns(data, optional_patterns) do
    # Optional patterns don't fail validation, just track warnings
    warnings =
      Enum.reduce(optional_patterns, [], fn pattern, acc ->
        if pattern_matches?(data, pattern) do
          acc
        else
          [{:missing_optional_pattern, Map.get(pattern, :name, :unnamed)} | acc]
        end
      end)

    # Log warnings but don't fail
    if warnings != [], do: Logger.debug("Optional patterns missing: #{inspect(warnings)}")
    :ok
  end

  defp validate_structural_rules(data, structural_rules) do
    errors =
      Enum.reduce(structural_rules, [], fn rule, acc ->
        case validate_structural_rule(data, rule) do
          :ok -> acc
          {:error, reason} -> [reason | acc]
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  defp validate_structural_rule(data, rule) do
    rule_type = Map.get(rule, :rule_type)

    case rule_type do
      :min_fields -> validate_min_fields(data, rule)
      :max_fields -> validate_max_fields(data, rule)
      :_required_keys -> validate_required_keys(data, rule)
      :forbidden_keys -> validate_forbidden_keys(data, rule)
      :unique_values -> validate_unique_values(data, rule)
      _ -> :ok
    end
  end

  defp validate_min_fields(data, rule) when is_map(data) do
    min_count = Map.get(rule, :min, 0)
    actual_count = map_size(data)

    if actual_count >= min_count do
      :ok
    else
      {:error, {:too_few_fields, actual_count, min_count}}
    end
  end

  defp validate_min_fields(_data, _rule), do: :ok

  defp validate_max_fields(data, rule) when is_map(data) do
    max_count = Map.get(rule, :max, 100)
    actual_count = map_size(data)

    if actual_count <= max_count do
      :ok
    else
      {:error, {:too_many_fields, actual_count, max_count}}
    end
  end

  defp validate_max_fields(_data, _rule), do: :ok

  defp validate_required_keys(data, rule) when is_map(data) do
    required_keys = Map.get(rule, :keys, [])
    missing_keys = Enum.filter(required_keys, fn key -> not Map.has_key?(data, key) end)

    if missing_keys == [] do
      :ok
    else
      {:error, {:missing_required_keys, missing_keys}}
    end
  end

  defp validate_required_keys(_data, _rule), do: :ok

  defp validate_forbidden_keys(data, rule) when is_map(data) do
    forbidden_keys = Map.get(rule, :keys, [])
    found_forbidden = Enum.filter(forbidden_keys, fn key -> Map.has_key?(data, key) end)

    if found_forbidden == [] do
      :ok
    else
      {:error, {:forbidden_keys_present, found_forbidden}}
    end
  end

  defp validate_forbidden_keys(_data, _rule), do: :ok

  defp validate_unique_values(data, rule) when is_map(data) do
    check_fields = Map.get(rule, :fields, Map.keys(data))
    values = Enum.map(check_fields, &Map.get(data, &1))
    unique_count = values |> Enum.uniq() |> length()

    if unique_count == length(values) do
      :ok
    else
      {:error, {:duplicate_values_found, length(values) - unique_count}}
    end
  end

  defp validate_unique_values(_data, _rule), do: :ok

  defp apply_transformation_template(data, transformation) do
    transformation_type = Map.get(transformation, :type, :replace)

    case transformation_type do
      :replace -> apply_replace_transformation(data, transformation)
      :merge -> apply_merge_transformation(data, transformation)
      :map -> apply_map_transformation(data, transformation)
      :filter -> apply_filter_transformation(data, transformation)
      _ -> data
    end
  end

  defp apply_replace_transformation(data, transformation) do
    Map.get(transformation, :value, data)
  end

  defp apply_merge_transformation(data, transformation) when is_map(data) do
    merge_data = Map.get(transformation, :data, %{})
    Map.merge(data, merge_data)
  end

  defp apply_merge_transformation(data, _transformation), do: data

  defp apply_map_transformation(data, transformation) when is_list(data) do
    mapper = Map.get(transformation, :mapper)

    if is_function(mapper, 1) do
      Enum.map(data, mapper)
    else
      data
    end
  end

  defp apply_map_transformation(data, _transformation), do: data

  defp apply_filter_transformation(data, transformation) when is_list(data) do
    filter_func = Map.get(transformation, :filter)

    if is_function(filter_func, 1) do
      Enum.filter(data, filter_func)
    else
      data
    end
  end

  defp apply_filter_transformation(data, _transformation), do: data

  # NOTE: Kept for potential future use
  # defp calculate_pattern_confidence(data, pattern, _req) do
  #   base_confidence = if pattern_matches?(data, pattern), do: 1.0, else: 0.0
  #   complexity_factor = Map.get(pattern, :complexity, 1.0)
  #   specificity_factor = Map.get(pattern, :specificity, 1.0)
  #
  #   base_confidence * complexity_factor * specificity_factor
  # end

  defp recognize_pattern_type(data, pattern_type, recognition_config) do
    patterns =
      case pattern_type do
        :structural ->
          recognize_structural_patterns(data, recognition_config)

        :value ->
          recognize_value_patterns(data, recognition_config)

        :sequence ->
          recognize_sequence_patterns(data, recognition_config)

        _ ->
          []
      end

    Enum.map(patterns, &Map.put(&1, :pattern_type, pattern_type))
  end

  defp recognize_structural_patterns(data, _recognition_config) when is_map(data) do
    field_patterns = analyze_field_types(data)
    nesting_patterns = analyze_nesting_depth(data)

    [field_patterns | nesting_patterns]
    |> Enum.filter(&(&1 != nil))
  end

  defp recognize_structural_patterns(_data, _recognition_config), do: []

  defp recognize_value_patterns(data, _recognition_config) do
    frequencies = calculate_value_frequencies(data)

    Enum.map(frequencies, fn {value, count} ->
      %{
        pattern: %{type: :value_frequency, value: value},
        confidence: min(count / length(List.wrap(data)), 1.0),
        metadata: %{count: count, value: value}
      }
    end)
  end

  defp recognize_sequence_patterns(data, _recognition_config) when is_list(data) do
    if length(data) >= 2 do
      Enum.flat_map(2..min(length(data), 5), fn pattern_length ->
        find_repeating_sequences(data, pattern_length)
      end)
    else
      []
    end
  end

  defp recognize_sequence_patterns(_data, _recognition_config), do: []

  defp find_repeating_sequences(data, pattern_length) when is_list(data) do
    sequences =
      data
      |> Enum.chunk_every(pattern_length, 1, :discard)
      |> Enum.frequencies()
      |> Enum.filter(fn {_seq, count} -> count > 1 end)
      |> Enum.map(fn {seq, count} ->
        %{
          pattern: %{type: :sequence, sequence: seq, length: pattern_length},
          confidence: min(count / length(data), 1.0),
          metadata: %{repetitions: count}
        }
      end)

    sequences
  end

  defp find_repeating_sequences(_data, _pattern_length), do: []

  defp analyze_field_types(data) when is_map(data) do
    field_type_analysis =
      Map.new(data, fn {key, value} ->
        {key, %{type: get_data_type(value), sample: value}}
      end)

    %{
      pattern: %{field_types: field_type_analysis, field_count: map_size(data)},
      confidence: 1.0,
      metadata: %{analyzed_at: DateTime.utc_now()}
    }
  end

  defp analyze_field_types(_data), do: nil

  defp analyze_nesting_depth(data) do
    max_depth = calculate_max_depth(data)

    [
      %{
        pattern: %{type: :nesting_depth, max_depth: max_depth},
        confidence: 1.0,
        metadata: %{structure_complexity: max_depth}
      }
    ]
  end

  defp calculate_max_depth(data) when is_map(data) do
    if map_size(data) == 0 do
      1
    else
      data
      |> Map.values()
      |> Enum.map(&calculate_max_depth/1)
      |> Enum.max()
      |> Kernel.+(1)
    end
  end

  defp calculate_max_depth(data) when is_list(data) do
    if data == [] do
      1
    else
      data
      |> Enum.map(&calculate_max_depth/1)
      |> Enum.max()
      |> Kernel.+(1)
    end
  end

  defp calculate_max_depth(_data), do: 0

  defp calculate_value_frequencies(data) do
    all_values = extract_all_values(data)

    all_values
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_value, count} -> count end, :desc)
    |> Enum.take(10)
  end

  defp extract_all_values(data) when is_map(data) do
    Enum.flat_map(data, fn {_key, value} -> extract_all_values(value) end)
  end

  defp extract_all_values(data) when is_list(data) do
    Enum.flat_map(data, &extract_all_values/1)
  end

  defp extract_all_values(data), do: [data]

  defp identify_common_structure(example_data) do
    if length(example_data) > 0 do
      first_example = List.first(example_data)

      if is_map(first_example) do
        common_keys =
          example_data
          |> Enum.map(&Map.keys/1)
          |> Enum.reduce(&MapSet.intersection(MapSet.new(&1), MapSet.new(&2)))
          |> MapSet.to_list()

        %{type: :map, common_keys: common_keys}
      else
        %{type: get_data_type(first_example)}
      end
    else
      %{type: :unknown}
    end
  end

  defp analyze_field_patterns(example_data) do
    all_fields =
      example_data
      |> Enum.flat_map(fn data -> if is_map(data), do: Map.keys(data), else: [] end)
      |> Enum.uniq()

    Map.new(all_fields, fn field ->
      field_map_values = Enum.map(example_data, &Map.get(&1, field))
      field_values = Enum.filter(field_map_values, &(&1 != nil))

      type_list = Enum.map(field_values, &get_data_type/1)
      types = Enum.uniq(type_list)

      analysis = %{
        present_in: length(field_values),
        f_requency: length(field_values) / length(example_data),
        types: types,
        samples: Enum.take(field_values, 3)
      }

      {field, analysis}
    end)
  end

  defp analyze_value_patterns(example_data) do
    all_values =
      Enum.flat_map(example_data, fn data ->
        if is_map(data), do: Map.values(data), else: [data]
      end)

    value_types_mapped = Enum.map(all_values, &get_data_type/1)
    frequency_sorted = Enum.frequencies(all_values)

    %{
      total_values: length(all_values),
      unique_values: all_values |> Enum.uniq() |> length(),
      value_types: value_types_mapped |> Enum.frequencies(),
      value_frequencies:
        frequency_sorted |> Enum.sort_by(fn {_v, c} -> c end, :desc) |> Enum.take(10)
    }
  end

  defp calculate_template_confidence(example_data) do
    if length(example_data) < 2 do
      0.5
    else
      # Calculate confidence based on consistency of examples
      similarities =
        example_data
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [data1, data2] ->
          calculate_data_similarity(data1, data2)
        end)

      if length(similarities) > 0 do
        Enum.sum(similarities) / length(similarities)
      else
        0.5
      end
    end
  end

  defp calculate_data_similarity(data1, data2) do
    cond do
      is_map(data1) and is_map(data2) ->
        calculate_map_similarity(data1, data2)

      is_list(data1) and is_list(data2) ->
        calculate_list_similarity(data1, data2)

      get_data_type(data1) == get_data_type(data2) ->
        if data1 == data2, do: 1.0, else: 0.5

      true ->
        0.0
    end
  end

  defp calculate_map_similarity(map1, map2) do
    keys1 = MapSet.new(Map.keys(map1))
    keys2 = MapSet.new(Map.keys(map2))
    common_keys = MapSet.intersection(keys1, keys2)
    all_keys = MapSet.union(keys1, keys2)

    if MapSet.size(all_keys) == 0 do
      1.0
    else
      key_similarity = MapSet.size(common_keys) / MapSet.size(all_keys)

      value_similarities =
        common_keys
        |> Enum.map(fn key ->
          v1 = Map.get(map1, key)
          v2 = Map.get(map2, key)
          calculate_data_similarity(v1, v2)
        end)

      value_similarity =
        if length(value_similarities) > 0 do
          Enum.sum(value_similarities) / length(value_similarities)
        else
          0.0
        end

      (key_similarity + value_similarity) / 2.0
    end
  end

  defp calculate_list_similarity(list1, list2) do
    len1 = length(list1)
    len2 = length(list2)
    max_len = max(len1, len2)

    if max_len == 0 do
      1.0
    else
      min_len = min(len1, len2)
      common_items = min_len

      # Basic length similarity
      length_similarity = common_items / max_len

      # Type similarity for common items
      zipped_items = Enum.zip(Enum.take(list1, min_len), Enum.take(list2, min_len))

      type_similarities =
        zipped_items
        |> Enum.map(fn {item1, item2} ->
          if get_data_type(item1) == get_data_type(item2), do: 1.0, else: 0.0
        end)

      type_similarity =
        if length(type_similarities) > 0 do
          Enum.sum(type_similarities) / length(type_similarities)
        else
          0.0
        end

      (length_similarity + type_similarity) / 2.0
    end
  end

  defp get_structural_differences(data1, data2) do
    cond do
      is_map(data1) and is_map(data2) ->
        get_map_differences(data1, data2)

      is_list(data1) and is_list(data2) ->
        get_list_differences(data1, data2)

      get_data_type(data1) != get_data_type(data2) ->
        [{:different_types, get_data_type(data1), get_data_type(data2)}]

      data1 != data2 ->
        [{:different_values, data1, data2}]

      true ->
        []
    end
  end

  defp get_map_differences(map1, map2) do
    keys1 = MapSet.new(Map.keys(map1))
    keys2 = MapSet.new(Map.keys(map2))

    first_diff = MapSet.difference(keys1, keys2)
    only_in_first = MapSet.to_list(first_diff)

    second_diff = MapSet.difference(keys2, keys1)
    only_in_second = MapSet.to_list(second_diff)

    common_set = MapSet.intersection(keys1, keys2)
    common_keys = MapSet.to_list(common_set)

    key_differences =
      if(only_in_first != [], do: [{:keys_only_in_first, only_in_first}], else: []) ++
        if only_in_second != [], do: [{:keys_only_in_second, only_in_second}], else: []

    value_differences =
      common_keys
      |> Enum.flat_map(fn key ->
        v1 = Map.get(map1, key)
        v2 = Map.get(map2, key)

        if v1 != v2 do
          [{:value_difference, key, v1, v2}]
        else
          []
        end
      end)

    key_differences ++ value_differences
  end

  defp get_list_differences(list1, list2) do
    len1 = length(list1)
    len2 = length(list2)

    length_diff =
      if len1 != len2 do
        [{:different_lengths, len1, len2}]
      else
        []
      end

    zipped_indexed = Enum.zip(Enum.with_index(list1), Enum.with_index(list2))

    item_differences =
      zipped_indexed
      |> Enum.flat_map(fn {{item1, idx1}, {item2, _idx2}} ->
        if item1 != item2 do
          [{:item_difference, idx1, item1, item2}]
        else
          []
        end
      end)

    length_diff ++ item_differences
  end

  defp get_data_type(value) when is_binary(value), do: :string
  defp get_data_type(value) when is_integer(value), do: :integer
  defp get_data_type(value) when is_float(value), do: :float
  defp get_data_type(value) when is_boolean(value), do: :boolean
  defp get_data_type(value) when is_list(value), do: :list
  defp get_data_type(value) when is_map(value), do: :map
  defp get_data_type(value) when is_atom(value), do: :atom
  defp get_data_type(_value), do: :unknown
end
