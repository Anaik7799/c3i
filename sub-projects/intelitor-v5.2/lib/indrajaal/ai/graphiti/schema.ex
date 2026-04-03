defmodule Indrajaal.AI.Graphiti.Schema do
  @moduledoc """
  Ecto-based schemas for structured AI knowledge extraction.

  ## Purpose

  Defines the data structures that the LLM must output. Uses Ecto validation
  to enforce business rules on AI-generated content. Invalid outputs trigger
  automatic retries via Instructor.

  ## Schemas

  - `Fact`: A single knowledge graph edge (source -> target with label)
  - `Extraction`: The complete extraction result with chain-of-thought

  ## STAMP Constraints

  - SC-AI-201: Schema-enforced LLM output
  - SC-AI-202: Validation before storage
  - SC-AI-203: Chain-of-thought required for reasoning trace

  ## Usage

      # Define expected structure
      {:ok, extraction} = Instructor.chat_completion(
        response_model: Indrajaal.AI.Graphiti.Schema.Extraction,
        ...
      )

      # Access validated facts
      for fact <- extraction.facts do
        IO.puts("\#{fact.source} --[\#{fact.label}]--> \#{fact.target}")
      end
  """

  # ---------------------------------------------------------------------------
  # Fact Schema: A Single Graph Edge
  # ---------------------------------------------------------------------------

  defmodule Fact do
    @moduledoc """
    Represents a single knowledge graph fact (edge).

    ## Fields

    - `source`: The origin entity (e.g., "Alice")
    - `target`: The destination entity (e.g., "OpenRouter")
    - `label`: The relationship type in UPPER_SNAKE_CASE (e.g., "WORKS_AT")
    - `category`: Entity type classification
    - `confidence`: Extraction confidence (0-100, must be >= 75)

    ## Validation Rules

    1. Source and target cannot be empty
    2. Label must be UPPER_SNAKE_CASE format
    3. Confidence must be >= 75%
    4. Category must be a known type
    """

    use Ecto.Schema
    import Ecto.Changeset

    @type t :: %__MODULE__{
            source: String.t(),
            target: String.t(),
            label: String.t(),
            category: atom(),
            confidence: integer()
          }

    @categories [:person, :organization, :location, :concept, :event, :product, :technology]

    @primary_key false
    embedded_schema do
      field :source, :string
      field :target, :string
      field :label, :string
      field :category, Ecto.Enum, values: @categories
      field :confidence, :integer, default: 80
    end

    @doc """
    Returns the list of valid entity categories.
    """
    @spec categories() :: [atom()]
    def categories, do: @categories

    @doc """
    Creates a changeset for a Fact.

    Validates:
    - Required fields present
    - Label format (UPPER_SNAKE_CASE)
    - Confidence threshold (>= 75)
    """
    @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
    def changeset(fact, attrs) do
      fact
      |> cast(attrs, [:source, :target, :label, :category, :confidence])
      |> validate_required([:source, :target, :label, :category])
      |> validate_format(:label, ~r/^[A-Z][A-Z0-9_]*$/,
        message: "must be UPPER_SNAKE_CASE (e.g., WORKS_AT, HAS_ROLE)"
      )
      |> validate_number(:confidence,
        greater_than_or_equal_to: 75,
        message: "must be >= 75 for reliable facts"
      )
      |> validate_inclusion(:category, @categories)
      |> validate_length(:source, min: 1, max: 500)
      |> validate_length(:target, min: 1, max: 500)
      |> validate_length(:label, min: 2, max: 100)
    end

    @doc """
    Validates a Fact changeset. Called by Instructor.
    """
    @spec validate_changeset(Ecto.Changeset.t()) :: Ecto.Changeset.t()
    def validate_changeset(changeset), do: changeset
  end

  # ---------------------------------------------------------------------------
  # Extraction Schema: Complete Extraction Result
  # ---------------------------------------------------------------------------

  defmodule Extraction do
    @moduledoc """
    The complete result of a knowledge extraction operation.

    ## Fields

    - `chain_of_thought`: The LLM's reasoning process (required)
    - `facts`: List of extracted knowledge graph facts
    - `summary`: Brief summary of what was extracted
    - `entity_count`: Number of unique entities found

    ## Chain of Thought

    The `chain_of_thought` field forces the LLM to reason step-by-step
    before generating facts. This improves accuracy and provides an
    audit trail for the extraction.
    """

    use Ecto.Schema
    import Ecto.Changeset

    alias Indrajaal.AI.Graphiti.Schema.Fact

    @type t :: %__MODULE__{
            chain_of_thought: String.t(),
            facts: [Fact.t()],
            summary: String.t() | nil,
            entity_count: integer()
          }

    @primary_key false
    embedded_schema do
      field :chain_of_thought, :string
      field :summary, :string
      field :entity_count, :integer, default: 0
      embeds_many :facts, Fact, on_replace: :delete
    end

    @doc """
    Creates a changeset for an Extraction.
    """
    @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
    def changeset(extraction, attrs) do
      extraction
      |> cast(attrs, [:chain_of_thought, :summary, :entity_count])
      |> validate_required([:chain_of_thought])
      |> validate_length(:chain_of_thought,
        min: 10,
        message: "reasoning trace must be at least 10 characters"
      )
      |> cast_embed(:facts, with: &Fact.changeset/2)
      |> compute_entity_count()
    end

    @doc """
    Validates an Extraction changeset. Called by Instructor.
    """
    @spec validate_changeset(Ecto.Changeset.t()) :: Ecto.Changeset.t()
    def validate_changeset(changeset), do: changeset

    # Compute unique entity count from facts
    defp compute_entity_count(changeset) do
      case get_field(changeset, :facts) do
        nil ->
          changeset

        [] ->
          put_change(changeset, :entity_count, 0)

        facts ->
          entities =
            facts
            |> Enum.flat_map(fn f -> [f.source, f.target] end)
            |> Enum.uniq()
            |> length()

          put_change(changeset, :entity_count, entities)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Query Schema: For querying the knowledge graph
  # ---------------------------------------------------------------------------

  defmodule Query do
    @moduledoc """
    Schema for structured knowledge graph queries.
    """

    use Ecto.Schema
    import Ecto.Changeset

    @type t :: %__MODULE__{
            entity: String.t() | nil,
            label: String.t() | nil,
            category: atom() | nil,
            temporal: atom()
          }

    @primary_key false
    embedded_schema do
      field :entity, :string
      field :label, :string
      field :category, Ecto.Enum, values: Fact.categories()
      field :temporal, Ecto.Enum, values: [:current, :historical, :all], default: :current
    end

    @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
    def changeset(query, attrs) do
      query
      |> cast(attrs, [:entity, :label, :category, :temporal])
    end
  end
end
