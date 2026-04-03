defmodule Indrajaal.Substrate.L3.ResourceLedger do
  @moduledoc """
  ## Design Intent
  L3 substrate resource ledger — pure functional resource accounting.

  Biomorphic metaphor: the liver's role as metabolic accountant — tracking credits
  (resource production) and debits (consumption) across accounts with double-entry
  bookkeeping semantics. Each transaction balances total supply against demand.

  Algorithm:
  1. Accounts are identified by string keys with a current balance and a credit limit.
  2. Debit checks balance before proceeding; credit increases balance up to the limit.
  3. Transfer atomically debits one account and credits another.
  4. All transactions are recorded in an append-only ledger with sequence numbers.
  5. Snapshot computes net position across all accounts.

  ## STAMP Constraints
  - SC-S3-001: Cybernetic VSM S3 control — ENFORCED
  - SC-RCPSP-001: Resource-constrained scheduling — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type account :: %{
          balance: float(),
          credit_limit: float(),
          debit_total: float(),
          credit_total: float()
        }

  @type txn :: %{
          seq: pos_integer(),
          type: :credit | :debit | :transfer,
          account: String.t(),
          counterpart: String.t() | nil,
          amount: float(),
          timestamp: DateTime.t()
        }

  @type t :: %__MODULE__{
          accounts: %{String.t() => account()},
          ledger: [txn()],
          seq: non_neg_integer()
        }

  defstruct accounts: %{},
            ledger: [],
            seq: 0

  @doc """
  Create a new ResourceLedger.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(_opts \\ []) do
    {:ok, %__MODULE__{}}
  end

  @doc """
  Open a new account with an initial balance and credit limit.
  """
  @spec open_account(t(), String.t(), float(), float()) ::
          {:ok, t()} | {:error, String.t()}
  def open_account(state, id, initial_balance \\ 0.0, credit_limit \\ 1.0e9)

  def open_account(%__MODULE__{} = state, id, initial_balance, credit_limit)
      when is_binary(id) and is_number(initial_balance) and is_number(credit_limit) do
    cond do
      Map.has_key?(state.accounts, id) ->
        {:error, "account #{id} already exists"}

      initial_balance < 0.0 ->
        {:error, "initial_balance must be >= 0"}

      credit_limit < initial_balance ->
        {:error, "credit_limit must be >= initial_balance"}

      true ->
        account = %{
          balance: initial_balance * 1.0,
          credit_limit: credit_limit * 1.0,
          debit_total: 0.0,
          credit_total: initial_balance * 1.0
        }

        {:ok, %__MODULE__{state | accounts: Map.put(state.accounts, id, account)}}
    end
  end

  def open_account(%__MODULE__{}, _id, _initial_balance, _credit_limit) do
    {:error, "id must be a binary, amounts must be numbers"}
  end

  @doc """
  Credit an account by `amount`. Balance may not exceed credit_limit.
  """
  @spec credit(t(), String.t(), float()) :: {:ok, t()} | {:error, atom()}
  def credit(%__MODULE__{} = state, account_id, amount)
      when is_binary(account_id) and is_number(amount) and amount > 0.0 do
    case Map.fetch(state.accounts, account_id) do
      :error ->
        {:error, :account_not_found}

      {:ok, account} ->
        new_balance = account.balance + amount

        if new_balance > account.credit_limit do
          {:error, :credit_limit_exceeded}
        else
          updated = %{account | balance: new_balance, credit_total: account.credit_total + amount}
          {new_seq, txn} = build_txn(state.seq, :credit, account_id, nil, amount)

          {:ok,
           %__MODULE__{
             state
             | accounts: Map.put(state.accounts, account_id, updated),
               ledger: [txn | state.ledger],
               seq: new_seq
           }}
        end
    end
  end

  def credit(%__MODULE__{}, _id, _amount), do: {:error, :invalid_arguments}

  @doc """
  Debit an account by `amount`. Balance may not go below 0.
  """
  @spec debit(t(), String.t(), float()) :: {:ok, t()} | {:error, atom()}
  def debit(%__MODULE__{} = state, account_id, amount)
      when is_binary(account_id) and is_number(amount) and amount > 0.0 do
    case Map.fetch(state.accounts, account_id) do
      :error ->
        {:error, :account_not_found}

      {:ok, account} ->
        if account.balance < amount do
          {:error, :insufficient_balance}
        else
          updated = %{
            account
            | balance: account.balance - amount,
              debit_total: account.debit_total + amount
          }

          {new_seq, txn} = build_txn(state.seq, :debit, account_id, nil, amount)

          {:ok,
           %__MODULE__{
             state
             | accounts: Map.put(state.accounts, account_id, updated),
               ledger: [txn | state.ledger],
               seq: new_seq
           }}
        end
    end
  end

  def debit(%__MODULE__{}, _id, _amount), do: {:error, :invalid_arguments}

  @doc """
  Transfer `amount` from `from_id` to `to_id`.
  """
  @spec transfer(t(), String.t(), String.t(), float()) :: {:ok, t()} | {:error, atom()}
  def transfer(%__MODULE__{} = state, from_id, to_id, amount)
      when is_binary(from_id) and is_binary(to_id) and is_number(amount) and amount > 0.0 do
    with {:ok, state2} <- debit(state, from_id, amount),
         {:ok, %__MODULE__{} = state3} <- credit(state2, to_id, amount) do
      {new_seq, txn} = build_txn(state3.seq, :transfer, from_id, to_id, amount)

      {:ok, %{state3 | ledger: [txn | state3.ledger], seq: new_seq}}
    end
  end

  def transfer(%__MODULE__{}, _from, _to, _amount), do: {:error, :invalid_arguments}

  @doc """
  Returns a summary map of the ledger state.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    total_balance = state.accounts |> Map.values() |> Enum.reduce(0.0, &(&1.balance + &2))

    %{
      account_count: map_size(state.accounts),
      transaction_count: length(state.ledger),
      seq: state.seq,
      total_balance: total_balance,
      accounts:
        Map.new(state.accounts, fn {id, acc} ->
          {id, %{balance: acc.balance, credit_limit: acc.credit_limit}}
        end)
    }
  end

  # ── Private ────────────────────────────────────────────────────────────────

  @spec build_txn(non_neg_integer(), atom(), String.t(), String.t() | nil, float()) ::
          {pos_integer(), txn()}
  defp build_txn(seq, type, account, counterpart, amount) do
    new_seq = seq + 1

    txn = %{
      seq: new_seq,
      type: type,
      account: account,
      counterpart: counterpart,
      amount: amount,
      timestamp: DateTime.utc_now()
    }

    {new_seq, txn}
  end
end
