defmodule Indrajaal.AI.Graphiti.SchemaTest do
  @moduledoc """
  Tests for Graphiti Schema modules (Fact, Extraction, Query).

  ## STAMP Constraints Verified
  - SC-AI-201: Schema-enforced LLM output
  - SC-AI-202: Validation before storage
  - SC-AI-203: Chain-of-thought required
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.Graphiti.Schema.{Fact, Extraction, Query}

  describe "Fact schema" do
    test "valid fact passes changeset validation" do
      attrs = %{
        source: "Alice",
        target: "OpenRouter",
        label: "WORKS_AT",
        category: :person,
        confidence: 85
      }

      changeset = Fact.changeset(%Fact{}, attrs)

      assert changeset.valid?
      fact = Ecto.Changeset.apply_changes(changeset)
      assert fact.source == "Alice"
      assert fact.target == "OpenRouter"
      assert fact.label == "WORKS_AT"
      assert fact.category == :person
      assert fact.confidence == 85
    end

    test "rejects empty source" do
      attrs = %{
        source: "",
        target: "OpenRouter",
        label: "WORKS_AT",
        category: :person
      }

      changeset = Fact.changeset(%Fact{}, attrs)

      refute changeset.valid?
      # Empty string triggers "can't be blank" from validate_required
      assert "can't be blank" in errors_on(changeset, :source)
    end

    test "rejects empty target" do
      attrs = %{
        source: "Alice",
        target: "",
        label: "WORKS_AT",
        category: :person
      }

      changeset = Fact.changeset(%Fact{}, attrs)

      refute changeset.valid?
      # Empty string triggers "can't be blank" from validate_required
      assert "can't be blank" in errors_on(changeset, :target)
    end

    test "rejects invalid label format (lowercase)" do
      attrs = %{
        source: "Alice",
        target: "OpenRouter",
        label: "works_at",
        category: :person,
        confidence: 80
      }

      changeset = Fact.changeset(%Fact{}, attrs)

      refute changeset.valid?
      assert "must be UPPER_SNAKE_CASE (e.g., WORKS_AT, HAS_ROLE)" in errors_on(changeset, :label)
    end

    test "rejects low confidence" do
      attrs = %{
        source: "Alice",
        target: "OpenRouter",
        label: "WORKS_AT",
        category: :person,
        confidence: 50
      }

      changeset = Fact.changeset(%Fact{}, attrs)

      refute changeset.valid?
      assert "must be >= 75 for reliable facts" in errors_on(changeset, :confidence)
    end

    test "rejects invalid category" do
      attrs = %{
        source: "Alice",
        target: "OpenRouter",
        label: "WORKS_AT",
        category: :invalid_category,
        confidence: 80
      }

      changeset = Fact.changeset(%Fact{}, attrs)

      refute changeset.valid?
    end

    test "accepts all valid categories" do
      for category <- Fact.categories() do
        attrs = %{
          source: "Test",
          target: "Target",
          label: "RELATED_TO",
          category: category,
          confidence: 80
        }

        changeset = Fact.changeset(%Fact{}, attrs)
        assert changeset.valid?, "Category #{category} should be valid"
      end
    end

    test "categories/0 returns expected list" do
      categories = Fact.categories()

      assert :person in categories
      assert :organization in categories
      assert :location in categories
      assert :concept in categories
      assert :event in categories
      assert :product in categories
      assert :technology in categories
      assert length(categories) == 7
    end

    test "defaults confidence to 80" do
      attrs = %{
        source: "Alice",
        target: "OpenRouter",
        label: "WORKS_AT",
        category: :person
      }

      changeset = Fact.changeset(%Fact{}, attrs)
      fact = Ecto.Changeset.apply_changes(changeset)

      assert fact.confidence == 80
    end
  end

  describe "Extraction schema" do
    test "valid extraction with facts passes validation" do
      attrs = %{
        chain_of_thought:
          "Step 1: Analyzed text. Step 2: Found entities Alice and OpenRouter. Step 3: Identified WORKS_AT relationship.",
        summary: "Alice works at OpenRouter",
        facts: [
          %{
            source: "Alice",
            target: "OpenRouter",
            label: "WORKS_AT",
            category: :person,
            confidence: 85
          }
        ]
      }

      changeset = Extraction.changeset(%Extraction{}, attrs)

      assert changeset.valid?
      extraction = Ecto.Changeset.apply_changes(changeset)
      assert extraction.chain_of_thought =~ "Step 1"
      assert extraction.summary == "Alice works at OpenRouter"
      assert length(extraction.facts) == 1
      # Alice and OpenRouter
      assert extraction.entity_count == 2
    end

    test "requires chain_of_thought" do
      attrs = %{
        summary: "Summary without reasoning",
        facts: []
      }

      changeset = Extraction.changeset(%Extraction{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset, :chain_of_thought)
    end

    test "chain_of_thought must be at least 10 characters" do
      attrs = %{
        chain_of_thought: "Short",
        facts: []
      }

      changeset = Extraction.changeset(%Extraction{}, attrs)

      refute changeset.valid?

      assert "reasoning trace must be at least 10 characters" in errors_on(
               changeset,
               :chain_of_thought
             )
    end

    test "computes entity_count from facts" do
      attrs = %{
        chain_of_thought: "Extracted entities from text analysis",
        facts: [
          %{
            source: "Alice",
            target: "OpenRouter",
            label: "WORKS_AT",
            category: :person,
            confidence: 80
          },
          %{
            source: "Bob",
            target: "OpenRouter",
            label: "WORKS_AT",
            category: :person,
            confidence: 80
          },
          %{source: "Alice", target: "Bob", label: "KNOWS", category: :person, confidence: 75}
        ]
      }

      changeset = Extraction.changeset(%Extraction{}, attrs)
      extraction = Ecto.Changeset.apply_changes(changeset)

      # Unique entities: Alice, OpenRouter, Bob = 3
      assert extraction.entity_count == 3
    end

    test "empty facts results in entity_count of 0" do
      attrs = %{
        chain_of_thought: "No entities found in the text",
        facts: []
      }

      changeset = Extraction.changeset(%Extraction{}, attrs)
      extraction = Ecto.Changeset.apply_changes(changeset)

      assert extraction.entity_count == 0
    end

    test "summary is optional" do
      attrs = %{
        chain_of_thought: "Analyzed the text but no summary needed",
        facts: []
      }

      changeset = Extraction.changeset(%Extraction{}, attrs)

      assert changeset.valid?
      extraction = Ecto.Changeset.apply_changes(changeset)
      assert extraction.summary == nil
    end

    test "embedded facts are validated" do
      attrs = %{
        chain_of_thought: "Extracted invalid facts from text",
        facts: [
          %{
            source: "Alice",
            target: "OpenRouter",
            label: "invalid_label",
            category: :person,
            confidence: 80
          }
        ]
      }

      changeset = Extraction.changeset(%Extraction{}, attrs)

      refute changeset.valid?
    end
  end

  describe "Query schema" do
    test "accepts valid query with all fields" do
      attrs = %{
        entity: "Alice",
        label: "WORKS_AT",
        category: :person,
        temporal: :current
      }

      changeset = Query.changeset(%Query{}, attrs)

      assert changeset.valid?
      query = Ecto.Changeset.apply_changes(changeset)
      assert query.entity == "Alice"
      assert query.label == "WORKS_AT"
      assert query.category == :person
      assert query.temporal == :current
    end

    test "all fields are optional" do
      changeset = Query.changeset(%Query{}, %{})

      assert changeset.valid?
    end

    test "defaults temporal to :current" do
      changeset = Query.changeset(%Query{}, %{})
      query = Ecto.Changeset.apply_changes(changeset)

      assert query.temporal == :current
    end

    test "accepts all temporal values" do
      for temporal <- [:current, :historical, :all] do
        changeset = Query.changeset(%Query{}, %{temporal: temporal})
        assert changeset.valid?, "Temporal #{temporal} should be valid"
      end
    end
  end

  # Helper to extract error messages from changeset
  defp errors_on(changeset, field) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    Map.get(errors, field, [])
  end
end
