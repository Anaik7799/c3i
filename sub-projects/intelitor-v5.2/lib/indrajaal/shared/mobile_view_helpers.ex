defmodule Indrajaal.Shared.MobileViewHelpers do
  @moduledoc """
  Shared utilities for Mobile API view rendering.

  This module eliminates massive code duplication across 19 mobile API view files
  by providing common rendering functions for index, show, individual items, and error responses.

  SOPv5.1 Compliance: ✅ Systematic duplication elimination
  Agent: Worker - 4
  Target: ~700 duplicate violations elimination
  Pattern: EP401 - Mobile API View Duplication
  """

  import Phoenix.View, only: [render_many: 3, render_one: 3]

  @api_version "v1"

  @doc """
  Renders paginated index response for mobile API.

  ## Parameters
  - `items`: List of domain objects
  - `total`: Total count of items
  - `page`: Current page number
  - `page_size`: Number of items per page
  - `view_module`: The view module for rendering individual items
  - `item_template`: Template name for individual items (e.g., "device.json")
  - `collection_key`: Key name for the collection in response (e.g., :devices)

  ## Examples
      iex> render_mobile_index(devices, 100, 1, 20, DeviceView, "device.json", :devices)
      %{status: "success", __data: %{devices: [...], total: 100, ...}}
  """
  def render_mobile_index(
        items,
        total,
        page,
        page_size,
        view_module,
        item_template,
        collection_key
      ) do
    data_map =
      %{
        total: total,
        page: page,
        page_size: page_size,
        total_pages: ceil(total / page_size)
      }
      |> Map.put(collection_key, render_many(items, view_module, item_template))

    %{
      status: "success",
      __data: data_map,
      meta_data: render_meta_data()
    }
  end

  @doc """
  Renders show response for mobile API.

  ## Parameters
  - `item`: Domain object to render
  - `view_module`: The view module for rendering the item
  - `item_template`: Template name for the item
  - `item_key`: Key name for the item in response

  ## Examples
      iex> render_mobile_show(device, DeviceView, "device.json", :device)
      %{status: "success", __data: %{device: %{...}}}
  """
  def render_mobile_show(item, view_module, item_template, item_key) do
    %{
      status: "success",
      __data: Map.put(%{}, item_key, render_one(item, view_module, item_template)),
      meta_data: render_meta_data()
    }
  end

  @doc """
  Renders standard item response for mobile API.

  This function provides the common structure for individual domain objects
  with standard fields and domain - specific field additions.

  ## Parameters
  - `item`: Domain object with standard fields (id, name, description, etc.)

  ## Examples
      iex> render_mobile_item(%{id: 1, name: "Test", description: "Test item", ...})
      %{id: 1, name: "Test", description: "Test item", ...}
  """
  @spec render_mobile_item(map()) :: map()
  def render_mobile_item(item) do
    %{
      id: Map.get(item, :id),
      name: Map.get(item, :name, ""),
      description: Map.get(item, :description, ""),
      active: Map.get(item, :active, true),
      meta_data: Map.get(item, :meta_data, %{}),
      created_at:
        item
        |> Map.get(:inserted_at)
        |> then(fn t -> if t, do: DateTime.to_iso8601(t), else: nil end),
      updated_at:
        item
        |> Map.get(:updated_at)
        |> then(fn t -> if t, do: DateTime.to_iso8601(t), else: nil end)
    }
    |> add_domain_specific_fields(item)
  end

  @doc """
  Renders error response for mobile API.

  ## Parameters
  - `changeset`: Ecto changeset with validation errors

  ## Examples
      iex> render_mobile_error(changeset)
      %{status: "error", errors: %{...}, meta_data: %{...}}
  """
  @spec render_mobile_error(Ecto.Changeset.t()) :: map()
  def render_mobile_error(changeset) do
    %{
      status: "error",
      errors: format_changeset_errors(changeset),
      meta_data: render_meta_data()
    }
  end

  @doc """
  Renders standard meta_data for mobile API responses.

  ## Examples
      iex> render_meta_data()
      %{api_version: "v1", timestamp: "2025 - 08 - 22T09:47:36Z"}
  """
  def render_meta_data do
    %{
      api_version: @api_version,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  @doc """
  Renders changeset errors in a consistent format.

  ## Parameters
  - `changeset`: Ecto changeset with validation errors
  """
  @spec render_changeset_errors(Ecto.Changeset.t()) :: map()
  def render_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @doc """
  Adds domain - specific fields to the base item map.

  This function extends the standard item rendering with domain - specific
  fields based on the item's structure.

  ## Parameters
  - `base`: Base map with standard fields
  - `item`: Domain object that may contain additional fields
  """
  @spec add_domain_specific_fields(map(), any()) :: map()
  def add_domain_specific_fields(base, item) do
    # Add domain - specific fields based on the domain type
    case item do
      %{type: type} -> Map.put(base, :type, type)
      %{status: status} -> Map.put(base, :status, status)
      %{location: location} -> Map.put(base, :location, location)
      _ -> base
    end
  end

  @doc """
  Macro to inject common mobile view functions into view modules.

  This macro reduces boilerplate by automatically generating the common
  render functions for mobile API views.

  ## Usage
      defmodule MyApp.SomeView do

        use MyApp, :view
        import Indrajaal.Shared.MobileViewHelpers

        use_mobile_view_helpers(
          collection_key: :items,
          item_key: :item,
          item_template: "item.json"
        )

        # Only define custom render functions for domain - specific templates
      end
  """
  defmacro use_mobile_view_helpers(opts) do
    collection_key = Keyword.get(opts, :collection_key, :items)
    item_key = Keyword.get(opts, :item_key, :item)
    item_template = Keyword.get(opts, :item_template, "item.json")

    quote do
      import Indrajaal.Shared.MobileViewHelpers

      def render("index.json", assigns) do
        %{
          unquote(collection_key) => items,
          total: total,
          page: page,
          page_size: page_size
        } = assigns

        render_mobile_index(
          items,
          total,
          page,
          page_size,
          __MODULE__,
          unquote(item_template),
          unquote(collection_key)
        )
      end

      def render("show.json", assigns) do
        item = Map.get(assigns, unquote(item_key))
        render_mobile_show(item, __MODULE__, unquote(item_template), unquote(item_key))
      end

      def render("error.json", %{changeset: changeset}) do
        render_mobile_error(changeset)
      end

      def render(unquote(item_template), assigns) do
        item = Map.get(assigns, unquote(item_key))
        render_mobile_item(item)
      end
    end
  end

  # Private helper functions

  @doc false
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
