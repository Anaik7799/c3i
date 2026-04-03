defmodule Indrajaal.Video.Artery.WebRTCSignaling do
  @moduledoc """
  WebRTC signaling server for ICE candidate exchange via Zenoh control channel.

  Manages SDP offer/answer exchange and ICE candidate gathering for
  peer-to-peer video streaming connections.

  ## STAMP Constraints

  - SC-ARTERY-001: Signaling via encrypted channel only

  ## Architecture

  ```
  SIGNALING FLOW
  ├─ create_offer/2     → Generate SDP offer
  ├─ handle_offer/3     → Process offer, return answer
  ├─ add_ice_candidate/3 → Trickle ICE candidates
  └─ subscribe/2        → Event notifications
  ```

  ## Usage

      {:ok, sig} = WebRTCSignaling.start_link(name: :signaling)

      # Create offer for outgoing stream
      {:ok, offer} = WebRTCSignaling.create_offer(sig, "stream-1")

      # Or handle incoming offer
      {:ok, answer} = WebRTCSignaling.handle_offer(sig, "stream-1", remote_offer)

      # Add ICE candidates as they arrive
      :ok = WebRTCSignaling.add_ice_candidate(sig, "stream-1", candidate)

  """

  use GenServer
  require Logger

  @type stream_id :: String.t()
  @type connection_state :: :new | :connecting | :connected | :disconnected | :failed

  @type sdp :: %{
          type: :offer | :answer,
          sdp: String.t()
        }

  @type ice_candidate :: %{
          candidate: String.t(),
          sdp_mid: String.t(),
          sdp_mline_index: non_neg_integer()
        }

  # ============================================================================
  # CLIENT API
  # ============================================================================

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Creates an SDP offer for a stream.
  """
  @spec create_offer(GenServer.server(), stream_id()) :: {:ok, sdp()}
  def create_offer(server, stream_id) do
    GenServer.call(server, {:create_offer, stream_id})
  end

  @doc """
  Handles an incoming SDP offer and returns an answer.
  """
  @spec handle_offer(GenServer.server(), stream_id(), sdp()) :: {:ok, sdp()}
  def handle_offer(server, stream_id, offer) do
    GenServer.call(server, {:handle_offer, stream_id, offer})
  end

  @doc """
  Adds an ICE candidate for a stream.
  """
  @spec add_ice_candidate(GenServer.server(), stream_id(), ice_candidate()) :: :ok
  def add_ice_candidate(server, stream_id, candidate) do
    GenServer.call(server, {:add_ice_candidate, stream_id, candidate})
  end

  @doc """
  Gets all ICE candidates for a stream.
  """
  @spec get_ice_candidates(GenServer.server(), stream_id()) :: [ice_candidate()]
  def get_ice_candidates(server, stream_id) do
    GenServer.call(server, {:get_ice_candidates, stream_id})
  end

  @doc """
  Subscribes to signaling events for all streams.

  Subscriber receives:
  - `{:ice_candidate_added, stream_id, candidate}`
  - `{:offer_created, stream_id, offer}`
  - `{:answer_created, stream_id, answer}`
  """
  @spec subscribe(GenServer.server(), pid()) :: :ok
  def subscribe(server, pid) do
    GenServer.call(server, {:subscribe, pid})
  end

  @doc """
  Gets the connection state for a stream.
  """
  @spec get_connection_state(GenServer.server(), stream_id()) :: connection_state()
  def get_connection_state(server, stream_id) do
    GenServer.call(server, {:get_connection_state, stream_id})
  end

  @doc """
  Returns signaling metrics.
  """
  @spec metrics(GenServer.server()) :: map()
  def metrics(server) do
    GenServer.call(server, :metrics)
  end

  # ============================================================================
  # GENSERVER CALLBACKS
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %{
      sessions: %{},
      subscribers: [],
      metrics: %{
        total_offers: 0,
        total_answers: 0,
        total_candidates: 0
      },
      started_at: DateTime.utc_now()
    }

    Logger.info("[WebRTCSignaling] Started")

    {:ok, state}
  end

  @impl true
  def handle_call({:create_offer, stream_id}, _from, state) do
    # Generate SDP offer (simplified - real implementation would use WebRTC library)
    offer = %{
      type: :offer,
      sdp: generate_sdp(:offer, stream_id)
    }

    # Create or update session
    session = get_or_create_session(state.sessions, stream_id)
    session = %{session | local_offer: offer, state: :connecting}
    new_sessions = Map.put(state.sessions, stream_id, session)

    # Notify subscribers
    notify_subscribers(state.subscribers, {:offer_created, stream_id, offer})

    # Update metrics
    new_metrics = %{state.metrics | total_offers: state.metrics.total_offers + 1}

    Logger.debug("[WebRTCSignaling] Created offer for stream: #{stream_id}")

    {:reply, {:ok, offer}, %{state | sessions: new_sessions, metrics: new_metrics}}
  end

  @impl true
  def handle_call({:handle_offer, stream_id, offer}, _from, state) do
    # Generate SDP answer
    answer = %{
      type: :answer,
      sdp: generate_sdp(:answer, stream_id, offer.sdp)
    }

    # Create or update session
    session = get_or_create_session(state.sessions, stream_id)
    session = %{session | remote_offer: offer, local_answer: answer, state: :connecting}
    new_sessions = Map.put(state.sessions, stream_id, session)

    # Notify subscribers
    notify_subscribers(state.subscribers, {:answer_created, stream_id, answer})

    # Update metrics
    new_metrics = %{state.metrics | total_answers: state.metrics.total_answers + 1}

    Logger.debug("[WebRTCSignaling] Created answer for stream: #{stream_id}")

    {:reply, {:ok, answer}, %{state | sessions: new_sessions, metrics: new_metrics}}
  end

  @impl true
  def handle_call({:add_ice_candidate, stream_id, candidate}, _from, state) do
    session = get_or_create_session(state.sessions, stream_id)
    session = %{session | ice_candidates: [candidate | session.ice_candidates]}
    new_sessions = Map.put(state.sessions, stream_id, session)

    # Notify subscribers
    notify_subscribers(state.subscribers, {:ice_candidate_added, stream_id, candidate})

    # Update metrics
    new_metrics = %{state.metrics | total_candidates: state.metrics.total_candidates + 1}

    Logger.debug("[WebRTCSignaling] Added ICE candidate for stream: #{stream_id}")

    {:reply, :ok, %{state | sessions: new_sessions, metrics: new_metrics}}
  end

  @impl true
  def handle_call({:get_ice_candidates, stream_id}, _from, state) do
    session = Map.get(state.sessions, stream_id, %{ice_candidates: []})
    {:reply, session.ice_candidates, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: [pid | state.subscribers]}}
  end

  @impl true
  def handle_call({:get_connection_state, stream_id}, _from, state) do
    session = Map.get(state.sessions, stream_id)
    conn_state = if session, do: session.state, else: :new
    {:reply, conn_state, state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    metrics = %{
      active_sessions: map_size(state.sessions),
      total_offers: state.metrics.total_offers,
      total_answers: state.metrics.total_answers,
      total_candidates: state.metrics.total_candidates,
      subscriber_count: length(state.subscribers),
      uptime_ms: DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond)
    }

    {:reply, metrics, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    new_subscribers = Enum.reject(state.subscribers, &(&1 == pid))
    {:noreply, %{state | subscribers: new_subscribers}}
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp get_or_create_session(sessions, stream_id) do
    Map.get(sessions, stream_id, %{
      stream_id: stream_id,
      state: :new,
      local_offer: nil,
      remote_offer: nil,
      local_answer: nil,
      remote_answer: nil,
      ice_candidates: [],
      created_at: DateTime.utc_now()
    })
  end

  defp generate_sdp(:offer, stream_id) do
    # Simplified SDP generation (real implementation would use ex_webrtc or similar)
    """
    v=0
    o=- #{:erlang.phash2(stream_id)} 1 IN IP4 0.0.0.0
    s=Indrajaal Stream #{stream_id}
    t=0 0
    a=group:BUNDLE 0
    m=video 9 UDP/TLS/RTP/SAVPF 96
    c=IN IP4 0.0.0.0
    a=rtcp:9 IN IP4 0.0.0.0
    a=ice-ufrag:#{random_string(8)}
    a=ice-pwd:#{random_string(24)}
    a=fingerprint:sha-256 #{random_fingerprint()}
    a=setup:actpass
    a=mid:0
    a=sendrecv
    a=rtcp-mux
    a=rtpmap:96 H264/90_000
    """
  end

  defp generate_sdp(:answer, stream_id, _remote_sdp) do
    # Simplified SDP answer (would parse remote_sdp in real implementation)
    """
    v=0
    o=- #{:erlang.phash2(stream_id)} 1 IN IP4 0.0.0.0
    s=Indrajaal Stream #{stream_id}
    t=0 0
    a=group:BUNDLE 0
    m=video 9 UDP/TLS/RTP/SAVPF 96
    c=IN IP4 0.0.0.0
    a=rtcp:9 IN IP4 0.0.0.0
    a=ice-ufrag:#{random_string(8)}
    a=ice-pwd:#{random_string(24)}
    a=fingerprint:sha-256 #{random_fingerprint()}
    a=setup:active
    a=mid:0
    a=sendrecv
    a=rtcp-mux
    a=rtpmap:96 H264/90_000
    """
  end

  defp random_string(length) do
    random_bytes = :crypto.strong_rand_bytes(length)
    encoded = Base.encode64(random_bytes)
    binary_part(encoded, 0, length)
  end

  defp random_fingerprint do
    random_bytes = :crypto.strong_rand_bytes(32)
    encoded = Base.encode16(random_bytes, case: :upper)
    graphemes = String.graphemes(encoded)
    chunked = Enum.chunk_every(graphemes, 2)
    joined_chunks = Enum.map(chunked, &Enum.join/1)
    Enum.join(joined_chunks, ":")
  end

  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn pid ->
      send(pid, message)
    end)
  end
end
