defmodule Indrajaal.Federation.Membership do
  @moduledoc """
  Federation Membership - Node Lifecycle Management for v20.0.0

  Manages the membership lifecycle of Jain nodes:
  - Application and approval
  - Probationary period
  - Full membership
  - Suspension and expulsion
  - Voluntary departure

  ## Membership States
  - **Applicant**: Requesting to join
  - **Probationary**: Newly joined, limited privileges
  - **Full**: Full federation member
  - **Suspended**: Temporarily restricted
  - **Expelled**: Permanently removed

  ## Membership Requirements
  1. Valid constitution
  2. Adequate resources
  3. Passing health check
  4. Consensus approval (for full membership)

  ## STAMP Constraints
  - SC-MEM-001: Membership changes MUST be logged
  - SC-MEM-002: Expulsion MUST be consensus-based
  - SC-MEM-003: Probationary period MUST be enforced
  - SC-MEM-004: Constitution verification MUST precede acceptance
  """

  require Logger

  alias Indrajaal.Federation.{Consensus, Directory}

  @type membership_state ::
          :applicant | :probationary | :full | :suspended | :expelled | :departed

  @type membership_record :: %{
          node_id: String.t(),
          state: membership_state(),
          applied_at: DateTime.t(),
          accepted_at: DateTime.t() | nil,
          promoted_at: DateTime.t() | nil,
          suspended_at: DateTime.t() | nil,
          expelled_at: DateTime.t() | nil,
          departed_at: DateTime.t() | nil,
          metadata: map()
        }

  @type membership_application :: %{
          node_id: String.t(),
          constitution_hash: binary(),
          resources: map(),
          endpoints: [String.t()],
          parent_id: String.t() | nil
        }

  # Probationary period duration (hours)
  @probationary_period_hours 24

  # Minimum votes for expulsion - used by Consensus module
  # @expulsion_quorum 0.67

  @doc """
  Applies for federation membership.
  """
  @spec apply(membership_application()) :: {:ok, membership_record()} | {:error, term()}
  def apply(application) do
    Logger.info("Processing membership application from #{application.node_id}")

    with :ok <- verify_application(application),
         :ok <- check_duplicate(application.node_id),
         {:ok, record} <- create_applicant_record(application) do
      Logger.info("Application accepted for #{application.node_id}")
      {:ok, record}
    end
  end

  @doc """
  Approves an application (moves to probationary).
  """
  @spec approve(String.t()) :: {:ok, membership_record()} | {:error, term()}
  def approve(node_id) do
    Logger.info("Approving membership for #{node_id}")

    case get_record(node_id) do
      {:ok, record} when record.state == :applicant ->
        new_record = %{
          record
          | state: :probationary,
            accepted_at: DateTime.utc_now()
        }

        save_record(new_record)
        schedule_promotion_check(node_id)

        Logger.info("#{node_id} approved - now probationary")

        {:ok, new_record}

      {:ok, record} ->
        {:error, {:invalid_state, record.state}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Promotes a probationary member to full membership.
  """
  @spec promote(String.t()) :: {:ok, membership_record()} | {:error, term()}
  def promote(node_id) do
    Logger.info("Promoting #{node_id} to full membership")

    case get_record(node_id) do
      {:ok, record} when record.state == :probationary ->
        # Check probationary period
        if probationary_period_complete?(record) do
          new_record = %{
            record
            | state: :full,
              promoted_at: DateTime.utc_now()
          }

          save_record(new_record)

          Logger.info("#{node_id} promoted to full member")

          {:ok, new_record}
        else
          {:error, :probationary_period_incomplete}
        end

      {:ok, record} ->
        {:error, {:invalid_state, record.state}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Suspends a member.
  """
  @spec suspend(String.t(), String.t()) :: {:ok, membership_record()} | {:error, term()}
  def suspend(node_id, reason) do
    Logger.warning("Suspending #{node_id}: #{reason}")

    case get_record(node_id) do
      {:ok, record} when record.state in [:probationary, :full] ->
        new_record = %{
          record
          | state: :suspended,
            suspended_at: DateTime.utc_now(),
            metadata: Map.put(record.metadata, :suspension_reason, reason)
        }

        save_record(new_record)

        Logger.info("#{node_id} suspended")

        {:ok, new_record}

      {:ok, record} ->
        {:error, {:invalid_state, record.state}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Reinstates a suspended member.
  """
  @spec reinstate(String.t()) :: {:ok, membership_record()} | {:error, term()}
  def reinstate(node_id) do
    Logger.info("Reinstating #{node_id}")

    case get_record(node_id) do
      {:ok, record} when record.state == :suspended ->
        # Restore to previous state (probationary or full)
        previous_state = if record.promoted_at, do: :full, else: :probationary

        new_record = %{
          record
          | state: previous_state,
            suspended_at: nil,
            metadata: Map.delete(record.metadata, :suspension_reason)
        }

        save_record(new_record)

        Logger.info("#{node_id} reinstated to #{previous_state}")

        {:ok, new_record}

      {:ok, record} ->
        {:error, {:invalid_state, record.state}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Expels a member (requires consensus).
  """
  @spec expel(String.t(), String.t()) :: {:ok, membership_record()} | {:error, term()}
  def expel(node_id, reason) do
    Logger.warning("🚫 Processing expulsion for #{node_id}: #{reason}")

    case get_record(node_id) do
      {:ok, record} when record.state != :expelled ->
        # SC-MEM-002: Expulsion requires consensus
        case Consensus.propose(:expulsion, %{node_id: node_id, reason: reason}) do
          {:ok, %{approved: true}} ->
            new_record = %{
              record
              | state: :expelled,
                expelled_at: DateTime.utc_now(),
                metadata: Map.put(record.metadata, :expulsion_reason, reason)
            }

            save_record(new_record)
            notify_expulsion(node_id, reason)

            Logger.warning("🚫 #{node_id} expelled from federation")

            {:ok, new_record}

          {:ok, %{approved: false}} ->
            {:error, :expulsion_rejected}

          {:error, _} = error ->
            error
        end

      {:ok, record} ->
        {:error, {:invalid_state, record.state}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Processes voluntary departure.
  """
  @spec depart(String.t()) :: {:ok, membership_record()} | {:error, term()}
  def depart(node_id) do
    Logger.info("Processing departure for #{node_id}")

    case get_record(node_id) do
      {:ok, record} when record.state not in [:expelled, :departed] ->
        new_record = %{
          record
          | state: :departed,
            departed_at: DateTime.utc_now()
        }

        save_record(new_record)

        Logger.info("#{node_id} has departed the federation")

        {:ok, new_record}

      {:ok, record} ->
        {:error, {:invalid_state, record.state}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Gets membership record for a node.
  """
  @spec get_record(String.t()) :: {:ok, membership_record()} | {:error, :not_found}
  def get_record(node_id) do
    # In production, would query database
    case Directory.get_node(node_id) do
      {:ok, node_info} ->
        {:ok, node_info.membership}

      {:error, _} ->
        {:error, :not_found}
    end
  end

  @doc """
  Lists all members by state.
  """
  @spec list_by_state(membership_state()) :: [membership_record()]
  def list_by_state(state) do
    # In production, would query database
    Directory.list_nodes()
    |> Enum.filter(fn node -> node.membership.state == state end)
    |> Enum.map(fn node -> node.membership end)
  end

  @doc """
  Gets membership statistics.
  """
  @spec stats() :: map()
  def stats do
    all_nodes = Directory.list_nodes()

    %{
      total: length(all_nodes),
      applicants: count_by_state(all_nodes, :applicant),
      probationary: count_by_state(all_nodes, :probationary),
      full: count_by_state(all_nodes, :full),
      suspended: count_by_state(all_nodes, :suspended),
      expelled: count_by_state(all_nodes, :expelled),
      departed: count_by_state(all_nodes, :departed)
    }
  end

  @doc """
  Checks if a node is a current member (any active state).
  """
  @spec member?(String.t()) :: boolean()
  def member?(node_id) do
    case get_record(node_id) do
      {:ok, record} -> record.state in [:probationary, :full]
      {:error, _} -> false
    end
  end

  @doc """
  Checks if a node has full membership privileges.
  """
  @spec full_member?(String.t()) :: boolean()
  def full_member?(node_id) do
    case get_record(node_id) do
      {:ok, record} -> record.state == :full
      {:error, _} -> false
    end
  end

  # Private helpers

  defp verify_application(application) do
    cond do
      is_nil(application.node_id) or application.node_id == "" ->
        {:error, :invalid_node_id}

      is_nil(application.constitution_hash) ->
        {:error, :no_constitution}

      not valid_resources?(application.resources) ->
        {:error, :insufficient_resources}

      true ->
        # Verify constitution matches federation
        verify_constitution(application.constitution_hash)
    end
  end

  defp valid_resources?(resources) when is_map(resources) do
    # Check minimum resource requirements
    cpu = Map.get(resources, :cpu, 0)
    memory = Map.get(resources, :memory, 0)
    storage = Map.get(resources, :storage, 0)

    cpu >= 0.1 and memory >= 512 * 1024 * 1024 and storage >= 1024 * 1024 * 1024
  end

  defp valid_resources?(_), do: false

  defp verify_constitution(hash) do
    federation_hash = get_federation_constitution_hash()

    if hash == federation_hash do
      :ok
    else
      {:error, :constitution_mismatch}
    end
  end

  defp get_federation_constitution_hash do
    # In production, would load from federation configuration
    "federation_constitution_hash"
  end

  defp check_duplicate(node_id) do
    case get_record(node_id) do
      {:ok, record} when record.state not in [:departed, :expelled] ->
        {:error, :already_member}

      _ ->
        :ok
    end
  end

  defp create_applicant_record(application) do
    record = %{
      node_id: application.node_id,
      state: :applicant,
      applied_at: DateTime.utc_now(),
      accepted_at: nil,
      promoted_at: nil,
      suspended_at: nil,
      expelled_at: nil,
      departed_at: nil,
      metadata: %{
        parent_id: application.parent_id,
        endpoints: application.endpoints,
        constitution_hash: application.constitution_hash
      }
    }

    # In production, would persist to database
    {:ok, record}
  end

  defp save_record(_record) do
    # In production, would persist to database
    :ok
  end

  defp schedule_promotion_check(node_id) do
    # Schedule automatic promotion check after probationary period
    delay_ms = @probationary_period_hours * 60 * 60 * 1000

    Task.start(fn ->
      Process.sleep(delay_ms)
      maybe_auto_promote(node_id)
    end)
  end

  defp maybe_auto_promote(node_id) do
    case get_record(node_id) do
      {:ok, record} when record.state == :probationary ->
        if probationary_period_complete?(record) do
          promote(node_id)
        end

      _ ->
        :ok
    end
  end

  defp probationary_period_complete?(record) do
    hours_since_accepted =
      DateTime.diff(DateTime.utc_now(), record.accepted_at, :hour)

    hours_since_accepted >= @probationary_period_hours
  end

  defp count_by_state(nodes, state) do
    Enum.count(nodes, fn node -> node.membership.state == state end)
  end

  defp notify_expulsion(node_id, reason) do
    # In production, would broadcast to federation
    Logger.info("Broadcasting expulsion notice for #{node_id}: #{reason}")
    :ok
  end
end
