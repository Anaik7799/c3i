defmodule Indrajaal.Shared.PhotoManagement do
  @moduledoc """
  Shared utilities for managing photo URLs across multiple domains.

  This module extracts common photo URL functionality used by:
  - Maintenance.Task (mass: 44 - 57)
  - Maintenance.WorkOrder (mass: 44 - 57)
  - Maintenance.ServiceRecord (mass: 44)
  - Other domains with photo management

  Following Toyota TPS principles to eliminate duplicate code waste.
  """

  @doc """
  Creates an add photo change function for Ash changesets.

  ## Parameters
    - `photo_field` - The field containing photo URLs list (default: :photo_urls)
    - `url_argument` - The argument name for new photo URL (default: :photo_url)
    - `max_urls` - Maximum number of URLs allowed (default: 50)

  ## Returns
  Function that can be used in Ash `change` declarations.

  ## Example
      change Indrajaal.Shared.PhotoManagement.create_add_photo_change()

      # Or with custom settings
      change Indrajaal.Shared.PhotoManagement.create_add_photo_change(:image_urls,
        :image_url, 20)
  """
  def createadd_photo_change(
        photo_field \\ :photourls,
        url_argument \\ :photourl,
        max_urls \\ 50
      ) do
    fn changeset, _context ->
      photos = Ash.Changeset.get_attribute(changeset, photo_field) || []
      new_url = Ash.Changeset.get_argument(changeset, url_argument)

      cond do
        new_url in photos ->
          # URL already exists, no change needed
          changeset

        length(photos) >= max_urls ->
          # Too many photos, add validation error
          Ash.Changeset.add_error(changeset,
            field: photo_field,
            message: "Maximum #{max_urls} photos allowed"
          )

        true ->
          # Add new URL to the list
          Ash.Changeset.force_change_attribute(changeset, photo_field, [new_url | photos])
      end
    end
  end

  @doc """
  Creates a remove photo change function for Ash changesets.

  ## Parameters
    - `photo_field` - The field containing photo URLs list (default: :photo_urls)
    - `url_argument` - The argument name for photo URL to remove (default:
      :photo_url)

  ## Returns
  Function that can be used in Ash `change` declarations.
  """
  def createremove_photo_change(
        photo_field \\ :photourls,
        url_argument \\ :photourl
      ) do
    fn changeset, _context ->
      photos = Ash.Changeset.get_attribute(changeset, photo_field) || []
      url_to_remove = Ash.Changeset.get_argument(changeset, url_argument)

      case url_to_remove in photos do
        true ->
          updated_photos = Enum.reject(photos, &(&1 == url_to_remove))
          Ash.Changeset.force_change_attribute(changeset, photo_field, updated_photos)

        false ->
          changeset
      end
    end
  end

  @doc """
  Creates a standard add photo action definition.

  ## Parameters
    - `action_name` - Name of the action (default: :add_photo)
    - `photo_field` - The field containing photo URLs (default: :photo_urls)
    - `url_argument` - The argument name for new photo URL (default: :photo_url)
    - `max_urls` - Maximum number of URLs allowed (default: 50)

  ## Returns
  Map with action configuration that can be used in Ash actions.

  ## Example
      update Indrajaal.Shared.PhotoManagement.add_photo_action()
  """
  def addphoto_action(
        action_name \\ :addphoto,
        photo_field \\ :photourls,
        url_argument \\ :photourl,
        max_urls \\ 50
      ) do
    %{
      name: action_name,
      accept: [photo_field],
      arguments: [
        {url_argument,
         %{
           type: :string,
           allow_nil?: false,
           constraints: [max_length: 500]
         }}
      ],
      changes: [
        {:change, createadd_photo_change(photo_field, url_argument, max_urls)}
      ]
    }
  end

  @doc """
  Creates a standard remove photo action definition.

  ## Parameters
    - `action_name` - Name of the action (default: :remove_photo)
    - `photo_field` - The field containing photo URLs (default: :photo_urls)
    - `url_argument` - The argument name for photo URL to remove (default:
      :photo_url)

  ## Returns
  Map with action configuration that can be used in Ash actions.
  """
  def removephoto_action(
        action_name \\ :removephoto,
        photo_field \\ :photourls,
        url_argument \\ :photourl
      ) do
    %{
      name: action_name,
      accept: [photo_field],
      arguments: [
        {url_argument,
         %{
           type: :string,
           allow_nil?: false,
           constraints: [max_length: 500]
         }}
      ],
      changes: [
        {:change, createremove_photo_change(photo_field, url_argument)}
      ]
    }
  end

  @doc """
  Validates photo URL format.

  ## Parameters
    - `url` - URL string to validate

  ## Returns
    - `{:ok, url}` if valid
    - `{:error, reason}` if invalid
  """
  @spec validate_photo_url(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_photo_url(url) when is_binary(url) do
    uri = URI.parse(url)

    cond do
      is_nil(uri.scheme) ->
        {:error, "URL must include protocol (http / https)"}

      uri.scheme not in ["http", "https"] ->
        {:error, "URL must use http or https protocol"}

      is_nil(uri.host) ->
        {:error, "URL must include valid host"}

      String.length(url) > 500 ->
        {:error, "URL too long (max 500 characters)"}

      not image_extension?(uri.path) ->
        {:error, "URL must point to an image file"}

      true ->
        {:ok, url}
    end
  end

  @spec validate_photo_url(any()) :: any()
  # def validate_photo_url(_), do: {:error, "URL must be a string"}
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Bulk validates a list of photo URLs.

  ## Parameters
    - `urls` - List of URL strings to validate

  ## Returns
    - `{:ok, valid_urls}` if all valid
    - `{:error, {invalid_url, reason}}` for first invalid URL
  """
  @spec validate_photo_urls(list(String.t())) ::
          {:ok, list(String.t())} | {:error, {String.t(), String.t()}}
  @spec validate_photo_urls(any()) :: any()
  def validate_photo_urls(urls) when is_list(urls) do
    case Enum.find(urls, fn url ->
           case validate_photo_url(url) do
             {:ok, _} -> false
             {:error, _} -> true
           end
         end) do
      nil ->
        {:ok, urls}

      invalid_url ->
        {:error, invalid_url, elem(validate_photo_url(invalid_url), 1)}
    end
  end

  @spec validate_photo_urls(any()) :: any()
  # def validate_photo_urls(_), do: {:error, "URLs must be provided as a list"}
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Filters photo URLs by file extension.

  ## Parameters
    - `urls` - List of URLs to filter
    - `extensions` - List of allowed extensions (default: common image formats)

  ## Returns
  List of URLs with allowed extensions.
  """
  @spec filter_by_extension(
          list(String.t()),
          list(String.t())
        ) :: list(String.t())
  def filter_by_extension(
        urls,
        extensions \\ [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"]
      ) do
    Enum.filter(urls, fn url ->
      path = URI.parse(url).path || ""
      raw_ext = Path.extname(path)
      ext = String.downcase(raw_ext)
      ext in extensions
    end)
  end

  @doc """
  Organizes photos by date taken (extracted from URL or meta_data).

  ## Parameters
    - `photos` - List of photo URLs or photo maps with meta_data
    - `date_field` - Field name for date (default: :taken_at)

  ## Returns
  Map with dates as keys and lists of photos as values.
  """
  def organizeby_date(photos, date_field \\ :takenat) do
    Enum.group_by(photos, fn photo ->
      case photo do
        %{^date_field => date} when not is_nil(date) ->
          Date.from_iso8601!(date)

        url when is_binary(url) ->
          # Try to extract date from URL pattern
          extract_date_from_url(url) || Date.utc_today()

        _ ->
          Date.utc_today()
      end
    end)
  end

  @doc """
  Generates thumbnail URLs from photo URLs using a standard pattern.

  ## Parameters
    - `urls` - List of photo URLs
    - `thumbnail_suffix` - Suffix to add for thumbnails (default: "_thumb")

  ## Returns
  List of thumbnail URLs.
  """
  def generatethumbnail_urls(urls, thumbnail_suffix \\ "thumb") do
    Enum.map(urls, fn url ->
      %{path: path} = uri = URI.parse(url)

      case Path.extname(path) do
        "" ->
          url <> thumbnail_suffix

        ext ->
          base = Path.rootname(path)
          new_path = base <> thumbnail_suffix <> ext
          %{uri | path: new_path} |> URI.to_string()
      end
    end)
  end

  # Private helper functions

  @spec image_extension?(term()) :: term()
  defp image_extension?(nil), do: false

  defp image_extension?(path) do
    raw_ext = Path.extname(path)
    ext = String.downcase(raw_ext)
    ext in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff", ".svg"]
  end

  @spec extract_date_from_url(term()) :: term()
  defp extract_date_from_url(url) do
    # Try to extract YYYY - MM - DD pattern from URL
    case Regex.run(~r/(\d{4})-(\d{2})-(\d{2})/, url) do
      [_, year, month, day] ->
        case Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day)) do
          {:ok, date} -> date
          _ -> nil
        end

      _ ->
        nil
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
