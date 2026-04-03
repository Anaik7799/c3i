defmodule Indrajaal.Crm.CampaignMember do
  @moduledoc """
  CampaignMember Resource - Links Leads/Contacts to Campaigns.

  ## WHAT
  Junction table linking campaigns to leads or contacts:
  - Member type (lead or contact)
  - Member status (sent, responded, converted, etc.)
  - Response tracking
  - Conversion tracking

  ## WHY
  Campaign membership and response tracking:
  - Who was targeted by the campaign?
  - Who responded?
  - What was the conversion rate?
  - Which leads came from which campaigns?

  ## STAMP Constraints
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key :id
  - SC-DB-012: create_if_not_exists for indexes
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  postgres do
    table "campaign_members"
    repo Indrajaal.Repo

    references do
      reference :campaign, on_delete: :delete
      reference :lead, on_delete: :delete
      reference :contact, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :member_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:lead, :contact]
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:sent, :opened, :responded, :converted, :bounced, :opted_out]
      default :sent
    end

    attribute :responded, :boolean do
      public? true
      default false
    end

    attribute :has_converted, :boolean do
      public? true
      default false
      description "Has this member converted (lead -> opportunity)?"
    end

    attribute :first_responded_date, :datetime, public?: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :campaign, Indrajaal.Crm.Campaign do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :lead, Indrajaal.Crm.Lead do
      attribute_writable? true
    end

    belongs_to :contact, Indrajaal.Crm.Contact do
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :campaign_id,
        :member_type,
        :lead_id,
        :contact_id,
        :status,
        :responded,
        :has_converted
      ]

      primary? true

      validate fn changeset, _context ->
        member_type = Ash.Changeset.get_attribute(changeset, :member_type)
        lead_id = Ash.Changeset.get_attribute(changeset, :lead_id)
        contact_id = Ash.Changeset.get_attribute(changeset, :contact_id)

        case member_type do
          :lead ->
            if is_nil(lead_id) do
              {:error, field: :lead_id, message: "Lead ID required when member_type is :lead"}
            else
              :ok
            end

          :contact ->
            if is_nil(contact_id) do
              {:error,
               field: :contact_id, message: "Contact ID required when member_type is :contact"}
            else
              :ok
            end

          _ ->
            :ok
        end
      end
    end

    update :update do
      accept [:status, :responded, :has_converted]
      primary? true
      require_atomic? false
    end

    update :mark_responded do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:responded, true)
        |> Ash.Changeset.force_change_attribute(:status, :responded)
        |> Ash.Changeset.force_change_attribute(:first_responded_date, DateTime.utc_now())
      end
    end

    update :mark_converted do
      accept []
      require_atomic? false
      change set_attribute(:has_converted, true)
    end

    read :by_campaign do
      argument :campaign_id, :uuid, allow_nil?: false
      filter expr(campaign_id == ^arg(:campaign_id))
    end

    read :by_lead do
      argument :lead_id, :uuid, allow_nil?: false
      filter expr(lead_id == ^arg(:lead_id) and member_type == :lead)
    end

    read :by_contact do
      argument :contact_id, :uuid, allow_nil?: false
      filter expr(contact_id == ^arg(:contact_id) and member_type == :contact)
    end

    read :responded_members do
      filter expr(responded == true)
    end

    read :converted_members do
      filter expr(has_converted == true)
    end
  end

  postgres do
    custom_indexes do
      index [:campaign_id, :member_type]
      index [:lead_id]
      index [:contact_id]
      index [:status]
    end
  end
end
