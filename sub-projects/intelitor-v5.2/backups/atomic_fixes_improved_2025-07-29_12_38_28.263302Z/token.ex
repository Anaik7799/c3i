defmodule Intelitor.Accounts.Token do
  @moduledoc """
  Token resource for authentication.

  Stores JWT tokens, API keys, and other authentication tokens.
  Will be extended with AshAuthentication.TokenResource when fully integrated.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Accounts,
    table: "tokens"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :token_hash, :string do
      allow_nil? false
      sensitive? true
      description "Hashed token value"
    end

    attribute :type, :atom do
      allow_nil? false
      constraints one_of: [:access, :refresh, :api, :reset_password, :confirm_email]
      description "Token type"
    end

    attribute :purpose, :string do
      constraints max_length: 255
      description "Token purpose/description"
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
      description "Token expiration"
    end

    attribute :revoked_at, :utc_datetime_usec do
      description "When token was revoked"
    end

    attribute :used_at, :utc_datetime_usec do
      description "When token was last used"
    end

    attribute :metadata, :map do
      default %{}
      description "Additional token data"
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Intelitor.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_token, [:token_hash]
  end

  actions do
    defaults [:read]

    create :create do
      accept [:user_id, :type, :purpose, :metadata]

      argument :token, :string do
        allow_nil? false
      end

      argument :ttl_seconds, :integer do
        default 3600
      end

      change fn changeset, _ ->
        token = Ash.Changeset.get_argument(changeset, :token)
        ttl = Ash.Changeset.get_argument(changeset, :ttl_seconds)

        changeset
        |> Ash.Changeset.change_attribute(:token_hash, hash_token(token))
        |> Ash.Changeset.change_attribute(
          :expires_at,
          DateTime.add(DateTime.utc_now(), ttl, :second)
        )
      end
    end

    update :revoke do
      require_atomic? false
      accept []

      change set_attribute(:revoked_at, &DateTime.utc_now/0)
    end

    update :mark_used do
      require_atomic? false
      accept []

      change set_attribute(:used_at, &DateTime.utc_now/0)
    end

    destroy :destroy do
      require_atomic? false
      soft? true
      change set_attribute(:revoked_at, &DateTime.utc_now/0)
    end
  end

  calculations do
    calculate :is_expired?, :boolean, expr(expires_at < now())

    calculate :is_revoked?, :boolean, expr(not is_nil(revoked_at))

    calculate :is_valid?, :boolean, expr(is_nil(revoked_at) and expires_at > now())
  end

  validations do
    validate compare(:expires_at, greater_than: :inserted_at)
  end

  policies do
    # Users can read their own tokens
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Users can revoke their own tokens
    policy action([:revoke, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Only system can create tokens
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:is_system, true)
    end
  end

  code_interface do
    # get and list are already defined in BaseResource
    define :create
    define :revoke
    define :mark_used
  end

  postgres do
    table "tokens"
    repo Intelitor.Repo

    custom_indexes do
      index [:token_hash], unique: true
      index [:user_id, :type]
      index [:expires_at], where: "revoked_at IS NULL"
      index [:type, :expires_at], where: "revoked_at IS NULL"
    end
  end

  # Helper function
  defp hash_token(token) do
    :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
  end
end
