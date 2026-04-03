defmodule Indrajaal.Alarms.WorkflowTemplateTest do
  @moduledoc """
  TDG comprehensive test suite for Alarms.WorkflowTemplate.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-WT-001: create must have at least one step (validated inline)
  - SC-WT-002: each step must have "type" and "name" keys with valid type
  - SC-WT-003: category defaults to :standard
  - SC-WT-004: activate requires active? == false; deactivate requires active? == true
  - SC-WT-005: update_workflow increments version by 1
  - SC-WT-006: add_site requires site_specific? == true

  ## Constitutional Verification
  - Psi0 Existence: WorkflowTemplate persists through activate/deactivate lifecycle
  - Psi3 Verification: Version counter increments monotonically on update_workflow
  - Psi5 Truthfulness: active? accurately reflects activate/deactivate state

  ## Founder's Directive Alignment
  - Omega0.1: Workflow templates ensure consistent alarm response procedures

  ## TPS 5-Level RCA Context
  - L1 Symptom: WorkflowTemplate created with empty steps list
  - L5 Root Cause: Step validation not applied on create action

  ## Change History
  | Version | Date       | Author | Change            |
  |---------|------------|--------|-------------------|
  | 21.3.0  | 2026-03-19 | Claude | Initial TDG suite |
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Alarms.WorkflowTemplate

  @moduletag :zenoh_nif

  @system_admin %{role: "admin", id: "00000000-0000-0000-0000-000000000006"}

  # A minimal valid step map — must have "type" and "name" with a known type
  @valid_step %{"type" => "notification", "name" => "Send alert"}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_workflow_template(attrs \\ %{}) do
    tenant_id = random_tenant().id

    base = %{
      name: "Test Workflow #{System.unique_integer([:positive])}",
      steps: [@valid_step],
      tenant_id: tenant_id
    }

    merged = Map.merge(base, attrs)

    Ash.create(WorkflowTemplate, merged,
      authorize?: false,
      actor: @system_admin,
      tenant: tenant_id
    )
  end

  # ---------------------------------------------------------------------------
  # describe: create action
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "creates a workflow_template with required fields" do
      assert {:ok, wt} = create_workflow_template()
      assert not is_nil(wt.id)
    end

    test "name is persisted correctly" do
      {:ok, wt} = create_workflow_template(%{name: "Fire Response"})
      assert wt.name == "Fire Response"
    end

    test "category defaults to :standard" do
      {:ok, wt} = create_workflow_template()
      assert wt.category == :standard
    end

    test "active? defaults to true" do
      {:ok, wt} = create_workflow_template()
      assert wt.active? == true
    end

    test "version defaults to 1" do
      {:ok, wt} = create_workflow_template()
      assert wt.version == 1
    end

    test "priority defaults to 5" do
      {:ok, wt} = create_workflow_template()
      assert wt.priority == 5
    end

    test "steps are persisted correctly" do
      step = %{"type" => "dispatch", "name" => "Dispatch guard"}
      {:ok, wt} = create_workflow_template(%{steps: [step]})
      assert length(wt.steps) == 1
    end

    test "empty steps list fails validation" do
      result = create_workflow_template(%{steps: []})
      assert match?({:error, _}, result)
    end

    test "step missing type key fails validation" do
      invalid_step = %{"name" => "Missing type"}
      result = create_workflow_template(%{steps: [invalid_step]})
      assert match?({:error, _}, result)
    end

    test "step with invalid type fails validation" do
      invalid_step = %{"type" => "invalid_type_xyz", "name" => "Bad step"}
      result = create_workflow_template(%{steps: [invalid_step]})
      assert match?({:error, _}, result)
    end

    test "category :emergency is valid" do
      {:ok, wt} = create_workflow_template(%{category: :emergency})
      assert wt.category == :emergency
    end

    test "category :verification is valid" do
      {:ok, wt} = create_workflow_template(%{category: :verification})
      assert wt.category == :verification
    end

    test "category :escalation is valid" do
      {:ok, wt} = create_workflow_template(%{category: :escalation})
      assert wt.category == :escalation
    end

    test "category :dispatch is valid" do
      {:ok, wt} = create_workflow_template(%{category: :dispatch})
      assert wt.category == :dispatch
    end

    test "category :notification is valid" do
      {:ok, wt} = create_workflow_template(%{category: :notification})
      assert wt.category == :notification
    end

    test "category :custom is valid" do
      {:ok, wt} = create_workflow_template(%{category: :custom})
      assert wt.category == :custom
    end

    test "id is a UUID" do
      {:ok, wt} = create_workflow_template()
      assert is_binary(wt.id)
      assert String.length(wt.id) == 36
    end

    test "business_hours_only? defaults to false" do
      {:ok, wt} = create_workflow_template()
      assert wt.business_hours_only? == false
    end

    test "require_acknowledgment? defaults to true" do
      {:ok, wt} = create_workflow_template()
      assert wt.require_acknowledgment? == true
    end

    test "auto_resolve? defaults to false" do
      {:ok, wt} = create_workflow_template()
      assert wt.auto_resolve? == false
    end
  end

  # ---------------------------------------------------------------------------
  # describe: activate/deactivate actions
  # ---------------------------------------------------------------------------

  describe "activate/1" do
    test "sets active? to true after deactivate" do
      {:ok, wt} = create_workflow_template()

      {:ok, deactivated} =
        Ash.update(wt, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      assert deactivated.active? == false

      {:ok, activated} =
        Ash.update(deactivated, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert activated.active? == true
    end

    test "activate on already-active fails" do
      {:ok, wt} = create_workflow_template()
      assert wt.active? == true
      result = Ash.update(wt, %{}, action: :activate, authorize?: false, actor: @system_admin)
      assert match?({:error, _}, result)
    end
  end

  describe "deactivate/1" do
    test "sets active? to false" do
      {:ok, wt} = create_workflow_template()

      {:ok, deactivated} =
        Ash.update(wt, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      assert deactivated.active? == false
    end

    test "deactivate on already-inactive fails" do
      {:ok, wt} = create_workflow_template()

      {:ok, deactivated} =
        Ash.update(wt, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      result =
        Ash.update(deactivated, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: update_workflow action
  # ---------------------------------------------------------------------------

  describe "update_workflow/1" do
    test "updates steps and increments version" do
      {:ok, wt} = create_workflow_template()
      assert wt.version == 1

      new_steps = [
        %{"type" => "notification", "name" => "Alert 1"},
        %{"type" => "dispatch", "name" => "Dispatch guard"}
      ]

      {:ok, updated} =
        Ash.update(wt, %{steps: new_steps},
          action: :update_workflow,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.version == 2
      assert length(updated.steps) == 2
    end

    test "version increments monotonically on multiple updates" do
      {:ok, wt} = create_workflow_template()

      {:ok, v2} =
        Ash.update(wt, %{steps: [@valid_step, @valid_step]},
          action: :update_workflow,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, v3} =
        Ash.update(v2, %{steps: [@valid_step]},
          action: :update_workflow,
          authorize?: false,
          actor: @system_admin
        )

      assert v2.version == 2
      assert v3.version == 3
    end

    test "update with empty steps fails" do
      {:ok, wt} = create_workflow_template()

      result =
        Ash.update(wt, %{steps: []},
          action: :update_workflow,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: id persists through activate/deactivate cycle" do
      {:ok, wt} = create_workflow_template()
      original_id = wt.id

      {:ok, deactivated} =
        Ash.update(wt, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      {:ok, activated} =
        Ash.update(deactivated, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert activated.id == original_id
    end

    test "Psi3 verification: version is always >= 1 and monotonically increasing" do
      {:ok, wt} = create_workflow_template()
      assert wt.version >= 1

      {:ok, updated} =
        Ash.update(wt, %{steps: [@valid_step]},
          action: :update_workflow,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.version > wt.version
    end

    test "Psi5 truthfulness: active? reflects actual activate/deactivate state" do
      {:ok, wt} = create_workflow_template()
      assert wt.active? == true

      {:ok, deactivated} =
        Ash.update(wt, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      assert deactivated.active? == false

      {:ok, activated} =
        Ash.update(deactivated, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert activated.active? == true
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "dual-channel: two templates can be created concurrently" do
      tasks = [
        Task.async(fn -> create_workflow_template(%{category: :emergency}) end),
        Task.async(fn -> create_workflow_template(%{category: :standard}) end)
      ]

      [r1, r2] = Task.await_many(tasks, 10_000)
      assert match?({:ok, _}, r1)
      assert match?({:ok, _}, r2)
    end

    test "create completes within 5 seconds" do
      {elapsed_us, result} = :timer.tc(fn -> create_workflow_template() end)
      assert match?({:ok, _}, result)
      assert elapsed_us < 5_000_000
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  property "all 7 valid categories are accepted" do
    categories = [
      :standard,
      :emergency,
      :verification,
      :escalation,
      :dispatch,
      :notification,
      :custom
    ]

    forall category <- PC.oneof(Enum.map(categories, &PC.exactly/1)) do
      result = create_workflow_template(%{category: category})
      match?({:ok, _}, result)
    end
  end

  property "version always starts at 1" do
    forall _n <- PC.integer(1, 3) do
      {:ok, wt} = create_workflow_template()
      wt.version == 1
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  test "active? is always true on fresh create" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      {:ok, wt} = create_workflow_template()
      assert wt.active? == true
    end
  end

  test "update_workflow always increments version" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      {:ok, wt} = create_workflow_template()

      {:ok, updated} =
        Ash.update(wt, %{steps: [@valid_step]},
          action: :update_workflow,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.version == wt.version + 1
    end
  end
end
