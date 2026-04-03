defmodule Indrajaal.Compliance.Document do
  @moduledoc """
  Represents compliance documents and supporting materials.

  Documents provide evidence, templates, policies, procedures, and other
  materials supporting compliance activities. They include version control,
  access management, and lifecycle tracking.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.RiskManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Document identification
    attribute :document_number, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :description, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :document_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :policy,
                    :procedure,
                    :standard,
                    :guideline,
                    :template,
                    :checklist,
                    :evidence,
                    :certificate,
                    :report,
                    :assessment,
                    :audit_trail,
                    :training_material,
                    :reference_document,
                    :form,
                    :contract
                  ]

      default :policy
    end

    # Document relationships
    attribute :framework_id, :uuid do
      public? true
    end

    attribute :_requirement_id, :uuid do
      public? true
    end

    attribute :assessment_id, :uuid do
      public? true
    end

    attribute :report_id, :uuid do
      public? true
    end

    attribute :parent_document_id, :uuid do
      public? true
    end

    # Document metadata
    attribute :version, :string do
      allow_nil? false
      public? true
      constraints max_length: 20
      default "1.0"
    end

    attribute :language, :string do
      allow_nil? false
      public? true
      constraints max_length: 5
      default "en"
    end

    attribute :file_format, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :pdf,
                    :word,
                    :excel,
                    :powerpoint,
                    :html,
                    :text,
                    :image,
                    :video,
                    :audio,
                    :archive,
                    :xml,
                    :json,
                    :csv
                  ]

      default :pdf
    end

    attribute :file_size_bytes, :integer do
      public? true
      constraints min: 0
    end

    attribute :file_path, :string do
      public? true
      constraints max_length: 500
    end

    attribute :file_url, :string do
      public? true
      constraints max_length: 500
    end

    attribute :checksum, :string do
      public? true
      constraints max_length: 128
    end

    # Classification and security
    attribute :classification, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :public,
                    :internal,
                    :confidential,
                    :restricted,
                    :top_secret
                  ]

      default :internal
    end

    attribute :sensitivity_level, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :access_level, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:open, :restricted, :authorized_only, :need_to_know]
      default :restricted
    end

    attribute :encryption_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :watermarking?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Authoring and ownership
    attribute :author_id, :uuid do
      public? true
    end

    attribute :owner_id, :uuid do
      public? true
    end

    attribute :custodian_id, :uuid do
      public? true
    end

    attribute :created_by, :string do
      public? true
      constraints max_length: 200
    end

    attribute :organization, :string do
      public? true
      constraints max_length: 200
    end

    attribute :department, :string do
      public? true
      constraints max_length: 100
    end

    # Status and lifecycle
    attribute :status, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :draft,
                    :under_review,
                    :approved,
                    :published,
                    :archived,
                    :superseded,
                    :obsolete,
                    :withdrawn
                  ]

      default :draft
    end

    attribute :lifecycle_stage, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :creation,
                    :review,
                    :approval,
                    :publication,
                    :maintenance,
                    :revision,
                    :retirement,
                    :disposal
                  ]

      default :creation
    end

    # Important dates
    attribute :creation_date, :date do
      allow_nil? false
      public? true
    end

    attribute :last_modified_date, :date do
      public? true
    end

    attribute :review_date, :date do
      public? true
    end

    attribute :approval_date, :date do
      public? true
    end

    attribute :publication_date, :date do
      public? true
    end

    attribute :effective_date, :date do
      public? true
    end

    attribute :expiration_date, :date do
      public? true
    end

    attribute :next_review_date, :date do
      public? true
    end

    # Review and approval workflow
    attribute :review_cycle_months, :integer do
      public? true
      constraints min: 1, max: 120
    end

    attribute :reviewer_id, :uuid do
      public? true
    end

    attribute :approver_id, :uuid do
      public? true
    end

    attribute :review_required?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :approval_required?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :peer_review_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Content and purpose
    attribute :purpose, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :scope, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :applicability, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :audience, {:array, :atom} do
      public? true
      default []

      constraints items: [
                    one_of: [
                      :all_staff,
                      :management,
                      :executives,
                      :it_team,
                      :security_team,
                      :compliance_team,
                      :legal_team,
                      :hr_team,
                      :finance_team,
                      :auditors,
                      :contractors,
                      :partners,
                      :regulators,
                      :customers
                    ]
                  ]
    end

    # Related documents and references
    attribute :supersedes_documents, {:array, :uuid} do
      public? true
      default []
    end

    attribute :superseded_by_document_id, :uuid do
      public? true
    end

    attribute :related_documents, {:array, :uuid} do
      public? true
      default []
    end

    attribute :reference_documents, {:array, :string} do
      public? true
      default []
    end

    attribute :external_references, {:array, :string} do
      public? true
      default []
    end

    # Training and awareness
    attribute :training_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :awareness_campaign?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :acknowledgment_required?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :competency_assessment?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    # Access control and distribution
    attribute :authorized_users, {:array, :uuid} do
      public? true
      default []
    end

    attribute :authorized_roles, {:array, :string} do
      public? true
      default []
    end

    attribute :distribution_list, {:array, :string} do
      public? true
      default []
    end

    attribute :public_access?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :download_allowed?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    attribute :print_allowed?, :boolean do
      allow_nil? false
      public? true
      default true
    end

    # Usage tracking
    attribute :view_count, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :download_count, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :last_accessed, :utc_datetime_usec do
      public? true
    end

    attribute :access_log, {:array, :map} do
      public? true
      default []
    end

    # Quality and validation
    attribute :quality_checked?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :accuracy_verified?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :completeness_verified?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :consistency_checked?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :quality_score, :integer do
      public? true
      constraints min: 1, max: 5
    end

    # Compliance relevance
    attribute :compliance_evidence?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :audit_evidence?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :regulatory_relevance, {:array, :string} do
      public? true
      default []
    end

    attribute :control_objective, :string do
      public? true
      constraints max_length: 500
    end

    # Version control
    attribute :version_history, {:array, :map} do
      public? true
      default []
    end

    attribute :major_version, :integer do
      allow_nil? false
      public? true
      constraints min: 1
      default 1
    end

    attribute :minor_version, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
    end

    attribute :change_summary, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :change_reason, :string do
      public? true
      constraints max_length: 500
    end

    # Retention and disposal
    attribute :retention_period_years, :integer do
      public? true
      constraints min: 1, max: 100
    end

    attribute :legal_hold?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :archive_date, :date do
      public? true
    end

    attribute :disposal_date, :date do
      public? true
    end

    attribute :disposal_method, :atom do
      public? true

      constraints one_of: [
                    :secure_deletion,
                    :physical_destruction,
                    :transfer,
                    :archive
                  ]
    end

    # Search and indexing
    attribute :keywords, {:array, :string} do
      public? true
      default []
    end

    attribute :subject_areas, {:array, :string} do
      public? true
      default []
    end

    attribute :searchable_content, :string do
      public? true
      constraints max_length: 10_000
    end

    # Integration and automation
    attribute :automated_updates?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :integration_points, {:array, :string} do
      public? true
      default []
    end

    attribute :sync_with_external?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :external_system_id, :string do
      public? true
      constraints max_length: 100
    end

    # Metadata
    attribute :metadata, :map do
      public? true
      default %{}
    end

    attribute :tags, {:array, :string} do
      public? true
      default []
    end

    timestamps()
  end

  relationships do
    belongs_to :framework, Indrajaal.Compliance.Framework do
      attribute_public? true
    end

    belongs_to :_requirement, Indrajaal.Compliance.Requirement do
      attribute_public? true
    end

    belongs_to :assessment, Indrajaal.Compliance.Assessment do
      attribute_public? true
    end

    belongs_to :report, Indrajaal.Compliance.Report do
      attribute_public? true
    end

    belongs_to :parent_document, Indrajaal.Compliance.Document do
      attribute_public? true
    end

    belongs_to :superseded_by_document, Indrajaal.Compliance.Document do
      attribute_public? true
    end

    belongs_to :author, Indrajaal.Accounts.User do
      attribute_public? true
    end

    belongs_to :owner, Indrajaal.Accounts.User do
      attribute_public? true
    end

    belongs_to :custodian, Indrajaal.Accounts.User do
      attribute_public? true
    end

    belongs_to :reviewer, Indrajaal.Accounts.User do
      attribute_public? true
    end

    belongs_to :approver, Indrajaal.Accounts.User do
      attribute_public? true
    end

    has_many :child_documents, Indrajaal.Compliance.Document do
      source_attribute :id
      destination_attribute :parent_document_id
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :title,
        :description,
        :document_type,
        :framework_id,
        :_requirement_id,
        :assessment_id,
        :report_id,
        :parent_document_id,
        :language,
        :file_format,
        :file_size_bytes,
        :file_path,
        :file_url,
        :classification,
        :sensitivity_level,
        :access_level,
        :encryption_required?,
        :watermarking?,
        :author_id,
        :owner_id,
        :custodian_id,
        :created_by,
        :organization,
        :department,
        :review_cycle_months,
        :reviewer_id,
        :approver_id,
        :review_required?,
        :approval_required?,
        :peer_review_required?,
        :purpose,
        :scope,
        :applicability,
        :audience,
        :supersedes_documents,
        :related_documents,
        :reference_documents,
        :external_references,
        :training_required?,
        :awareness_campaign?,
        :acknowledgment_required?,
        :competency_assessment?,
        :authorized_users,
        :authorized_roles,
        :distribution_list,
        :public_access?,
        :download_allowed?,
        :print_allowed?,
        :compliance_evidence?,
        :audit_evidence?,
        :regulatory_relevance,
        :control_objective,
        :change_summary,
        :change_reason,
        :retention_period_years,
        :keywords,
        :subject_areas,
        :automated_updates?,
        :integration_points,
        :sync_with_external?,
        :external_system_id,
        :metadata
      ]

      change fn changeset, _context ->
        next_review = calculate_next_review_date(changeset)

        changeset
        |> generate_document_number()
        |> Ash.Changeset.force_change_attribute(:creation_date, Date.utc_today())
        |> Ash.Changeset.force_change_attribute(:status, :draft)
        |> Ash.Changeset.force_change_attribute(:lifecycle_stage, :creation)
        |> apply_next_review_date(next_review)
      end
    end

    update :update do
      require_atomic? false
      primary? true

      accept [
        :title,
        :description,
        :language,
        :file_size_bytes,
        :file_path,
        :file_url,
        :classification,
        :sensitivity_level,
        :access_level,
        :encryption_required?,
        :watermarking?,
        :owner_id,
        :custodian_id,
        :organization,
        :department,
        :review_cycle_months,
        :reviewer_id,
        :approver_id,
        :purpose,
        :scope,
        :applicability,
        :audience,
        :related_documents,
        :reference_documents,
        :external_references,
        :training_required?,
        :awareness_campaign?,
        :acknowledgment_required?,
        :competency_assessment?,
        :authorized_users,
        :authorized_roles,
        :distribution_list,
        :public_access?,
        :download_allowed?,
        :print_allowed?,
        :regulatory_relevance,
        :control_objective,
        :change_summary,
        :change_reason,
        :retention_period_years,
        :keywords,
        :subject_areas,
        :automated_updates?,
        :integration_points,
        :sync_with_external?,
        :external_system_id,
        :metadata
      ]

      change fn changeset, _context ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :last_modified_date,
          Date.utc_today()
        )
      end
    end

    update :submit_for_review do
      require_atomic? false
      accept [:status, :lifecycle_stage]

      validate attribute_equals(:status, :draft)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :under_review)
        |> Ash.Changeset.force_change_attribute(:lifecycle_stage, :review)
      end
    end

    update :approve do
      require_atomic? false
      accept [:status, :lifecycle_stage, :approval_date, :quality_checked?]

      argument :approver_notes, :string do
        constraints max_length: 1000
      end

      validate attribute_equals(:status, :under_review)

      change fn changeset, _context ->
        approver_notes = changeset.arguments.approver_notes

        version_entry = %{
          "version" => Ash.Changeset.get_attribute(changeset, :version),
          "date" => Date.utc_today(),
          "action" => "approved",
          "notes" => approver_notes
        }

        version_history = Ash.Changeset.get_attribute(changeset, :version_history) || []

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :approved)
        |> Ash.Changeset.force_change_attribute(:lifecycle_stage, :approval)
        |> Ash.Changeset.force_change_attribute(:approval_date, Date.utc_today())
        |> Ash.Changeset.force_change_attribute(:quality_checked?, true)
        |> Ash.Changeset.force_change_attribute(
          :version_history,
          [version_entry | version_history]
        )
      end
    end

    update :publish do
      require_atomic? false
      accept [:status, :lifecycle_stage, :publication_date, :effective_date]

      validate attribute_equals(:status, :approved)

      change fn changeset, _context ->
        publication_date = Date.utc_today()
        # Could be different if specified
        effective_date = Date.utc_today()

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :published)
        |> Ash.Changeset.force_change_attribute(:lifecycle_stage, :publication)
        |> Ash.Changeset.force_change_attribute(:publication_date, publication_date)
        |> Ash.Changeset.force_change_attribute(:effective_date, effective_date)
      end
    end

    update :create_new_version do
      require_atomic? false
      accept [:version, :major_version, :minor_version, :change_summary, :change_reason]

      argument :version_type, :atom do
        allow_nil? false
        constraints one_of: [:major, :minor]
      end

      argument :change_summary, :string do
        allow_nil? false
        constraints max_length: 1000
      end

      change fn changeset, _context ->
        version_type = changeset.arguments.version_type
        change_summary = changeset.arguments.change_summary

        current_major = Ash.Changeset.get_attribute(changeset, :major_version)
        current_minor = Ash.Changeset.get_attribute(changeset, :minor_version)

        {new_major, new_minor, new_version} =
          case version_type do
            :major -> {current_major + 1, 0, "#{current_major + 1}.0"}
            :minor -> {current_major, current_minor + 1, "#{current_major}.#{current_minor + 1}"}
          end

        version_entry = %{
          "version" => new_version,
          "date" => Date.utc_today(),
          "action" => "new_version",
          "type" => version_type,
          "summary" => change_summary
        }

        version_history = Ash.Changeset.get_attribute(changeset, :version_history) || []

        updated_changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:version, new_version)
          |> Ash.Changeset.force_change_attribute(:major_version, new_major)
          |> Ash.Changeset.force_change_attribute(:minor_version, new_minor)
          |> Ash.Changeset.force_change_attribute(:change_summary, change_summary)
          |> Ash.Changeset.force_change_attribute(:status, :draft)

        updated_changeset
        |> Ash.Changeset.force_change_attribute(:lifecycle_stage, :creation)
        |> Ash.Changeset.force_change_attribute(
          :version_history,
          [version_entry | version_history]
        )
      end
    end

    update :supersede do
      require_atomic? false
      accept [:status, :superseded_by_document_id]

      argument :new_document_id, :uuid do
        allow_nil? false
      end

      validate attribute_equals(:status, :published)

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :superseded)
        |> Ash.Changeset.force_change_attribute(
          :superseded_by_document_id,
          changeset.arguments.new_document_id
        )
      end
    end

    update :track_access do
      require_atomic? false
      accept [:view_count, :download_count, :last_accessed, :access_log]

      argument :access_type, :atom do
        allow_nil? false
        constraints one_of: [:view, :download, :print]
      end

      argument :user_id, :uuid
      argument :ip_address, :string

      change fn changeset, _context ->
        access_type = changeset.arguments.access_type
        user_id = changeset.arguments.user_id
        ip_address = changeset.arguments.ip_address

        access_entry = %{
          "type" => access_type,
          "user_id" => user_id,
          "ip_address" => ip_address,
          "timestamp" => DateTime.utc_now()
        }

        access_log = Ash.Changeset.get_attribute(changeset, :access_log) || []
        # Keep only last 100 entries
        updated_log = [access_entry | Enum.take(access_log, 99)]

        _changeset =
          changeset
          |> Ash.Changeset.force_change_attribute(:last_accessed, DateTime.utc_now())
          |> Ash.Changeset.force_change_attribute(:access_log, updated_log)

        case access_type do
          :view ->
            current_views = Ash.Changeset.get_attribute(changeset, :view_count)
            Ash.Changeset.force_change_attribute(changeset, :view_count, current_views + 1)

          :download ->
            current_downloads = Ash.Changeset.get_attribute(changeset, :download_count)

            Ash.Changeset.force_change_attribute(
              changeset,
              :download_count,
              current_downloads + 1
            )

          _ ->
            changeset
        end
      end
    end

    update :schedule_review do
      require_atomic? false
      accept [:next_review_date, :review_date]

      change fn changeset, _context ->
        review_cycle = Ash.Changeset.get_attribute(changeset, :review_cycle_months)

        if review_cycle do
          next_review = Date.add(Date.utc_today(), review_cycle * 30)
          Ash.Changeset.force_change_attribute(changeset, :next_review_date, next_review)
        else
          changeset
        end
      end
    end

    update :archive do
      require_atomic? false
      accept [:status, :lifecycle_stage, :archive_date]

      validate attribute_in(:status, [:published, :superseded])

      change fn changeset, _context ->
        retention_years = Ash.Changeset.get_attribute(changeset, :retention_period_years) || 7
        archive_date = Date.utc_today()
        disposal_date = Date.add(archive_date, retention_years * 365)

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :archived)
        |> Ash.Changeset.force_change_attribute(:lifecycle_stage, :retirement)
        |> Ash.Changeset.force_change_attribute(:archive_date, archive_date)
        |> Ash.Changeset.force_change_attribute(:disposal_date, disposal_date)
      end
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :is_current?, :boolean do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn document ->
              document.status == :published && is_nil(document.superseded_by_document_id)
            end
          )

        {:ok, values}
      end
    end

    calculate :is_due_for_review?, :boolean do
      calculation fn records, _context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn document ->
              document.next_review_date &&
                Date.compare(
                  today,
                  document.next_review_date
                ) != :lt
            end
          )

        {:ok, values}
      end
    end

    calculate :days_until_review, :integer do
      calculation fn records, _context ->
        today = Date.utc_today()

        values =
          Enum.map(
            records,
            fn document ->
              if document.next_review_date do
                Date.diff(
                  document.next_review_date,
                  today
                )
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end

    calculate :age_in_days, :integer do
      calculation fn records, _context ->
        today = Date.utc_today()

        values =
          Enum.map(records, fn document ->
            Date.diff(today, document.creation_date)
          end)

        {:ok, values}
      end
    end

    calculate :usage_score, :float do
      calculation fn records, _context ->
        values =
          Enum.map(records, fn document ->
            age_days = Date.diff(Date.utc_today(), document.creation_date)

            if age_days > 0 do
              # Simple usage score: (views + downloads) / age in days
              (document.view_count + document.download_count) / age_days
            else
              0.0
            end
          end)

        {:ok, values}
      end
    end

    calculate :file_size_mb, :float do
      calculation fn records, _context ->
        values =
          Enum.map(
            records,
            fn document ->
              if document.file_size_bytes do
                document.file_size_bytes / (1024 * 1024)
              else
                nil
              end
            end
          )

        {:ok, values}
      end
    end
  end

  policies do
    bypass always() do
      authorize_if actor_attribute_equals(:role, "admin")
    end

    policy action(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "auditor")
      authorize_if actor_attribute_equals(:role, "manager")
      authorize_if actor_attribute_equals(:role, "legal")
      # Public documents can be read by anyone
      authorize_if expr(public_access? == true)
      # Document author / owner can read their documents
      authorize_if expr(author_id == ^actor(:id))
      authorize_if expr(owner_id == ^actor(:id))
      # Authorized _users can read documents
      authorize_if expr(^actor(:id) in authorized_users)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "legal")
      # Document author / owner can edit their documents
      authorize_if expr(author_id == ^actor(:id))
      authorize_if expr(owner_id == ^actor(:id))
    end

    policy action([:submit_for_review, :create_new_version]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      # Document author can submit for review
      authorize_if expr(author_id == ^actor(:id))
    end

    policy action([:approve, :publish, :supersede, :archive]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "compliance_officer")
      authorize_if actor_attribute_equals(:role, "manager")
      # Document approver can approve their documents
      authorize_if expr(approver_id == ^actor(:id))
    end

    policy action([:track_access, :schedule_review]) do
      # System can track access for any document
      authorize_if always()
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :submit_for_review
    define :approve
    define :publish
    define :create_new_version
    define :supersede
    define :track_access
    define :schedule_review
    define :archive
    define :destroy
  end

  postgres do
    table "compliance_documents"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :document_number], unique: true
      index [:framework_id], where: "framework_id IS NOT NULL"
      index [:_requirement_id], where: "_requirement_id IS NOT NULL"
      index [:assessment_id], where: "assessment_id IS NOT NULL"
      index [:report_id], where: "report_id IS NOT NULL"
      index [:parent_document_id], where: "parent_document_id IS NOT NULL"

      index [:superseded_by_document_id],
        where: "superseded_by_document_id IS NOT NULL"

      index [:author_id], where: "author_id IS NOT NULL"
      index [:owner_id], where: "owner_id IS NOT NULL"
      index [:custodian_id], where: "custodian_id IS NOT NULL"
      index [:reviewer_id], where: "reviewer_id IS NOT NULL"
      index [:approver_id], where: "approver_id IS NOT NULL"
      index [:document_type]
      index [:file_format]
      index [:classification]
      index [:sensitivity_level]
      index [:access_level]
      index [:status]
      index [:lifecycle_stage]
      index [:creation_date]
      index [:effective_date], where: "effective_date IS NOT NULL"
      index [:expiration_date], where: "expiration_date IS NOT NULL"
      index [:next_review_date], where: "next_review_date IS NOT NULL"

      index [:public_access?],
        name: "documents_public_access_index",
        where: "public_access? = true"

      index [:compliance_evidence?],
        name: "documents_compliance_evidence_index",
        where: "compliance_evidence? = true"

      index [:audit_evidence?],
        name: "documents_audit_evidence_index",
        where: "audit_evidence? = true"

      index [:training_required?],
        name: "documents_training_required_index",
        where: "training_required? = true"

      index [:review_required?],
        name: "documents_review_required_index",
        where: "review_required? = true"

      index [:legal_hold?], name: "documents_legal_hold_index", where: "legal_hold? = true"
      index [:archive_date], where: "archive_date IS NOT NULL"
    end
  end

  # Helper functions
  @spec apply_next_review_date(term(), Date.t() | nil) :: term()
  defp apply_next_review_date(changeset, next_review) do
    if next_review do
      Ash.Changeset.force_change_attribute(changeset, :next_review_date, next_review)
    else
      changeset
    end
  end

  @spec generate_document_number(term()) :: term()
  defp generate_document_number(changeset) do
    Indrajaal.Compliance.Helpers.generate_numbered_identifier(
      "DOC",
      changeset,
      :document_number
    )
  end

  @spec calculate_next_review_date(term()) :: term()
  defp calculate_next_review_date(changeset) do
    review_cycle = Ash.Changeset.get_argument_or_attribute(changeset, :review_cycle_months)

    if review_cycle do
      Date.add(Date.utc_today(), review_cycle * 30)
    else
      nil
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: Compliance
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
