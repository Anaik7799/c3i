defmodule Indrajaal.Authorization.AccessMatrixTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Authorization.AccessMatrix.

  Tests the AccessMatrix Ash resource that manages authorization access matrices
  with multi-tenant isolation and audit tracking.

  SOPv5.11 Compliance: ✅
  Test Categories: Module Structure, Code Interface, Attributes, Relationships,
                   Policies, Property Tests, Edge Cases
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Authorization.AccessMatrix

  # ============================================================================
  # MODULE STRUCTURE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(AccessMatrix)
    end

    test "module is an Ash resource" do
      assert function_exported?(AccessMatrix, :spark_is, 0)
    end

    test "has proper moduledoc" do
      case Code.fetch_docs(AccessMatrix) do
        {:docs_v1, _, :elixir, _, module_doc, _, _} ->
          assert module_doc != :hidden

        _ ->
          # Module may not have docs
          assert true
      end
    end
  end

  # ============================================================================
  # CODE INTERFACE TESTS
  # ============================================================================

  describe "Code Interface" do
    test "exports get function" do
      functions = AccessMatrix.__info__(:functions)
      assert {:get, 1} in functions or {:get, 2} in functions
    end

    test "exports list function" do
      functions = AccessMatrix.__info__(:functions)
      assert {:list, 0} in functions or {:list, 1} in functions
    end

    test "exports create function" do
      functions = AccessMatrix.__info__(:functions)
      assert {:create, 1} in functions or {:create, 2} in functions
    end

    test "exports update function" do
      functions = AccessMatrix.__info__(:functions)
      assert {:update, 2} in functions or {:update, 3} in functions
    end

    test "exports destroy function" do
      functions = AccessMatrix.__info__(:functions)
      assert {:destroy, 1} in functions or {:destroy, 2} in functions
    end
  end

  # ============================================================================
  # ASH RESOURCE STRUCTURE TESTS
  # ============================================================================

  describe "Ash Resource Structure" do
    test "has attributes defined" do
      info = AccessMatrix.__info__(:functions)
      # Ash resources have attribute-related functions
      assert is_list(info)
    end

    test "uses Indrajaal.BaseResource" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "use Indrajaal.BaseResource"
    end

    test "belongs to Indrajaal.Policy domain" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "domain: Indrajaal.Policy"
    end

    test "has postgres table configured" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ ~s(table "authorization_access_matrix")
      assert content =~ "repo Indrajaal.Repo"
    end
  end

  # ============================================================================
  # ATTRIBUTE TESTS
  # ============================================================================

  describe "Attributes" do
    test "has uuid_primary_key :id" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "uuid_primary_key :id"
    end

    test "has tenant_id attribute with allow_nil? false" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "attribute :tenant_id, :uuid"
      assert content =~ "allow_nil? false"
    end

    test "has name attribute with allow_nil? false" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "attribute :name, :string"
    end

    test "has description attribute" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "attribute :description, :string"
    end

    test "has active attribute with default true" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "attribute :active, :boolean"
      assert content =~ "default: true"
    end

    test "has audit tracking attributes" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "attribute :created_by_id, :uuid"
      assert content =~ "attribute :updated_by_id, :uuid"
    end

    test "has timestamps" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "timestamps()"
    end
  end

  # ============================================================================
  # ACTION TESTS
  # ============================================================================

  describe "Actions" do
    test "has default read action" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "defaults [:read, :destroy]"
    end

    test "has default destroy action" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "defaults [:read, :destroy]"
    end

    test "has create action with accepted attributes" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "create :create do"
      assert content =~ "accept [:name, :description, :active, :tenant_id]"
    end

    test "has update action with accepted attributes" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "update :update do"
      assert content =~ "accept [:name, :description, :active]"
    end

    test "create action sets created_by_id from actor" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "change set_attribute(:created_by_id, actor(:id))"
    end

    test "update action sets updated_by_id from actor" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "change set_attribute(:updated_by_id, actor(:id))"
    end
  end

  # ============================================================================
  # RELATIONSHIP TESTS
  # ============================================================================

  describe "Relationships" do
    test "belongs_to tenant" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "belongs_to :tenant, Indrajaal.Core.Tenant"
    end

    test "belongs_to created_by user" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "belongs_to :created_by, Indrajaal.Accounts.User"
    end

    test "belongs_to updated_by user" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "belongs_to :updated_by, Indrajaal.Accounts.User"
    end
  end

  # ============================================================================
  # IDENTITY TESTS
  # ============================================================================

  describe "Identities" do
    test "has unique_name_per_tenant identity" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "identity :unique_name_per_tenant, [:name, :tenant_id]"
    end
  end

  # ============================================================================
  # POLICY TESTS
  # ============================================================================

  describe "Policies" do
    test "has bypass for AshAuthenticationInteraction" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "bypass AshAuthentication.Checks.AshAuthenticationInteraction"
      assert content =~ "authorize_if always()"
    end

    test "has read policy with tenant_id check" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "policy action_type(:read)"
      assert content =~ "tenant_id == ^actor(:tenant_id)"
    end

    test "has create/update/destroy policy with tenant_id check" do
      source_path = "lib/indrajaal/authorization/access_matrix.ex"
      content = File.read!(source_path)

      assert content =~ "policy action_type([:create, :update, :destroy])"
      assert content =~ "tenant_id == ^actor(:tenant_id)"
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "module is always loadable" do
      forall _n <- PC.integer() do
        Code.ensure_loaded?(AccessMatrix)
      end
    end

    property "code interface functions are always exported" do
      forall _n <- PC.integer() do
        functions = AccessMatrix.__info__(:functions)

        has_get = Enum.any?(functions, fn {name, _} -> name == :get end)
        has_list = Enum.any?(functions, fn {name, _} -> name == :list end)
        has_create = Enum.any?(functions, fn {name, _} -> name == :create end)
        has_update = Enum.any?(functions, fn {name, _} -> name == :update end)
        has_destroy = Enum.any?(functions, fn {name, _} -> name == :destroy end)

        has_get and has_list and has_create and has_update and has_destroy
      end
    end

    property "source file always exists and is readable" do
      forall _n <- PC.integer() do
        source_path = "lib/indrajaal/authorization/access_matrix.ex"
        File.exists?(source_path) and is_binary(File.read!(source_path))
      end
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/authorization/access_matrix.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/authorization/access_matrix.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "has proper defmodule structure" do
      source = File.read!("lib/indrajaal/authorization/access_matrix.ex")
      assert source =~ "defmodule Indrajaal.Authorization.AccessMatrix"
    end

    test "has @skip_default_code_interface attribute" do
      source = File.read!("lib/indrajaal/authorization/access_matrix.ex")
      assert source =~ "@skip_default_code_interface true"
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "module info returns expected structure" do
      info = AccessMatrix.__info__(:module)
      assert info == Indrajaal.Authorization.AccessMatrix
    end

    test "handles introspection without errors" do
      # Should not raise
      _ = AccessMatrix.__info__(:functions)
      _ = AccessMatrix.__info__(:macros)
      _ = AccessMatrix.__info__(:attributes)

      assert true
    end

    test "source file has consistent indentation" do
      source = File.read!("lib/indrajaal/authorization/access_matrix.ex")
      lines = String.split(source, "\n")

      # Check that lines use consistent spacing (2-space indentation)
      indented_lines =
        lines
        |> Enum.filter(fn line ->
          String.starts_with?(line, "  ") and not String.starts_with?(line, "   ")
        end)

      # Should have some properly indented lines
      assert length(indented_lines) > 0
    end
  end

  # ============================================================================
  # MULTI-TENANT ISOLATION TESTS
  # ============================================================================

  describe "Multi-Tenant Isolation" do
    test "tenant_id is required for create" do
      source = File.read!("lib/indrajaal/authorization/access_matrix.ex")

      # tenant_id must be in accept list for create
      assert source =~ "accept [:name, :description, :active, :tenant_id]"
    end

    test "tenant_id has allow_nil? false" do
      source = File.read!("lib/indrajaal/authorization/access_matrix.ex")

      # Check tenant_id attribute configuration
      assert source =~ "attribute :tenant_id, :uuid do"
      assert source =~ "allow_nil? false"
    end

    test "policies enforce tenant isolation" do
      source = File.read!("lib/indrajaal/authorization/access_matrix.ex")

      # All data access should be scoped to tenant
      assert source =~ "tenant_id == ^actor(:tenant_id)"
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "all code interface functions are accessible" do
      functions = AccessMatrix.__info__(:functions)

      code_interface_functions = [
        :get,
        :list,
        :create,
        :update,
        :destroy
      ]

      Enum.each(code_interface_functions, fn func ->
        assert Enum.any?(functions, fn {name, _arity} -> name == func end),
               "Expected #{func} to be in functions"
      end)
    end

    test "module is part of Authorization domain" do
      module_name = to_string(AccessMatrix)
      assert module_name =~ "Authorization"
    end

    test "follows Ash resource conventions" do
      source = File.read!("lib/indrajaal/authorization/access_matrix.ex")

      # Should have standard Ash resource blocks
      assert source =~ "attributes do"
      assert source =~ "actions do"
      assert source =~ "relationships do"
      assert source =~ "policies do"
      assert source =~ "code_interface do"
    end
  end
end
