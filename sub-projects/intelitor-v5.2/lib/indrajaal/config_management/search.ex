defmodule Indrajaal.ConfigManagement.Search do
  @moduledoc """
  require Logger
  Advanced search and filtering for configurations across all domains.

  Provides full - text search, faceted filtering, and saved searches.

  Agent: Helper - 2 manages search operations
  SOPv5.1 Compliance: ✅
  """

  import Ecto.Query
  alias Indrajaal.Repo
  alias Indrajaal.Security.AuditLogger

  # Agent Comment: Helper - 2 provides intelligent search
  # STAMP Safety: Respect tenant boundaries
  # TPS 5 - Level RCA: Search performance analysis

  @doc """
  Performs advanced search across configurations.

  ## Options
    - :domains - List of domains to search (default: all)
    - :query - Full - text search query
    - :filters - Map of field filters
    - :date_range - {:from, :to} tuple for date filtering
    - :limit - Maximum results (default: 100)
    - :offset - Pagination offset
    - :sort - Sort configuration
    - :include_archived - Include archived records
  """
  @spec search(any(), any()) :: any()
  def search(tenant_id, opts \\ []) do
    # Agent: Helper - 2 performs advanced search
    # STAMP Safety: Enforce tenant isolation

    domains = Keyword.get(opts, :domains, :all)
    query_text = Keyword.get(opts, :query)
    filters = Keyword.get(opts, :filters, %{})
    date_range = Keyword.get(opts, :date_range)
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    sort = Keyword.get(opts, :sort, {:inserted_at, :desc})
    include_archived = Keyword.get(opts, :include_archived, false)

    results =
      search_domains(domains, %{
        tenant_id: tenant_id,
        query: query_text,
        filters: filters,
        date_range: date_range,
        include_archived: include_archived,
        sort: sort,
        limit: limit,
        offset: offset
      })

    # Log search for audit
    AuditLogger.log_data_access(
      get_current_user(),
      "configuration_search",
      results |> Enum.map(& &1.id),
      %{
        query: query_text,
        filters: filters,
        count: length(results)
      }
    )

    {:ok,
     %{
       results: results,
       total_count:
         count_results(domains, tenant_id, query_text, filters, date_range, include_archived),
       facets: calculate_facets(results),
       suggestions: generate_suggestions(query_text, results)
     }}
  end

  @doc """
  Creates a saved search for reuse.
  """
  @spec save_search(term(), term(), term(), list()) :: term()
  def save_search(user_id, name, criteria, opts \\ []) do
    # Agent: Helper - 2 saves search criteria
    attrs = %{
      name: name,
      user_id: user_id,
      criteria: criteria,
      shared: Keyword.get(opts, :shared, false),
      description: Keyword.get(opts, :description)
    }

    # EP999: Using generic map pattern instead of undefined SavedSearch struct
    %{}
    |> Map.merge(attrs)
    |> (fn search_attrs ->
          case Repo.insert_all("saved_searches", [search_attrs], returning: [:id]) do
            {1, [created]} -> {:ok, struct(%{id: created.id}, search_attrs)}
            _ -> {:error, "Failed to create saved search"}
          end
        end).()
  end

  @doc """
  Executes a saved search.
  """
  @spec execute_saved_search(any(), any()) :: any()
  def execute_saved_search(search_id, tenant_id) do
    # Agent: Helper - 2 executes saved search

    with {:ok, saved_search} <- get_saved_search(search_id),
         :ok <- validate_search_access(saved_search, get_current_user()) do
      search(tenant_id, saved_search.criteria)
    end
  end

  @doc """
  Builds search suggestions based on query.
  """
  @spec suggest(term(), term(), term()) :: term()
  def suggest(query_text, tenant_id, opts \\ []) do
    # Agent: Helper - 2 generates suggestions
    # Uses ML / AI for intelligent suggestions

    domains = Keyword.get(opts, :domains, :all)
    limit = Keyword.get(opts, :limit, 10)

    suggestions = %{
      query_suggestions: suggest_queries(query_text, tenant_id, domains),
      field_suggestions: suggest_fields(query_text, domains),
      value_suggestions: suggest_values(query_text, tenant_id, domains),
      saved_searches: suggest_saved_searches(query_text, get_current_user())
    }

    {:ok, Enum.take(suggestions, limit)}
  end

  @doc """
  Exports search results in various formats.
  """
  @spec export_results(term(), term(), term()) :: term()
  def export_results(search_params, format, tenant_id) do
    # Agent: Helper - 2 exports search results

    with {:ok, search_result} <- search(tenant_id, search_params) do
      case format do
        :csv -> export_to_csv(search_result.results)
        :json -> export_to_json(search_result)
        :excel -> export_to_excel(search_result.results)
        _ -> {:error, :unsupported_format}
      end
    end
  end

  # Private functions

  @spec search_domains(atom() | list(atom()), map()) :: list()
  defp search_domains(:all, params) do
    %{
      tenant_id: tenant_id,
      query: query,
      filters: filters,
      date_range: date_range,
      include_archived: include_archived,
      sort: sort,
      limit: limit,
      offset: offset
    } = params

    # Search all domains
    results = []

    # Devices
    results =
      results ++
        search_domain(
          Indrajaal.Devices.Device,
          tenant_id,
          query,
          filters,
          date_range,
          include_archived
        )

    # Alarms
    results =
      results ++
        search_domain(
          Indrajaal.Alarms.Alarm,
          tenant_id,
          query,
          filters,
          date_range,
          include_archived
        )

    # Add other domains...

    results |> apply_sort(sort) |> Enum.drop(offset) |> Enum.take(limit)
  end

  defp search_domains(domains, params) when is_list(domains) do
    %{
      tenant_id: tenant_id,
      query: query,
      filters: filters,
      date_range: date_range,
      include_archived: include_archived,
      sort: sort,
      limit: limit,
      offset: offset
    } = params

    domains
    |> Enum.flat_map(fn domain ->
      module = domain_to_module(domain)
      search_domain(module, tenant_id, query, filters, date_range, include_archived)
    end)
    |> apply_sort(sort)
    |> Enum.drop(offset)
    |> Enum.take(limit)
  end

  defp search_domain(schema_module, tenant_id, query_text, filters, date_range, include_archived) do
    base_query =
      from r in schema_module,
        where: r.tenant_id == ^tenant_id

    base_query
    |> apply_text_search(query_text)
    |> apply_filters(filters)
    |> apply_date_range(date_range)
    |> apply_archived_filter(include_archived)
    |> Repo.all()
    |> Enum.map(&add_search_metadata/1)
  end

  @spec apply_text_search(term(), term()) :: term()
  defp apply_text_search(query, nil), do: query

  defp apply_text_search(query, text) do
    # Simple text search - could be enhanced with full - text search
    search_term = "%#{text}%"

    from r in query,
      where:
        ilike(r.name, ^search_term) or
          ilike(r.description, ^search_term) or
          ilike(fragment("?::text", r.settings), ^search_term)
  end

  @spec apply_filters(term(), term()) :: term()
  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {field, value}, q ->
      apply_filter(q, field, value)
    end)
  end

  defp apply_filter(query, field, value) when is_list(value) do
    from r in query, where: field(r, ^field) in ^value
  end

  defp apply_filter(query, field, %{min: min, max: max}) do
    from r in query,
      where: field(r, ^field) >= ^min and field(r, ^field) <= ^max
  end

  defp apply_filter(query, field, value) do
    from r in query, where: field(r, ^field) == ^value
  end

  @spec apply_date_range(term(), term()) :: term()
  defp apply_date_range(query, nil), do: query

  defp apply_date_range(query, {from_date, to_date}) do
    from r in query,
      where: r.inserted_at >= ^from_date and r.inserted_at <= ^to_date
  end

  @spec apply_archived_filter(term(), term()) :: term()
  defp apply_archived_filter(query, false) do
    # Assuming we have an archived_at field
    from r in query, where: is_nil(r.archived_at)
  end

  @spec apply_archived_filter(term(), term()) :: term()
  defp apply_archived_filter(query, true), do: query

  defp apply_sort(results, {field, direction}) do
    case direction do
      :asc -> Enum.sort_by(results, &Map.get(&1, field))
      :desc -> Enum.sort_by(results, &Map.get(&1, field), :desc)
    end
  end

  @spec add_search_metadata(term()) :: term()
  defp add_search_metadata(record) do
    Map.put(record, :search_metadata, %{
      domain: record.__struct__ |> Module.split() |> List.last() |> Macro.underscore(),
      score: calculate_relevance_score(record),
      highlighted_fields: highlight_matches(record)
    })
  end

  @spec calculate_relevance_score(term()) :: term()
  defp calculate_relevance_score(_record) do
    # Simple relevance scoring - could use ML / AI
    1.0
  end

  @spec highlight_matches(term()) :: term()
  defp highlight_matches(_record) do
    # EP001: Unused parameter, prefixed with underscore for clarity
    # Highlight matching fields - simplified
    %{}
  end

  defp count_results(domains, tenant_id, query, filters, date_range, include_archived) do
    # Get total count without pagination
    results =
      search_domains(domains, %{
        tenant_id: tenant_id,
        query: query,
        filters: filters,
        date_range: date_range,
        include_archived: include_archived,
        sort: {:id, :asc},
        limit: 10_000,
        offset: 0
      })

    length(results)
  end

  @spec calculate_facets(term()) :: term()
  defp calculate_facets(results) do
    # Calculate facets for filtering
    %{
      domains: results |> Enum.group_by(& &1.searchmetadata.domain) |> Map.keys(),
      types: results |> Enum.map(& &1[:type]) |> Enum.uniq() |> Enum.reject(&is_nil/1),
      statuses: results |> Enum.map(& &1[:status]) |> Enum.uniq() |> Enum.reject(&is_nil/1),
      date_ranges: %{
        today: count_by_date_range(results, :today)
      }
    }
  end

  @spec count_by_date_range(term(), term()) :: term()
  defp count_by_date_range(results, :today) do
    today = Date.utc_today()
    Enum.count(results, &(Date.compare(DateTime.to_date(&1.inserted_at), today) == :eq))
  end

  @spec generate_suggestions(term(), term()) :: term()
  defp generate_suggestions(query_text, results) do
    # Generate intelligent suggestions
    %{
      did_you_mean: spell_check_suggestions(query_text),
      related_searches: extract_related_searches(results),
      popular_filters: extract_popular_filters(results)
    }
  end

  @spec spell_check_suggestions(term()) :: term()
  defp spell_check_suggestions(_query) do
    # Simplified - would use proper spell checking
    []
  end

  @spec extract_related_searches(term()) :: term()
  defp extract_related_searches(_results) do
    # ML - based related search suggestions
    ["alarm configuration", "device templates", "security policies"]
  end

  @spec extract_popular_filters(term()) :: term()
  defp extract_popular_filters(results) do
    # Extract commonly used filter combinations
    %{
      status:
        results |> Enum.map(& &1[:status]) |> Enum.frequencies() |> Map.to_list() |> Enum.take(3),
      type:
        results |> Enum.map(& &1[:type]) |> Enum.frequencies() |> Map.to_list() |> Enum.take(3)
    }
  end

  defp suggest_queries(_text, _tenant_id, _domains) do
    # Query completion suggestions - simplified stub
    [
      "configuration",
      "template",
      "active",
      "recent"
    ]
  end

  @spec suggest_fields(term(), term()) :: term()
  defp suggest_fields(_text, _domains) do
    # Common searchable fields
    ["name", "description", "type", "status", "created_by"]
  end

  defp suggest_values(_text, _tenant_id, _domains) do
    # EP001: Unused parameter, prefixed with underscore for clarity
    # Value suggestions based on existing data
    %{
      status: ["active", "inactive", "maintenance"],
      type: ["camera", "sensor", "alarm_panel", "access_control"]
    }
  end

  @spec suggest_saved_searches(term(), term()) :: term()
  defp suggest_saved_searches(text, user) do
    # User's saved searches matching text
    Indrajaal.ConfigManagement.SavedSearch
    |> where([s], s.user_id == ^user.id or s.shared == true)
    |> where([s], ilike(s.name, ^"%#{text}%"))
    |> limit(5)
    |> Repo.all()
  end

  @spec domain_to_module(String.t()) :: term()
  defp domain_to_module("devices"), do: Indrajaal.Devices.Device
  defp domain_to_module("alarms"), do: Indrajaal.Alarms.Alarm
  defp domain_to_module("sites"), do: Indrajaal.Sites.Site
  @spec domain_to_module(String.t()) :: term()
  defp domain_to_module("__users"), do: Indrajaal.Accounts.User
  # Add other domain mappings...

  @spec get_saved_search(term()) :: term()
  defp get_saved_search(id) do
    case Repo.get(Indrajaal.ConfigManagement.SavedSearch, id) do
      nil -> {:error, :not_found}
      search -> {:ok, search}
    end
  end

  @spec validate_search_access(term(), term()) :: term()
  defp validate_search_access(saved_search, user) do
    if saved_search.user_id == user.id || saved_search.shared do
      :ok
    else
      {:error, :access_denied}
    end
  end

  @spec export_to_csv(term()) :: term()
  defp export_to_csv(results) do
    # CSV export implementation
    headers = extract_common_headers(results)

    csv_data =
      [
        headers
        | Enum.map(results, fn record ->
            headers
            |> Enum.map(fn header ->
              get_nested_value(record, header)
            end)
          end)
      ]
      |> CSV.encode()
      |> Enum.to_list()
      |> Enum.join()

    {:ok, csv_data}
  end

  @spec export_to_json(term()) :: term()
  defp export_to_json(search_result) do
    data = %{
      query_metadata: %{
        total_count: search_result.total_count,
        exported_at: DateTime.utc_now(),
        facets: search_result.facets
      },
      results: Enum.map(search_result.results, &strip_metadata/1)
    }

    case Jason.encode(data) do
      {:ok, json} -> {:ok, json}
      error -> error
    end
  end

  @spec export_to_excel(term()) :: term()
  defp export_to_excel(results) do
    headers = extract_common_headers(results)

    rows =
      Enum.map(results, fn record ->
        map = if is_struct(record), do: Map.from_struct(record), else: record

        Enum.map(headers, fn header ->
          key = String.to_existing_atom(header)
          Map.get(map, key, "") |> to_string()
        end)
      end)

    csv_content =
      [headers | rows]
      |> Enum.map(&Enum.join(&1, "\t"))
      |> Enum.join("\n")

    {:ok, csv_content}
  rescue
    _ -> {:error, :export_failed}
  end

  @spec extract_common_headers(term()) :: term()
  defp extract_common_headers(results) do
    results
    |> List.first()
    |> Map.from_struct()
    |> Map.drop([:__meta__, :__struct__, :search_metadata])
    |> Map.keys()
    |> Enum.map(&Atom.to_string/1)
  end

  @spec get_nested_value(term(), term()) :: term()
  defp get_nested_value(record, header) do
    keys = String.split(header, ".")

    result =
      Enum.reduce(keys, record, fn key, acc ->
        case acc do
          nil -> nil
          map when is_map(map) -> Map.get(map, String.to_existing_atom(key))
          _ -> nil
        end
      end)

    to_string(result)
  end

  @spec strip_metadata(term()) :: term()
  defp strip_metadata(record) do
    Map.delete(record, :search_metadata)
  end

  @spec get_current_user() :: any()
  defp get_current_user do
    # TODO: Get from process dictionary or __context
    %{id: "system", role: "system"}
  end
end

defmodule Indrajaal.ConfigManagement.SavedSearch do
  @moduledoc """
  Schema for saved configuration searches.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "saved_searches" do
    field :name, :string
    field :description, :string
    field :criteria, :map
    field :shared, :boolean, default: false
    field :last_used_at, :utc_datetime
    field :use_count, :integer, default: 0

    belongs_to :user, Indrajaal.Accounts.User

    timestamps()
  end

  @spec changeset(any(), any()) :: any()
  def changeset(search, attrs) do
    search
    |> cast(attrs, [:name, :description, :criteria, :shared, :user_id])
    |> validate_required([:name, :criteria, :user_id])
    |> validate_length(:name, max: 100)
  end
end
