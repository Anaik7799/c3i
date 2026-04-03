defmodule Indrajaal.Video.Artery.SplitPlane do
  @moduledoc """
  Split-plane video architecture: control via Tailscale, pixels via WebRTC.

  Separates video streaming into two planes:
  - **Control Plane**: Signaling, ICE candidates, quality control (encrypted via Tailscale)
  - **Pixel Plane**: Actual video frames (WebRTC P2P or SFU)

  ## STAMP Constraints

  - SC-ARTERY-001: Signaling via encrypted channel only
  - SC-ARTERY-002: P2P preferred, SFU fallback

  ## Architecture

  ```
  CONTROL PLANE (Tailscale)     PIXEL PLANE (WebRTC P2P)
  ├─ Signaling                  ├─ Video frames
  ├─ ICE candidates             ├─ SRTP encrypted
  ├─ Quality control            └─ Direct peer-to-peer
  └─ Encrypted channel
  ```

  ## Usage

      conn = SplitPlane.new(stream_id: "camera-1", local_node: node())
             |> SplitPlane.configure_control_plane(%{
                  endpoint: "100.64.0.1:4000",
                  encryption: :tailscale
                })
             |> SplitPlane.configure_pixel_plane(%{
                  protocol: :webrtc,
                  codec: :h264
                })

      {:ok, conn} = SplitPlane.start_connection(conn)

  """

  @type mode :: :p2p | :sfu
  @type state :: :initializing | :connecting | :connected | :failed

  @type control_plane :: %{
          endpoint: String.t() | nil,
          encryption: :tailscale | :none | nil
        }

  @type pixel_plane :: %{
          protocol: :webrtc | :rtmp | nil,
          codec: :h264 | :vp8 | :vp9 | nil
        }

  @type ice_candidate :: %{
          candidate: String.t(),
          sdp_mid: String.t(),
          sdp_mline_index: non_neg_integer()
        }

  @type t :: %__MODULE__{
          stream_id: String.t(),
          local_node: String.t(),
          remote_node: String.t() | nil,
          mode: mode(),
          state: state(),
          control_plane: control_plane(),
          pixel_plane: pixel_plane(),
          ice_candidates: [ice_candidate()],
          created_at: DateTime.t()
        }

  defstruct stream_id: nil,
            local_node: nil,
            remote_node: nil,
            mode: :p2p,
            state: :initializing,
            control_plane: %{endpoint: nil, encryption: nil},
            pixel_plane: %{protocol: nil, codec: nil},
            ice_candidates: [],
            created_at: nil

  # ============================================================================
  # PUBLIC API
  # ============================================================================

  @doc """
  Creates a new split-plane connection.

  ## Options

  - `:stream_id` - Unique stream identifier (required)
  - `:local_node` - Local node identifier (required)
  - `:remote_node` - Remote node identifier (optional)

  """
  @spec new(keyword()) :: t()
  def new(opts) do
    %__MODULE__{
      stream_id: Keyword.fetch!(opts, :stream_id),
      local_node: Keyword.fetch!(opts, :local_node),
      remote_node: Keyword.get(opts, :remote_node),
      mode: :p2p,
      state: :initializing,
      control_plane: %{endpoint: nil, encryption: nil},
      pixel_plane: %{protocol: nil, codec: nil},
      ice_candidates: [],
      created_at: DateTime.utc_now()
    }
  end

  @doc """
  Configures the control plane (signaling channel).
  """
  @spec configure_control_plane(t(), map()) :: t()
  def configure_control_plane(conn, config) do
    control_plane = %{
      endpoint: Map.get(config, :endpoint),
      encryption: Map.get(config, :encryption)
    }

    %{conn | control_plane: control_plane}
  end

  @doc """
  Configures the pixel plane (video data channel).
  """
  @spec configure_pixel_plane(t(), map()) :: t()
  def configure_pixel_plane(conn, config) do
    pixel_plane = %{
      protocol: Map.get(config, :protocol),
      codec: Map.get(config, :codec)
    }

    %{conn | pixel_plane: pixel_plane}
  end

  @doc """
  Starts the connection process.
  """
  @spec start_connection(t()) :: {:ok, t()} | {:error, atom()}
  def start_connection(conn) do
    cond do
      conn.control_plane.endpoint == nil ->
        {:error, :control_plane_not_configured}

      conn.pixel_plane.protocol == nil ->
        {:error, :pixel_plane_not_configured}

      true ->
        {:ok, %{conn | state: :connecting}}
    end
  end

  @doc """
  Adds an ICE candidate for P2P connection.
  """
  @spec add_ice_candidate(t(), ice_candidate()) :: t()
  def add_ice_candidate(conn, candidate) do
    %{conn | ice_candidates: [candidate | conn.ice_candidates]}
  end

  @doc """
  Falls back to SFU mode (for symmetric NAT situations).
  """
  @spec fallback_to_sfu(t()) :: {:ok, t()}
  def fallback_to_sfu(conn) do
    {:ok, %{conn | mode: :sfu}}
  end

  @doc """
  Marks connection as established.
  """
  @spec mark_connected(t()) :: t()
  def mark_connected(conn) do
    %{conn | state: :connected}
  end

  @doc """
  Marks connection as failed.
  """
  @spec mark_failed(t(), String.t()) :: t()
  def mark_failed(conn, _reason) do
    %{conn | state: :failed}
  end

  @doc """
  Returns connection statistics.
  """
  @spec get_stats(t()) :: map()
  def get_stats(conn) do
    %{
      stream_id: conn.stream_id,
      state: conn.state,
      mode: conn.mode,
      local_node: conn.local_node,
      remote_node: conn.remote_node,
      ice_candidate_count: length(conn.ice_candidates),
      is_encrypted: is_encrypted?(conn),
      created_at: conn.created_at
    }
  end

  @doc """
  Checks if the control plane is encrypted.
  """
  @spec is_encrypted?(t()) :: boolean()
  def is_encrypted?(conn) do
    conn.control_plane.encryption == :tailscale
  end

  @doc """
  Checks if connection is using P2P mode.
  """
  @spec is_p2p?(t()) :: boolean()
  def is_p2p?(conn) do
    conn.mode == :p2p
  end
end
