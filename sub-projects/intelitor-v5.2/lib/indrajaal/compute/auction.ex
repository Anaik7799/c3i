defmodule Indrajaal.Compute.Auction do
  @moduledoc """
  Vickrey Auction - Second-Price Sealed-Bid Auction for v20.0.0

  Implements Vickrey (second-price) auctions for resource allocation:
  - Sealed-bid auction mechanism
  - Winner pays second-highest bid
  - Truthful bidding incentive
  - Multi-unit auction support

  ## Auction Theory

  Vickrey Auction Properties:
  - Truthful: Bidding true valuation is dominant strategy
  - Efficient: Resources go to highest-value bidders
  - Revenue: Seller receives second-highest value

  Payment: p_i = b_(i+1) (winner pays second-highest bid)

  ## Auction Types
  - **Single-item**: One resource, one winner
  - **Multi-unit**: Multiple identical resources
  - **Combinatorial**: Bundles of resources

  ## STAMP Constraints
  - SC-AUC-001: All bids MUST be sealed until reveal
  - SC-AUC-002: Winner determination < 10ms
  - SC-AUC-003: Payment = second highest bid
  - SC-AUC-004: No bid manipulation allowed
  """

  use GenServer
  require Logger

  @type agent_id :: String.t()
  @type resource_id :: String.t()
  @type bid_amount :: non_neg_integer()

  @type bid :: %{
          bidder: agent_id(),
          amount: bid_amount(),
          timestamp: DateTime.t(),
          sealed: boolean()
        }

  @type auction :: %{
          id: String.t(),
          resource: resource_id(),
          status: :open | :sealed | :resolved | :cancelled,
          bids: [bid()],
          winner: agent_id() | nil,
          payment: bid_amount() | nil,
          reserve_price: bid_amount(),
          deadline: DateTime.t(),
          created_at: DateTime.t()
        }

  @type state :: %{
          auctions: map(),
          completed: [auction()]
        }

  # Maximum completed auctions to retain
  @max_completed 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a new auction for a resource.
  """
  @spec create(resource_id(), Keyword.t()) :: {:ok, auction()} | {:error, term()}
  def create(resource_id, opts \\ []) do
    GenServer.call(__MODULE__, {:create, resource_id, opts})
  end

  @doc """
  Submits a sealed bid to an auction.
  """
  @spec bid(String.t(), agent_id(), bid_amount()) :: {:ok, :bid_accepted} | {:error, term()}
  def bid(auction_id, bidder, amount) do
    GenServer.call(__MODULE__, {:bid, auction_id, bidder, amount})
  end

  @doc """
  Resolves the auction and determines winner.
  """
  @spec resolve(String.t()) :: {:ok, map()} | {:error, term()}
  def resolve(auction_id) do
    GenServer.call(__MODULE__, {:resolve, auction_id})
  end

  @doc """
  Gets auction info.
  """
  @spec get(String.t()) :: {:ok, auction()} | {:error, :not_found}
  def get(auction_id) do
    GenServer.call(__MODULE__, {:get, auction_id})
  end

  @doc """
  Lists active auctions.
  """
  @spec list_active() :: [auction()]
  def list_active do
    GenServer.call(__MODULE__, :list_active)
  end

  @doc """
  Runs a quick single-item Vickrey auction.
  """
  @spec run_vickrey(resource_id(), [{agent_id(), bid_amount()}]) ::
          {:winner, agent_id(), bid_amount()} | {:no_bids}
  def run_vickrey(_resource, []), do: {:no_bids}
  def run_vickrey(_resource, [{winner, _amount}]), do: {:winner, winner, 0}

  def run_vickrey(_resource, bids) do
    # Sort by bid amount descending
    sorted = Enum.sort_by(bids, fn {_, amount} -> amount end, :desc)
    [{winner, _highest}, {_, second_highest} | _] = sorted
    {:winner, winner, second_highest}
  end

  @doc """
  Runs a multi-unit Vickrey auction.
  """
  @spec run_multi_unit(resource_id(), non_neg_integer(), [{agent_id(), bid_amount()}]) ::
          [{agent_id(), bid_amount()}]
  def run_multi_unit(_resource, units, bids) when length(bids) <= units do
    # All bidders win, pay 0 (no competition)
    Enum.map(bids, fn {bidder, _} -> {bidder, 0} end)
  end

  def run_multi_unit(_resource, units, bids) do
    # Sort by bid amount descending
    sorted = Enum.sort_by(bids, fn {_, amount} -> amount end, :desc)

    # First (units) bidders win
    winners = Enum.take(sorted, units)

    # All winners pay the (units + 1)th highest bid
    {_, clearing_price} = Enum.at(sorted, units)

    Enum.map(winners, fn {bidder, _} -> {bidder, clearing_price} end)
  end

  @doc """
  Cancels an auction.
  """
  @spec cancel(String.t()) :: :ok | {:error, term()}
  def cancel(auction_id) do
    GenServer.call(__MODULE__, {:cancel, auction_id})
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup_expired, 60_000)
    {:ok, %{auctions: %{}, completed: []}}
  end

  @impl true
  def handle_call({:create, resource_id, opts}, _from, state) do
    auction_id = generate_auction_id()

    auction = %{
      id: auction_id,
      resource: resource_id,
      status: :open,
      bids: [],
      winner: nil,
      payment: nil,
      reserve_price: Keyword.get(opts, :reserve_price, 0),
      deadline: Keyword.get(opts, :deadline, default_deadline()),
      created_at: DateTime.utc_now()
    }

    new_auctions = Map.put(state.auctions, auction_id, auction)
    Logger.info("Created auction #{auction_id} for resource #{resource_id}")

    {:reply, {:ok, auction}, %{state | auctions: new_auctions}}
  end

  @impl true
  def handle_call({:bid, auction_id, bidder, amount}, _from, state) do
    case Map.get(state.auctions, auction_id) do
      nil ->
        {:reply, {:error, :auction_not_found}, state}

      %{status: status} when status != :open ->
        {:reply, {:error, :auction_not_open}, state}

      auction ->
        handle_bid_submission(auction_id, auction, bidder, amount, state)
    end
  end

  @impl true
  def handle_call({:resolve, auction_id}, _from, state) do
    case Map.get(state.auctions, auction_id) do
      nil ->
        {:reply, {:error, :auction_not_found}, state}

      %{status: :resolved} = auction ->
        {:reply, {:ok, %{winner: auction.winner, payment: auction.payment}}, state}

      auction ->
        result = determine_winner(auction)

        case result do
          {:winner, winner, payment} ->
            resolved = %{
              auction
              | status: :resolved,
                winner: winner,
                payment: payment
            }

            new_auctions = Map.delete(state.auctions, auction_id)
            new_completed = [resolved | Enum.take(state.completed, @max_completed - 1)]

            Logger.info("Auction #{auction_id} resolved: winner=#{winner}, payment=#{payment}")

            emit_telemetry(:resolved, %{
              auction_id: auction_id,
              winner: winner,
              payment: payment,
              num_bids: length(auction.bids)
            })

            {:reply, {:ok, %{winner: winner, payment: payment}},
             %{state | auctions: new_auctions, completed: new_completed}}

          {:no_bids} ->
            cancelled = %{auction | status: :cancelled}
            new_auctions = Map.delete(state.auctions, auction_id)
            new_completed = [cancelled | Enum.take(state.completed, @max_completed - 1)]

            {:reply, {:ok, :no_bids}, %{state | auctions: new_auctions, completed: new_completed}}

          {:below_reserve} ->
            cancelled = %{auction | status: :cancelled}
            new_auctions = Map.delete(state.auctions, auction_id)
            new_completed = [cancelled | Enum.take(state.completed, @max_completed - 1)]

            {:reply, {:ok, :below_reserve},
             %{state | auctions: new_auctions, completed: new_completed}}
        end
    end
  end

  @impl true
  def handle_call({:get, auction_id}, _from, state) do
    case Map.get(state.auctions, auction_id) do
      nil ->
        # Check completed
        case Enum.find(state.completed, fn a -> a.id == auction_id end) do
          nil -> {:reply, {:error, :not_found}, state}
          auction -> {:reply, {:ok, auction}, state}
        end

      auction ->
        # Mask bid amounts for sealed auction (SC-AUC-001)
        masked =
          if auction.status == :open do
            masked_bids = Enum.map(auction.bids, fn b -> %{b | amount: :sealed} end)
            %{auction | bids: masked_bids}
          else
            auction
          end

        {:reply, {:ok, masked}, state}
    end
  end

  @impl true
  def handle_call(:list_active, _from, state) do
    active =
      state.auctions
      |> Map.values()
      |> Enum.filter(&(&1.status == :open))

    {:reply, active, state}
  end

  @impl true
  def handle_call({:cancel, auction_id}, _from, state) do
    case Map.get(state.auctions, auction_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      auction ->
        cancelled = %{auction | status: :cancelled}
        new_auctions = Map.delete(state.auctions, auction_id)
        new_completed = [cancelled | state.completed]

        {:reply, :ok, %{state | auctions: new_auctions, completed: new_completed}}
    end
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    now = DateTime.utc_now()

    # Auto-resolve expired auctions
    expired =
      state.auctions
      |> Map.values()
      |> Enum.filter(fn a ->
        a.status == :open and DateTime.compare(now, a.deadline) == :gt
      end)

    Enum.each(expired, fn a ->
      GenServer.cast(self(), {:auto_resolve, a.id})
    end)

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_expired, 60_000)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:auto_resolve, auction_id}, state) do
    # Trigger resolution
    case Map.get(state.auctions, auction_id) do
      nil ->
        {:noreply, state}

      auction ->
        result = determine_winner(auction)

        case result do
          {:winner, winner, payment} ->
            resolved = %{auction | status: :resolved, winner: winner, payment: payment}
            new_auctions = Map.delete(state.auctions, auction_id)
            new_completed = [resolved | Enum.take(state.completed, @max_completed - 1)]

            {:noreply, %{state | auctions: new_auctions, completed: new_completed}}

          _ ->
            cancelled = %{auction | status: :cancelled}
            new_auctions = Map.delete(state.auctions, auction_id)
            new_completed = [cancelled | Enum.take(state.completed, @max_completed - 1)]

            {:noreply, %{state | auctions: new_auctions, completed: new_completed}}
        end
    end
  end

  # Private helpers

  defp handle_bid_submission(auction_id, auction, bidder, amount, state) do
    with :ok <- check_auction_deadline(auction),
         :ok <- check_duplicate_bid(auction, bidder) do
      bid = %{
        bidder: bidder,
        amount: amount,
        timestamp: DateTime.utc_now(),
        sealed: true
      }

      new_auction = %{auction | bids: [bid | auction.bids]}
      new_auctions = Map.put(state.auctions, auction_id, new_auction)

      Logger.debug("Bid accepted: #{bidder} bid #{amount} on #{auction_id}")
      {:reply, {:ok, :bid_accepted}, %{state | auctions: new_auctions}}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp check_auction_deadline(auction) do
    if DateTime.compare(DateTime.utc_now(), auction.deadline) == :gt do
      {:error, :auction_expired}
    else
      :ok
    end
  end

  defp check_duplicate_bid(auction, bidder) do
    if Enum.any?(auction.bids, fn b -> b.bidder == bidder end) do
      {:error, :already_bid}
    else
      :ok
    end
  end

  defp generate_auction_id do
    bytes = :crypto.strong_rand_bytes(8)
    encoded = bytes |> Base.encode16(case: :lower)
    "auc_#{encoded}"
  end

  defp default_deadline do
    DateTime.add(DateTime.utc_now(), 300, :second)
  end

  defp determine_winner(auction) do
    bids = auction.bids

    if Enum.empty?(bids) do
      {:no_bids}
    else
      sorted = Enum.sort_by(bids, & &1.amount, :desc)
      highest = hd(sorted)

      # Check reserve price
      if highest.amount < auction.reserve_price do
        {:below_reserve}
      else
        # Second-price payment (SC-AUC-003)
        payment =
          case sorted do
            [_single] -> auction.reserve_price
            [_, second | _] -> max(second.amount, auction.reserve_price)
          end

        {:winner, highest.bidder, payment}
      end
    end
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:indrajaal, :compute, :auction, event],
      %{count: 1},
      metadata
    )
  end
end
