defmodule Indrajaal.Compute.Wallet do
  @moduledoc """
  Agent Wallet - Credit Account Management for v20.0.0

  Implements wallet functionality for agents:
  - Balance tracking per agent
  - Transaction history
  - Spending limits
  - Overdraft protection

  ## Wallet Model

  Wallet = {agent_id, balance, history, limits, status}

  ## Features
  - **Balance**: Current credit balance
  - **History**: Transaction log with timestamps
  - **Limits**: Daily/hourly spending limits
  - **Status**: Active, frozen, or suspended

  ## STAMP Constraints
  - SC-WAL-001: Balance MUST be non-negative
  - SC-WAL-002: History MUST be append-only
  - SC-WAL-003: Frozen wallets MUST reject transactions
  - SC-WAL-004: Limits MUST be enforced
  """

  use GenServer
  require Logger

  alias Indrajaal.Compute.Credits

  @type wallet_id :: String.t()
  @type transaction_type :: :credit | :debit | :transfer_in | :transfer_out

  @type transaction :: %{
          id: String.t(),
          type: transaction_type(),
          amount: non_neg_integer(),
          counterparty: wallet_id() | nil,
          timestamp: DateTime.t(),
          memo: String.t() | nil
        }

  @type wallet :: %{
          id: wallet_id(),
          agent_id: String.t(),
          balance: non_neg_integer(),
          history: [transaction()],
          limits: map(),
          status: :active | :frozen | :suspended,
          created_at: DateTime.t()
        }

  @type state :: %{
          wallets: map()
        }

  # Default spending limits
  @default_limits %{
    hourly: 10_000,
    daily: 100_000,
    per_transaction: 50_000
  }

  # History retention
  @max_history_size 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a new wallet for an agent.
  """
  @spec create(String.t(), Keyword.t()) :: {:ok, wallet()} | {:error, term()}
  def create(agent_id, opts \\ []) do
    GenServer.call(__MODULE__, {:create, agent_id, opts})
  end

  @doc """
  Gets wallet info.
  """
  @spec get(wallet_id()) :: {:ok, wallet()} | {:error, :not_found}
  def get(wallet_id) do
    GenServer.call(__MODULE__, {:get, wallet_id})
  end

  @doc """
  Gets wallet balance.
  """
  @spec balance(wallet_id()) :: {:ok, non_neg_integer()} | {:error, :not_found}
  def balance(wallet_id) do
    GenServer.call(__MODULE__, {:balance, wallet_id})
  end

  @doc """
  Credits the wallet (add funds).
  """
  @spec credit(wallet_id(), non_neg_integer(), String.t()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def credit(wallet_id, amount, memo \\ nil) do
    GenServer.call(__MODULE__, {:credit, wallet_id, amount, memo})
  end

  @doc """
  Debits the wallet (remove funds).
  """
  @spec debit(wallet_id(), non_neg_integer(), String.t()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def debit(wallet_id, amount, memo \\ nil) do
    GenServer.call(__MODULE__, {:debit, wallet_id, amount, memo})
  end

  @doc """
  Transfers between wallets.
  """
  @spec transfer(wallet_id(), wallet_id(), non_neg_integer(), String.t()) ::
          {:ok, :transferred} | {:error, term()}
  def transfer(from_wallet, to_wallet, amount, memo \\ nil) do
    GenServer.call(__MODULE__, {:transfer, from_wallet, to_wallet, amount, memo})
  end

  @doc """
  Freezes a wallet.
  """
  @spec freeze(wallet_id()) :: :ok | {:error, term()}
  def freeze(wallet_id) do
    GenServer.call(__MODULE__, {:set_status, wallet_id, :frozen})
  end

  @doc """
  Unfreezes a wallet.
  """
  @spec unfreeze(wallet_id()) :: :ok | {:error, term()}
  def unfreeze(wallet_id) do
    GenServer.call(__MODULE__, {:set_status, wallet_id, :active})
  end

  @doc """
  Gets transaction history.
  """
  @spec history(wallet_id(), Keyword.t()) :: {:ok, [transaction()]} | {:error, :not_found}
  def history(wallet_id, opts \\ []) do
    GenServer.call(__MODULE__, {:history, wallet_id, opts})
  end

  @doc """
  Sets spending limits.
  """
  @spec set_limits(wallet_id(), map()) :: :ok | {:error, term()}
  def set_limits(wallet_id, limits) do
    GenServer.call(__MODULE__, {:set_limits, wallet_id, limits})
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    {:ok, %{wallets: %{}}}
  end

  @impl true
  def handle_call({:create, agent_id, opts}, _from, state) do
    wallet_id = generate_wallet_id(agent_id)

    if Map.has_key?(state.wallets, wallet_id) do
      {:reply, {:error, :already_exists}, state}
    else
      initial_balance = Keyword.get(opts, :initial_balance, 0)
      role = Keyword.get(opts, :role, :worker)
      allocation = Credits.initial_allocation(role)

      wallet = %{
        id: wallet_id,
        agent_id: agent_id,
        balance: initial_balance + allocation,
        history: [],
        limits: Keyword.get(opts, :limits, @default_limits),
        status: :active,
        created_at: DateTime.utc_now()
      }

      # Add initial transaction
      wallet =
        if allocation > 0 do
          add_transaction(wallet, :credit, allocation, nil, "Initial allocation")
        else
          wallet
        end

      new_wallets = Map.put(state.wallets, wallet_id, wallet)
      {:reply, {:ok, wallet}, %{state | wallets: new_wallets}}
    end
  end

  @impl true
  def handle_call({:get, wallet_id}, _from, state) do
    case Map.get(state.wallets, wallet_id) do
      nil -> {:reply, {:error, :not_found}, state}
      wallet -> {:reply, {:ok, wallet}, state}
    end
  end

  @impl true
  def handle_call({:balance, wallet_id}, _from, state) do
    case Map.get(state.wallets, wallet_id) do
      nil -> {:reply, {:error, :not_found}, state}
      wallet -> {:reply, {:ok, wallet.balance}, state}
    end
  end

  @impl true
  def handle_call({:credit, wallet_id, amount, memo}, _from, state) do
    case Map.get(state.wallets, wallet_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{status: :frozen} ->
        {:reply, {:error, :wallet_frozen}, state}

      wallet ->
        new_wallet =
          wallet
          |> Map.update!(:balance, &(&1 + amount))
          |> add_transaction(:credit, amount, nil, memo)

        new_wallets = Map.put(state.wallets, wallet_id, new_wallet)
        {:reply, {:ok, new_wallet.balance}, %{state | wallets: new_wallets}}
    end
  end

  @impl true
  def handle_call({:debit, wallet_id, amount, memo}, _from, state) do
    case Map.get(state.wallets, wallet_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{status: :frozen} ->
        {:reply, {:error, :wallet_frozen}, state}

      wallet ->
        # Check balance (SC-WAL-001)
        if wallet.balance < amount do
          {:reply, {:error, :insufficient_balance}, state}
        else
          # Check limits (SC-WAL-004)
          case check_limits(wallet, amount) do
            :ok ->
              new_wallet =
                wallet
                |> Map.update!(:balance, &(&1 - amount))
                |> add_transaction(:debit, amount, nil, memo)

              new_wallets = Map.put(state.wallets, wallet_id, new_wallet)
              {:reply, {:ok, new_wallet.balance}, %{state | wallets: new_wallets}}

            {:error, reason} ->
              {:reply, {:error, reason}, state}
          end
        end
    end
  end

  @impl true
  def handle_call({:transfer, from_id, to_id, amount, memo}, _from, state) do
    from_wallet = Map.get(state.wallets, from_id)
    to_wallet = Map.get(state.wallets, to_id)

    cond do
      from_wallet == nil ->
        {:reply, {:error, :sender_not_found}, state}

      to_wallet == nil ->
        {:reply, {:error, :recipient_not_found}, state}

      from_wallet.status == :frozen ->
        {:reply, {:error, :sender_frozen}, state}

      from_wallet.balance < amount ->
        {:reply, {:error, :insufficient_balance}, state}

      true ->
        case check_limits(from_wallet, amount) do
          :ok ->
            # Atomic transfer
            new_from =
              from_wallet
              |> Map.update!(:balance, &(&1 - amount))
              |> add_transaction(:transfer_out, amount, to_id, memo)

            new_to =
              to_wallet
              |> Map.update!(:balance, &(&1 + amount))
              |> add_transaction(:transfer_in, amount, from_id, memo)

            new_wallets =
              state.wallets
              |> Map.put(from_id, new_from)
              |> Map.put(to_id, new_to)

            {:reply, {:ok, :transferred}, %{state | wallets: new_wallets}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:set_status, wallet_id, status}, _from, state) do
    case Map.get(state.wallets, wallet_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      wallet ->
        new_wallet = %{wallet | status: status}
        new_wallets = Map.put(state.wallets, wallet_id, new_wallet)
        {:reply, :ok, %{state | wallets: new_wallets}}
    end
  end

  @impl true
  def handle_call({:history, wallet_id, opts}, _from, state) do
    case Map.get(state.wallets, wallet_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      wallet ->
        history =
          wallet.history
          |> filter_history(opts)
          |> Enum.take(Keyword.get(opts, :limit, 100))

        {:reply, {:ok, history}, state}
    end
  end

  @impl true
  def handle_call({:set_limits, wallet_id, limits}, _from, state) do
    case Map.get(state.wallets, wallet_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      wallet ->
        new_limits = Map.merge(wallet.limits, limits)
        new_wallet = %{wallet | limits: new_limits}
        new_wallets = Map.put(state.wallets, wallet_id, new_wallet)
        {:reply, :ok, %{state | wallets: new_wallets}}
    end
  end

  # Private helpers

  defp generate_wallet_id(agent_id) do
    "wallet_#{agent_id}_#{:erlang.unique_integer([:positive])}"
  end

  defp add_transaction(wallet, type, amount, counterparty, memo) do
    transaction = %{
      id: generate_tx_id(),
      type: type,
      amount: amount,
      counterparty: counterparty,
      timestamp: DateTime.utc_now(),
      memo: memo
    }

    # Append-only history (SC-WAL-002)
    new_history = [transaction | Enum.take(wallet.history, @max_history_size - 1)]
    %{wallet | history: new_history}
  end

  defp generate_tx_id do
    bytes = :crypto.strong_rand_bytes(8)
    encoded = bytes |> Base.encode16(case: :lower)
    "tx_#{encoded}"
  end

  defp check_limits(wallet, amount) do
    limits = wallet.limits
    now = DateTime.utc_now()

    # Check per-transaction limit
    if amount > Map.get(limits, :per_transaction, :infinity) do
      {:error, :exceeds_transaction_limit}
    else
      # Check hourly limit
      hourly_spent = sum_recent_spending(wallet.history, now, 3600)

      if hourly_spent + amount > Map.get(limits, :hourly, :infinity) do
        {:error, :exceeds_hourly_limit}
      else
        # Check daily limit
        daily_spent = sum_recent_spending(wallet.history, now, 86_400)

        if daily_spent + amount > Map.get(limits, :daily, :infinity) do
          {:error, :exceeds_daily_limit}
        else
          :ok
        end
      end
    end
  end

  defp sum_recent_spending(history, now, seconds) do
    cutoff = DateTime.add(now, -seconds, :second)

    history
    |> Enum.filter(fn tx ->
      tx.type in [:debit, :transfer_out] and
        DateTime.compare(tx.timestamp, cutoff) == :gt
    end)
    |> Enum.reduce(0, fn tx, acc -> acc + tx.amount end)
  end

  defp filter_history(history, opts) do
    history
    |> filter_by_type(Keyword.get(opts, :type))
    |> filter_by_date(Keyword.get(opts, :from), Keyword.get(opts, :to))
  end

  defp filter_by_type(history, nil), do: history

  defp filter_by_type(history, type) do
    Enum.filter(history, &(&1.type == type))
  end

  defp filter_by_date(history, nil, nil), do: history

  defp filter_by_date(history, from, to) do
    Enum.filter(history, fn tx ->
      after_from = from == nil or DateTime.compare(tx.timestamp, from) != :lt
      before_to = to == nil or DateTime.compare(tx.timestamp, to) != :gt
      after_from and before_to
    end)
  end
end
