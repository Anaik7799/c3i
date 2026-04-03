defmodule Indrajaal.VisitorManagement.VisitApproval do
  @moduledoc """
  Multi - level approval workflows for visit _requests with delegation support.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.VisitorManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :approval_level, :integer do
      allow_nil? false
      constraints min: 1, max: 5
    end

    attribute :approval_type, :atom do
      constraints one_of: [:manager, :security, :facility, :compliance, :executive]
      allow_nil? false
    end

    attribute :approval_status, :atom do
      constraints one_of: [:pending, :approved, :rejected, :delegated, :escalated]
      default :pending
    end

    attribute :_requested_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :responded_at, :utc_datetime

    attribute :approval_comments, :string do
      constraints max_length: 1000
    end

    attribute :conditions, {:array, :string} do
      default []
    end

    attribute :restrictions, {:array, :string} do
      default []
    end

    attribute :escalation_reason, :string do
      constraints max_length: 500
    end

    attribute :delegation_reason, :string do
      constraints max_length: 500
    end

    attribute :response_deadline, :utc_datetime

    attribute :auto_approve_conditions, :map do
      default %{}
    end

    attribute :is_final_approval, :boolean do
      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :visit_request, Indrajaal.VisitorManagement.VisitRequest do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :approver, Indrajaal.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :delegated_to, Indrajaal.Accounts.User do
      attribute_writable? true
    end

    belongs_to :escalated_to, Indrajaal.Accounts.User do
      attribute_writable? true
    end
  end

  calculations do
    calculate :is_overdue, :boolean do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(
          records,
          fn record ->
            case {record.approval_status, record.response_deadline} do
              {status, deadline} when status == :pending and not is_nil(deadline) ->
                DateTime.compare(now, deadline) == :gt

              _ ->
                false
            end
          end
        )
      end
    end

    calculate :response_time_hours, :decimal do
      calculation fn records, _ ->
        Enum.map(
          records,
          fn record ->
            case record.responded_at do
              nil ->
                nil

              responded_at ->
                diff_seconds =
                  DateTime.diff(
                    responded_at,
                    record._requested_at,
                    :second
                  )

                Decimal.div(diff_seconds, 3600)
            end
          end
        )
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :_request_approval do
      argument :visit_request_id, :uuid do
        allow_nil? false
      end

      argument :approver_id, :uuid do
        allow_nil? false
      end

      argument :approval_type, :atom do
        allow_nil? false
      end

      argument :approval_level, :integer do
        allow_nil? false
      end

      argument :response_deadline, :utc_datetime

      change set_attribute(:visit_request_id, arg(:visit_request_id))
      change set_attribute(:approver_id, arg(:approver_id))
      change set_attribute(:approval_type, arg(:approval_type))
      change set_attribute(:approval_level, arg(:approval_level))
      change set_attribute(:response_deadline, arg(:response_deadline))
    end

    update :approve do
      require_atomic? false
      argument :comments, :string
      argument :conditions, {:array, :string}
      argument :restrictions, {:array, :string}
      argument :is_final, :boolean, default: false

      change set_attribute(:approval_status, :approved)
      change set_attribute(:responded_at, &DateTime.utc_now/0)
      change set_attribute(:approval_comments, arg(:comments))
      change set_attribute(:conditions, arg(:conditions))
      change set_attribute(:restrictions, arg(:restrictions))
      change set_attribute(:is_final_approval, arg(:is_final))
    end

    update :reject do
      require_atomic? false

      argument :rejection_reason, :string do
        allow_nil? false
      end

      change set_attribute(:approval_status, :rejected)
      change set_attribute(:responded_at, &DateTime.utc_now/0)
      change set_attribute(:approval_comments, arg(:rejection_reason))
    end

    update :delegate do
      require_atomic? false

      argument :delegated_to_id, :uuid do
        allow_nil? false
      end

      argument :delegation_reason, :string do
        allow_nil? false
      end

      change set_attribute(:approval_status, :delegated)
      change set_attribute(:delegated_to_id, arg(:delegated_to_id))
      change set_attribute(:delegation_reason, arg(:delegation_reason))
      change set_attribute(:responded_at, &DateTime.utc_now/0)
    end

    update :escalate do
      require_atomic? false

      argument :escalated_to_id, :uuid do
        allow_nil? false
      end

      argument :escalation_reason, :string do
        allow_nil? false
      end

      change set_attribute(:approval_status, :escalated)
      change set_attribute(:escalated_to_id, arg(:escalated_to_id))
      change set_attribute(:escalation_reason, arg(:escalation_reason))
      change set_attribute(:responded_at, &DateTime.utc_now/0)
    end

    update :set_auto_approve_conditions do
      require_atomic? false

      argument :conditions, :map do
        allow_nil? false
      end

      change set_attribute(:auto_approve_conditions, arg(:conditions))
    end

    update :extend_deadline do
      require_atomic? false

      argument :new_deadline, :utc_datetime do
        allow_nil? false
      end

      change set_attribute(:response_deadline, arg(:new_deadline))
    end
  end

  code_interface do
    define :create
    define :_request_approval
    define :approve
    define :reject
    define :delegate
    define :escalate
    define :set_auto_approve_conditions
    define :extend_deadline
  end

  postgres do
    table "visit_approvals"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :visit_request_id]
      index [:tenant_id, :approver_id]
      index [:tenant_id, :approval_status]
      index [:tenant_id, :approval_type]
      index [:tenant_id, :approval_level]
      index [:tenant_id, :_requested_at]

      index [:tenant_id, :response_deadline],
        where: "response_deadline IS NOT NULL"

      index [:tenant_id, :delegated_to_id], where: "delegated_to_id IS NOT NULL"
      index [:tenant_id, :escalated_to_id], where: "escalated_to_id IS NOT NULL"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Visitor management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
