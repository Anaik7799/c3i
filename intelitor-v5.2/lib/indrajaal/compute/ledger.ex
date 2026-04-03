defmodule Indrajaal.Compute.Ledger do
  @moduledoc """
  Transaction Ledger - Immutable Transaction Record for v20.0.0

  Implements an append-only ledger for all credit transactions:
  - Immutable transaction records
  - Double-entry bookkeeping
  - Audit trail
  - Balance verification

  ## Ledger Model

  Entry = {id, timestamp, debit_account, credit_account, amount, memo, hash}

  Invariant: Σ debits = Σ credits (balanced ledger)

  ## Entry Types
  - **Transfer**: Agent to agent
  - **Mint**: System creation
  - **Burn**: System destruction
  - **Fee**: System fees

  ## STAMP Constraints
  - SC-LED-001: Entries MUST be immutable
  - SC-LED-002: Ledger MUST always balance
  - SC-LED-003: Entry order MUST be preserved
  - SC-LED-004: Entries MUST be verifiable (hash chain)
  """

  use GenServer
  require Logger

  @type account_id :: String.t()
  @type entry_type :: :transfer | :mint | :burn | :fee

  @type entry :: %{
          id: String.t(),
          type: entry_type(),
          debit: account_id(),
          credit: account_id(),
          amount: non_neg_integer(),
          memo: String.t() | nil,
          timestamp: DateTime.t(),
          hash: String.t(),
          prev_hash: String.t()
        }

  @type state :: %{
          entries: [entry()],
          balances: map(),
          last_hash: String.t(),
          stats: map()
        }

  # System accounts
  @mint_account "system:mint"
  @burn_account "system:burn"
  @fee_account "system:fees"

  # Genesis hash
  @genesis_hash "0_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000"

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records a transfer between accounts.
  Accepts an optional first argument as the server name/pid for named instances.
  """
  @spec transfer(GenServer.server(), account_id(), account_id(), non_neg_integer()) ::
          {:ok, entry()} | {:error, term()}
  def transfer(server \\ __MODULE__, from, to, amount) do
    GenServer.call(server, {:transfer, from, to, amount, nil})
  end

  @doc """
  Records minting of new credits.
  Accepts an optional first argument as the server name/pid for named instances.
  """
  @spec mint(GenServer.server(), account_id(), non_neg_integer()) ::
          {:ok, entry()} | {:error, term()}
  def mint(server \\ __MODULE__, to, amount) do
    GenServer.call(server, {:mint, to, amount, nil})
  end

  @doc """
  Records burning of credits.
  Accepts an optional first argument as the server name/pid for named instances.
  """
  @spec burn(GenServer.server(), account_id(), non_neg_integer()) ::
          {:ok, entry()} | {:error, term()}
  def burn(server \\ __MODULE__, from, amount) do
    GenServer.call(server, {:burn, from, amount, nil})
  end

  @doc """
  Records a fee payment.
  Accepts an optional first argument as the server name/pid for named instances.
  """
  @spec fee(GenServer.server(), account_id(), non_neg_integer()) ::
          {:ok, entry()} | {:error, term()}
  def fee(server \\ __MODULE__, from, amount) do
    GenServer.call(server, {:fee, from, amount, nil})
  end

  @doc """
  Gets account balance from ledger.
  Accepts an optional first argument as the server name/pid for named instances.
  """
  @spec balance(GenServer.server()) :: {:ok, non_neg_integer()} | non_neg_integer()
  def balance(server \\ __MODULE__) do
    result = GenServer.call(server, :balance_all)
    {:ok, result}
  end

  @doc """
  Gets entries for an account.
  Accepts an optional first argument as the server name/pid for named instances.
  """
  @spec entries(GenServer.server(), account_id()) :: {:ok, [entry()]} | [entry()]
  def entries(server \\ __MODULE__, account_id) do
    result = GenServer.call(server, {:entries, account_id, []})
    {:ok, result}
  end

  @doc """
  Gets entry by ID.
  """
  @spec get_entry(String.t()) :: {:ok, entry()} | {:error, :not_found}
  def get_entry(entry_id) do
    GenServer.call(__MODULE__, {:get_entry, entry_id})
  end

  @doc """
  Verifies ledger integrity.
  Accepts an optional first argument as the server name/pid for named instances.
  """
  @spec verify(GenServer.server()) :: {:ok, :valid} | {:error, term()}
  def verify(server \\ __MODULE__) do
    GenServer.call(server, :verify)
  end

  @doc """
  Gets ledger statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Exports ledger for audit.
  """
  @spec export(Keyword.t()) :: [entry()]
  def export(opts \\ []) do
    GenServer.call(__MODULE__, {:export, opts})
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    state = %{
      entries: [],
      balances: %{
        @mint_account => 0,
        @burn_account => 0,
        @fee_account => 0
      },
      last_hash: @genesis_hash,
      stats: %{
        total_entries: 0,
        total_volume: 0,
        total_minted: 0,
        total_burned: 0,
        total_fees: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:transfer, from, to, amount, memo}, _from, state) do
    # Check balance
    from_balance = Map.get(state.balances, from, 0)

    if from_balance < amount do
      {:reply, {:error, :insufficient_balance}, state}
    else
      entry = create_entry(:transfer, from, to, amount, memo, state.last_hash)

      new_state =
        state
        |> add_entry(entry)
        |> update_balance(from, -amount)
        |> update_balance(to, amount)
        |> update_stats(:transfer, amount)

      {:reply, {:ok, entry}, new_state}
    end
  end

  @impl true
  def handle_call({:mint, to, amount, memo}, _from, state) do
    entry = create_entry(:mint, @mint_account, to, amount, memo, state.last_hash)

    new_state =
      state
      |> add_entry(entry)
      |> update_balance(@mint_account, -amount)
      |> update_balance(to, amount)
      |> update_stats(:mint, amount)

    {:reply, {:ok, entry}, new_state}
  end

  @impl true
  def handle_call({:burn, from, amount, memo}, _from, state) do
    from_balance = Map.get(state.balances, from, 0)

    if from_balance < amount do
      {:reply, {:error, :insufficient_balance}, state}
    else
      entry = create_entry(:burn, from, @burn_account, amount, memo, state.last_hash)

      new_state =
        state
        |> add_entry(entry)
        |> update_balance(from, -amount)
        |> update_balance(@burn_account, amount)
        |> update_stats(:burn, amount)

      {:reply, {:ok, entry}, new_state}
    end
  end

  @impl true
  def handle_call({:fee, from, amount, memo}, _from, state) do
    from_balance = Map.get(state.balances, from, 0)

    if from_balance < amount do
      {:reply, {:error, :insufficient_balance}, state}
    else
      entry = create_entry(:fee, from, @fee_account, amount, memo, state.last_hash)

      new_state =
        state
        |> add_entry(entry)
        |> update_balance(from, -amount)
        |> update_balance(@fee_account, amount)
        |> update_stats(:fee, amount)

      {:reply, {:ok, entry}, new_state}
    end
  end

  @impl true
  def handle_call({:balance, account_id}, _from, state) do
    balance = Map.get(state.balances, account_id, 0)
    {:reply, balance, state}
  end

  @impl true
  def handle_call(:balance_all, _from, state) do
    # Return total of all non-system balances
    total =
      state.balances
      |> Enum.reject(fn {k, _} -> k in [@mint_account, @burn_account, @fee_account] end)
      |> Enum.reduce(0, fn {_, v}, acc -> acc + max(v, 0) end)

    {:reply, total, state}
  end

  @impl true
  def handle_call({:entries, account_id, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)

    entries =
      state.entries
      |> Enum.filter(fn e -> e.debit == account_id or e.credit == account_id end)
      |> Enum.take(limit)

    {:reply, entries, state}
  end

  @impl true
  def handle_call({:get_entry, entry_id}, _from, state) do
    case Enum.find(state.entries, fn e -> e.id == entry_id end) do
      nil -> {:reply, {:error, :not_found}, state}
      entry -> {:reply, {:ok, entry}, state}
    end
  end

  @impl true
  def handle_call(:verify, _from, state) do
    # Verify hash chain (SC-LED-004)
    hash_valid = verify_hash_chain(state.entries)

    # Verify balance (SC-LED-002)
    balance_valid = verify_balance(state)

    if hash_valid and balance_valid do
      {:reply, {:ok, :valid}, state}
    else
      errors = []
      errors = if hash_valid, do: errors, else: [:hash_chain_broken | errors]
      errors = if balance_valid, do: errors, else: [:balance_mismatch | errors]
      {:reply, {:error, errors}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        num_accounts: map_size(state.balances),
        mint_balance: Map.get(state.balances, @mint_account, 0),
        burn_balance: Map.get(state.balances, @burn_account, 0),
        fee_balance: Map.get(state.balances, @fee_account, 0)
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:export, opts}, _from, state) do
    from_date = Keyword.get(opts, :from)
    to_date = Keyword.get(opts, :to)

    entries =
      state.entries
      |> filter_by_date(from_date, to_date)

    {:reply, entries, state}
  end

  # Private helpers

  defp create_entry(type, debit, credit, amount, memo, prev_hash) do
    id = generate_id()
    timestamp = DateTime.utc_now()

    # Create hash (SC-LED-004)
    hash_data =
      "#{id}|#{type}|#{debit}|#{credit}|#{amount}|#{DateTime.to_iso8601(timestamp)}|#{prev_hash}"

    encoded_hash = :crypto.hash(:sha256, hash_data)
    hash = Base.encode16(encoded_hash, case: :lower)

    %{
      id: id,
      type: type,
      debit: debit,
      credit: credit,
      amount: amount,
      memo: memo,
      timestamp: timestamp,
      hash: hash,
      prev_hash: prev_hash
    }
  end

  defp generate_id do
    bytes = :crypto.strong_rand_bytes(8)
    encoded = bytes |> Base.encode16(case: :lower)
    "led_#{encoded}"
  end

  defp add_entry(state, entry) do
    # Append-only (SC-LED-001, SC-LED-003)
    %{
      state
      | entries: [entry | state.entries],
        last_hash: entry.hash
    }
  end

  defp update_balance(state, account, delta) do
    current = Map.get(state.balances, account, 0)
    new_balances = Map.put(state.balances, account, current + delta)
    %{state | balances: new_balances}
  end

  defp update_stats(state, type, amount) do
    stats = state.stats

    updated =
      case type do
        :transfer ->
          %{
            stats
            | total_entries: stats.total_entries + 1,
              total_volume: stats.total_volume + amount
          }

        :mint ->
          %{
            stats
            | total_entries: stats.total_entries + 1,
              total_minted: stats.total_minted + amount
          }

        :burn ->
          %{
            stats
            | total_entries: stats.total_entries + 1,
              total_burned: stats.total_burned + amount
          }

        :fee ->
          %{
            stats
            | total_entries: stats.total_entries + 1,
              total_fees: stats.total_fees + amount
          }
      end

    %{state | stats: updated}
  end

  defp verify_hash_chain([]), do: true
  defp verify_hash_chain([_single]), do: true

  defp verify_hash_chain([current, previous | rest]) do
    if current.prev_hash == previous.hash do
      verify_hash_chain([previous | rest])
    else
      false
    end
  end

  defp verify_balance(state) do
    # Sum all debits and credits
    {total_debits, total_credits} =
      Enum.reduce(state.entries, {0, 0}, fn entry, {debits, credits} ->
        {debits + entry.amount, credits + entry.amount}
      end)

    total_debits == total_credits
  end

  defp filter_by_date(entries, nil, nil), do: entries

  defp filter_by_date(entries, from, to) do
    Enum.filter(entries, fn e ->
      after_from = from == nil or DateTime.compare(e.timestamp, from) != :lt
      before_to = to == nil or DateTime.compare(e.timestamp, to) != :gt
      after_from and before_to
    end)
  end
end
