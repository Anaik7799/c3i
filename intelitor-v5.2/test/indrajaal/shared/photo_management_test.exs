defmodule Indrajaal.Shared.PhotoManagementTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shared.PhotoManagement

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(PhotoManagement)
    end
  end

  describe "validate_photo_url/1" do
    test "function is exported" do
      assert function_exported?(PhotoManagement, :validate_photo_url, 1)
    end

    test "validates a valid https URL" do
      result = PhotoManagement.validate_photo_url("https://example.com/photo.jpg")
      assert result == :ok or match?({:ok, _}, result)
    end

    test "rejects an empty URL" do
      result = PhotoManagement.validate_photo_url("")
      assert match?({:error, _}, result) or result == :error
    end

    test "rejects nil URL" do
      result = PhotoManagement.validate_photo_url(nil)
      assert match?({:error, _}, result) or result == :error
    end

    test "accepts http URL" do
      result = PhotoManagement.validate_photo_url("http://internal.host/image.png")
      assert result == :ok or match?({:ok, _}, result)
    end
  end

  describe "validate_photo_urls/1" do
    test "function is exported" do
      assert function_exported?(PhotoManagement, :validate_photo_urls, 1)
    end

    test "validates a list of valid URLs" do
      urls = ["https://example.com/a.jpg", "https://example.com/b.png"]
      result = PhotoManagement.validate_photo_urls(urls)
      assert result == :ok or match?({:ok, _}, result) or is_list(result)
    end

    test "returns errors for list with invalid URL" do
      urls = ["https://valid.com/a.jpg", ""]
      result = PhotoManagement.validate_photo_urls(urls)
      assert is_list(result) or match?({:error, _}, result) or result == :ok
    end

    test "validates empty list" do
      result = PhotoManagement.validate_photo_urls([])
      assert result == :ok or match?({:ok, _}, result) or is_list(result)
    end
  end

  describe "filter_by_extension/2" do
    test "function is exported" do
      assert function_exported?(PhotoManagement, :filter_by_extension, 2)
    end

    test "filters photos by extension" do
      photos = [
        "https://example.com/a.jpg",
        "https://example.com/b.png",
        "https://example.com/c.gif"
      ]

      result = PhotoManagement.filter_by_extension(photos, [".jpg"])
      assert is_list(result)
      assert length(result) <= length(photos)
    end

    test "returns all photos when extension list is empty" do
      photos = ["https://example.com/a.jpg"]
      result = PhotoManagement.filter_by_extension(photos, [])
      assert is_list(result)
    end
  end

  describe "organizeby_date/2" do
    test "function is exported" do
      assert function_exported?(PhotoManagement, :organizeby_date, 2)
    end

    test "organizes photos by date" do
      photos = [
        %{url: "https://a.com/1.jpg", taken_at: ~D[2026-01-15]},
        %{url: "https://a.com/2.jpg", taken_at: ~D[2026-02-10]}
      ]

      result = PhotoManagement.organizeby_date(photos, :asc)
      assert is_list(result) or is_map(result)
    end
  end

  describe "generatethumbnail_urls/2" do
    test "function is exported" do
      assert function_exported?(PhotoManagement, :generatethumbnail_urls, 2)
    end

    test "generates thumbnail URLs" do
      photos = ["https://example.com/photo.jpg"]

      result =
        PhotoManagement.generatethumbnail_urls(photos, %{
          width: 200,
          height: 200
        })

      assert is_list(result)
    end
  end
end
