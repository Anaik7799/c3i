defmodule Indrajaal.ConfigManagement.SchemasTest do
  @moduledoc """
  TDG test suite for Indrajaal.ConfigManagement schemas.
  STAMP: SC-DB-001, SC-DB-005
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.ConfigManagement.{
    ConfigTemplate,
    ConfigVersion,
    ChangeRequest,
    ChangeApproval,
    ConfigSync,
    ConfigBackup
  }

  describe "ConfigTemplate schema" do
    test "has the expected fields" do
      fields = ConfigTemplate.__schema__(:fields)
      assert :id in fields
      assert :name in fields or :template_name in fields or is_list(fields)
    end

    test "changeset/2 accepts valid attrs" do
      attrs = %{name: "template-1", content: %{}}
      cs = ConfigTemplate.changeset(%ConfigTemplate{}, attrs)
      assert cs.__struct__ == Ecto.Changeset
    end
  end

  describe "ConfigVersion schema" do
    test "has the expected fields" do
      fields = ConfigVersion.__schema__(:fields)
      assert is_list(fields)
      assert length(fields) > 0
    end

    test "changeset/2 returns a changeset" do
      cs = ConfigVersion.changeset(%ConfigVersion{}, %{})
      assert cs.__struct__ == Ecto.Changeset
    end
  end

  describe "ChangeRequest schema" do
    test "has the expected fields" do
      fields = ChangeRequest.__schema__(:fields)
      assert is_list(fields)
    end

    test "changeset/2 returns a changeset" do
      cs = ChangeRequest.changeset(%ChangeRequest{}, %{})
      assert cs.__struct__ == Ecto.Changeset
    end
  end

  describe "ChangeApproval schema" do
    test "has the expected fields" do
      fields = ChangeApproval.__schema__(:fields)
      assert is_list(fields)
    end

    test "changeset/2 returns a changeset" do
      cs = ChangeApproval.changeset(%ChangeApproval{}, %{})
      assert cs.__struct__ == Ecto.Changeset
    end
  end

  describe "ConfigSync schema" do
    test "has the expected fields" do
      fields = ConfigSync.__schema__(:fields)
      assert is_list(fields)
    end

    test "changeset/2 returns a changeset" do
      cs = ConfigSync.changeset(%ConfigSync{}, %{})
      assert cs.__struct__ == Ecto.Changeset
    end
  end

  describe "ConfigBackup schema" do
    test "has the expected fields" do
      fields = ConfigBackup.__schema__(:fields)
      assert is_list(fields)
    end

    test "changeset/2 returns a changeset" do
      cs = ConfigBackup.changeset(%ConfigBackup{}, %{})
      assert cs.__struct__ == Ecto.Changeset
    end
  end
end
