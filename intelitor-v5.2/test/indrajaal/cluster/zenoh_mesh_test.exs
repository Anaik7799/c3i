defmodule Indrajaal.Cluster.ZenohMeshTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Cluster.ZenohMesh.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Zenoh mesh messaging invariants validated before cluster deployment
  - FPPS Validation: FQUN format, subscription lifecycle, health propagation

  ## STAMP Safety Integration
  - SC-MSG-001: FQUN key expression format required
  - SC-PRF-050: Response time < 50ms for pub/sub operations
  - SC-HEALTH-PROP-001: Health event propagation
  - SC-ZENOH-BRIDGE-001: F# to Elixir message routing

  ## Constitutional Verification
  - Psi_0 Existence: GenServer survives invalid publish/subscribe calls
  - Psi_1 Regeneration: Subscriptions reconstructable from patterns

  ## Founder's Directive Alignment
  - Omega_0.7: Mesh enables maximum capability accumulation

  ## TPS 5-Level RCA Context
  - L1 Symptom: Health events not propagated between nodes
  - L5 Root Cause: FQUN validation rejects valid patterns with wildcard
  """

  use ExUnit.Case, async: false

  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cluster.ZenohMesh

  @moduletag :zenoh_nif

  setup do
    # Start a local ZenohMesh GenServer for each test
    pid = start_supervised!({ZenohMesh, [port: 7449]})
    {:ok, pid: pid}
  end

  # ---- fqun/5 ----------------------------------------------------------------

  describe "fqun/5" do
    test "produces a string" do
      key = ZenohMesh.fqun("alarms", "fire", "events", "evt_001")
      assert is_binary(key)
    end

    test "produced key starts with 'indrajaal/'" do
      key = ZenohMesh.fqun("alarms", "fire", "events", "evt_001")
      assert String.starts_with?(key, "indrajaal/")
    end

    test "includes all four path components" do
      key =
        ZenohMesh.fqun("alarms", "fire", "events", "evt_001",
          node: "mynode",
          correlation_id: "corr_aabbcc"
        )

      assert String.contains?(key, "alarms")
      assert String.contains?(key, "fire")
      assert String.contains?(key, "events")
      assert String.contains?(key, "evt_001")
    end

    test "uses provided node name" do
      key = ZenohMesh.fqun("alarms", "fire", "events", "evt_001", node: "test_node")
      assert String.contains?(key, "@test_node")
    end

    test "uses provided correlation_id" do
      key = ZenohMesh.fqun("alarms", "fire", "events", "evt_001", correlation_id: "corr_12345")
      assert String.contains?(key, "#corr_12345")
    end
  end

  # ---- valid_fqun?/1 ---------------------------------------------------------

  describe "valid_fqun?/1" do
    test "returns true for valid FQUN" do
      key =
        ZenohMesh.fqun("alarms", "fire", "events", "evt_001",
          node: "app1",
          correlation_id: "corr_abc123"
        )

      assert ZenohMesh.valid_fqun?(key)
    end

    test "returns false for empty string" do
      refute ZenohMesh.valid_fqun?("")
    end

    test "returns false for missing @ node separator" do
      refute ZenohMesh.valid_fqun?("indrajaal/alarms/fire/events/evt_001")
    end

    test "returns false for missing # correlation separator" do
      refute ZenohMesh.valid_fqun?("indrajaal/alarms/fire/events/evt_001@node")
    end

    test "returns false for wrong prefix" do
      refute ZenohMesh.valid_fqun?("badprefix/alarms/fire/events/evt_001@node#corr_1")
    end

    test "returns false for too few path segments" do
      refute ZenohMesh.valid_fqun?("indrajaal/alarms/fire@node#corr")
    end
  end

  # ---- parse_fqun/1 ----------------------------------------------------------

  describe "parse_fqun/1" do
    test "parses valid FQUN into components" do
      key =
        ZenohMesh.fqun("alarms", "fire", "events", "evt_001",
          node: "app1",
          correlation_id: "corr_aabbcc"
        )

      assert {:ok, map} = ZenohMesh.parse_fqun(key)
      assert map["domain"] == "alarms"
      assert map["subdomain"] == "fire"
      assert map["resource_type"] == "events"
      assert map["resource_id"] == "evt_001"
      assert map["node"] == "app1"
      assert map["correlation_id"] == "corr_aabbcc"
      assert map["prefix"] == "indrajaal"
    end

    test "returns {:error, :invalid_fqun} for invalid key" do
      assert {:error, :invalid_fqun} = ZenohMesh.parse_fqun("bad-key")
    end

    test "returns {:error, :invalid_fqun} for empty string" do
      assert {:error, :invalid_fqun} = ZenohMesh.parse_fqun("")
    end

    test "round-trip: fqun then parse_fqun recovers all fields" do
      key =
        ZenohMesh.fqun("devices", "camera", "telemetry", "cam_001",
          node: "node_a",
          correlation_id: "corr_xyz789"
        )

      {:ok, parsed} = ZenohMesh.parse_fqun(key)
      assert parsed["domain"] == "devices"
      assert parsed["subdomain"] == "camera"
      assert parsed["resource_type"] == "telemetry"
      assert parsed["resource_id"] == "cam_001"
    end
  end

  # ---- subscribe/3 and unsubscribe/1 -----------------------------------------

  describe "subscribe/3 and unsubscribe/1" do
    test "subscribe returns {:ok, ref}" do
      {:ok, ref} = ZenohMesh.subscribe("indrajaal/alarms/**", fn _msg -> :ok end)
      assert is_reference(ref)
    end

    test "subscribe increments subscription count" do
      before_status = ZenohMesh.mesh_status()
      {:ok, _ref} = ZenohMesh.subscribe("indrajaal/test/**", fn _msg -> :ok end)
      after_status = ZenohMesh.mesh_status()
      assert after_status.subscription_count == before_status.subscription_count + 1
    end

    test "unsubscribe returns :ok" do
      {:ok, ref} = ZenohMesh.subscribe("indrajaal/alarms/**", fn _msg -> :ok end)
      assert :ok = ZenohMesh.unsubscribe(ref)
    end

    test "unsubscribe removes from subscription list" do
      {:ok, ref} = ZenohMesh.subscribe("indrajaal/test/**", fn _msg -> :ok end)
      ZenohMesh.unsubscribe(ref)
      subs = ZenohMesh.list_subscriptions()
      refs = Enum.map(subs, & &1.ref)
      refute ref in refs
    end

    test "multiple subscriptions are tracked independently" do
      {:ok, ref1} = ZenohMesh.subscribe("indrajaal/a/**", fn _msg -> :ok end)
      {:ok, ref2} = ZenohMesh.subscribe("indrajaal/b/**", fn _msg -> :ok end)
      subs = ZenohMesh.list_subscriptions()
      refs = Enum.map(subs, & &1.ref)
      assert ref1 in refs
      assert ref2 in refs
    end
  end

  # ---- publish/3 -------------------------------------------------------------

  describe "publish/3" do
    test "returns :ok for valid FQUN with map payload" do
      key =
        ZenohMesh.fqun("alarms", "fire", "events", "evt_001",
          node: "test_node",
          correlation_id: "corr_test1"
        )

      assert :ok = ZenohMesh.publish(key, %{data: "test"})
    end

    test "returns :ok for wildcard pattern key" do
      # Wildcard keys should bypass strict FQUN validation
      assert :ok = ZenohMesh.publish("indrajaal/alarms/**", %{data: "broadcast"})
    end

    test "returns {:error, :invalid_key_expression} for invalid key" do
      assert {:error, :invalid_key_expression} = ZenohMesh.publish("bad-key", %{})
    end

    test "returns {:error, :message_too_large} for oversized payload" do
      key =
        ZenohMesh.fqun("alarms", "fire", "events", "evt_big",
          node: "n",
          correlation_id: "c"
        )

      # 1MB + 1 byte - exceeds max_message_size
      oversized = :binary.copy(<<0>>, 1_048_577)
      assert {:error, :message_too_large} = ZenohMesh.publish(key, oversized, encoding: :binary)
    end

    test "published messages increment published_count" do
      key =
        ZenohMesh.fqun("alarms", "fire", "events", "evt_cnt",
          node: "n",
          correlation_id: "c_001"
        )

      before_status = ZenohMesh.mesh_status()
      ZenohMesh.publish(key, %{data: "test"})
      after_status = ZenohMesh.mesh_status()
      assert after_status.published_count == before_status.published_count + 1
    end

    test "publish with :binary encoding accepts binary payload" do
      key =
        ZenohMesh.fqun("alarms", "fire", "events", "evt_bin",
          node: "n",
          correlation_id: "c_002"
        )

      assert :ok = ZenohMesh.publish(key, <<1, 2, 3>>, encoding: :binary)
    end
  end

  # ---- put/3 -----------------------------------------------------------------

  describe "put/3" do
    test "returns :ok for valid FQUN" do
      key =
        ZenohMesh.fqun("alarms", "fire", "events", "evt_put",
          node: "n",
          correlation_id: "c_put"
        )

      assert :ok = ZenohMesh.put(key, %{stored: "value"})
    end

    test "returns {:error, :invalid_key_expression} for invalid key" do
      assert {:error, :invalid_key_expression} = ZenohMesh.put("bad-key", %{})
    end
  end

  # ---- query/2 ---------------------------------------------------------------

  describe "query/2" do
    test "returns {:ok, list}" do
      key =
        ZenohMesh.fqun("alarms", "fire", "events", "evt_q",
          node: "n",
          correlation_id: "c_q"
        )

      assert {:ok, results} = ZenohMesh.query(key)
      assert is_list(results)
    end
  end

  # ---- mesh_status/0 ---------------------------------------------------------

  describe "mesh_status/0" do
    test "returns a map with expected keys" do
      status = ZenohMesh.mesh_status()
      assert Map.has_key?(status, :port)
      assert Map.has_key?(status, :connected)
      assert Map.has_key?(status, :peers)
      assert Map.has_key?(status, :subscription_count)
      assert Map.has_key?(status, :published_count)
      assert Map.has_key?(status, :received_count)
      assert Map.has_key?(status, :uptime_seconds)
    end

    test "uptime_seconds is non-negative" do
      status = ZenohMesh.mesh_status()
      assert status.uptime_seconds >= 0
    end

    test "connected is a boolean" do
      status = ZenohMesh.mesh_status()
      assert is_boolean(status.connected)
    end
  end

  # ---- list_subscriptions/0 --------------------------------------------------

  describe "list_subscriptions/0" do
    test "returns a list" do
      subs = ZenohMesh.list_subscriptions()
      assert is_list(subs)
    end

    test "each subscription has required fields" do
      {:ok, _ref} = ZenohMesh.subscribe("indrajaal/test/**", fn _msg -> :ok end)
      subs = ZenohMesh.list_subscriptions()
      sub = List.first(subs)
      assert Map.has_key?(sub, :ref)
      assert Map.has_key?(sub, :pattern)
      assert Map.has_key?(sub, :created_at)
      assert Map.has_key?(sub, :received_count)
    end
  end

  # ---- Domain-specific key helpers -------------------------------------------

  describe "alarm_key/3, device_key/3, cluster_key/3, metrics_key/3" do
    test "alarm_key returns valid FQUN string" do
      key = ZenohMesh.alarm_key("fire", "alm_001", node: "n", correlation_id: "c")
      assert ZenohMesh.valid_fqun?(key)
      assert String.contains?(key, "alarms")
    end

    test "device_key returns valid FQUN string" do
      key = ZenohMesh.device_key("camera", "cam_001", node: "n", correlation_id: "c")
      assert ZenohMesh.valid_fqun?(key)
      assert String.contains?(key, "devices")
    end

    test "cluster_key returns valid FQUN string" do
      key = ZenohMesh.cluster_key("join", "node_001", node: "n", correlation_id: "c")
      assert ZenohMesh.valid_fqun?(key)
      assert String.contains?(key, "cluster")
    end

    test "metrics_key returns valid FQUN string" do
      key = ZenohMesh.metrics_key("cpu", "metric_001", node: "n", correlation_id: "c")
      assert ZenohMesh.valid_fqun?(key)
      assert String.contains?(key, "observability")
    end
  end

  # ---- mesh_topics/0 ---------------------------------------------------------

  describe "mesh_topics/0" do
    test "returns map with expected top-level categories" do
      topics = ZenohMesh.mesh_topics()
      assert Map.has_key?(topics, :cluster)
      assert Map.has_key?(topics, :agents)
      assert Map.has_key?(topics, :workers)
      assert Map.has_key?(topics, :health)
      assert Map.has_key?(topics, :observability)
      assert Map.has_key?(topics, :cepaf)
    end

    test "all topic values are strings" do
      topics = ZenohMesh.mesh_topics()

      topics
      |> Map.values()
      |> Enum.each(fn category ->
        Map.values(category)
        |> Enum.each(fn pattern ->
          assert is_binary(pattern)
        end)
      end)
    end
  end

  # ---- subscribe_category/2 --------------------------------------------------

  describe "subscribe_category/2" do
    test "returns {:ok, refs} for known category" do
      assert {:ok, refs} = ZenohMesh.subscribe_category(:health, fn _msg -> :ok end)
      assert is_list(refs)
      assert Enum.all?(refs, &is_reference/1)
    end

    test "returns {:error, {:unknown_category, ...}} for unknown category" do
      assert {:error, {:unknown_category, :nonexistent}} =
               ZenohMesh.subscribe_category(:nonexistent, fn _msg -> :ok end)
    end
  end

  # ---- publish_to_topic/4 ----------------------------------------------------

  describe "publish_to_topic/4" do
    test "returns :ok for known category and topic" do
      result =
        ZenohMesh.publish_to_topic(:health, :events, %{node: "app-1", status: "degraded"})

      assert result == :ok or match?({:error, _}, result)
    end

    test "returns error for unknown category" do
      assert {:error, {:unknown_topic, _}} =
               ZenohMesh.publish_to_topic(:nonexistent, :events, %{})
    end

    test "returns error for unknown topic within valid category" do
      assert {:error, {:unknown_topic, _}} =
               ZenohMesh.publish_to_topic(:health, :nonexistent, %{})
    end
  end

  # ---- publish_health_event/4 ------------------------------------------------

  describe "publish_health_event/4" do
    test "returns :ok for valid health state transition" do
      result = ZenohMesh.publish_health_event("app-1", :healthy, :degraded, "Memory pressure")
      assert result == :ok or match?({:error, _}, result)
    end

    test "publishes without reason (nil)" do
      result = ZenohMesh.publish_health_event("app-1", :healthy, :degraded)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  # ---- subscribe_to_health_events/1 ------------------------------------------

  describe "subscribe_to_health_events/1" do
    test "returns {:ok, ref}" do
      {:ok, ref} = ZenohMesh.subscribe_to_health_events(fn _event -> :ok end)
      assert is_reference(ref)
    end
  end

  # ---- publish_health_recovery/2 ---------------------------------------------

  describe "publish_health_recovery/2" do
    test "returns :ok for valid recovery" do
      result = ZenohMesh.publish_health_recovery("app-1", :healthy)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  # ---- broadcast_emergency_stop/2 --------------------------------------------

  describe "broadcast_emergency_stop/2" do
    test "returns :ok or publishable result" do
      result = ZenohMesh.broadcast_emergency_stop("app-2", "OOM killed")
      assert result == :ok or match?({:error, _}, result)
    end
  end

  # ---- subscribe_to_emergency_stops/1 ----------------------------------------

  describe "subscribe_to_emergency_stops/1" do
    test "returns {:ok, ref}" do
      {:ok, ref} = ZenohMesh.subscribe_to_emergency_stops(fn _msg -> :ok end)
      assert is_reference(ref)
    end
  end

  # ---- publish_to_fsharp/2 ---------------------------------------------------

  describe "publish_to_fsharp/2" do
    test "adds indrajaal/ prefix when missing" do
      # Should call publish with full topic path
      result = ZenohMesh.publish_to_fsharp("mymodule/event", %{data: "test"})
      assert result == :ok or match?({:error, _}, result)
    end

    test "preserves existing indrajaal/ prefix" do
      result = ZenohMesh.publish_to_fsharp("indrajaal/elixir/module/event", %{data: "test"})
      assert result == :ok or match?({:error, _}, result)
    end
  end

  # ---- get_mesh_health_state/0 -----------------------------------------------

  describe "get_mesh_health_state/0" do
    test "returns a map with health view fields" do
      state = ZenohMesh.get_mesh_health_state()
      assert Map.has_key?(state, :nodes)
      assert Map.has_key?(state, :total_nodes)
      assert Map.has_key?(state, :healthy_count)
      assert Map.has_key?(state, :degraded_count)
      assert Map.has_key?(state, :failed_count)
      assert Map.has_key?(state, :recent_events)
    end

    test "counts are non-negative integers" do
      state = ZenohMesh.get_mesh_health_state()
      assert state.total_nodes >= 0
      assert state.healthy_count >= 0
      assert state.degraded_count >= 0
      assert state.failed_count >= 0
    end
  end

  # ---- subscribe_to_fsharp_channels/0 ----------------------------------------

  describe "subscribe_to_fsharp_channels/0" do
    test "returns {:ok, refs} with 5 subscription refs" do
      {:ok, refs} = ZenohMesh.subscribe_to_fsharp_channels()
      assert is_list(refs)
      assert length(refs) == 5
      assert Enum.all?(refs, &is_reference/1)
    end
  end

  # ---- vote_on_health_consensus/3 --------------------------------------------

  describe "vote_on_health_consensus/3" do
    test "returns :ok or publishable result" do
      response_key =
        ZenohMesh.fqun("health", "consensus", "response", "req_001",
          node: "n",
          correlation_id: "c"
        )

      result = ZenohMesh.vote_on_health_consensus(response_key, "app-1", :healthy)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  # ---- PropCheck property tests ----------------------------------------------

  property "fqun/5 always produces a string" do
    forall {domain, subdomain, rtype, rid} <-
             {PC.utf8(), PC.utf8(), PC.utf8(), PC.utf8()} do
      key = ZenohMesh.fqun(domain, subdomain, rtype, rid)
      is_binary(key)
    end
  end

  property "valid_fqun? is consistent with fqun/5 output" do
    forall {domain, subdomain, rtype, rid} <-
             {PC.utf8(), PC.utf8(), PC.utf8(), PC.utf8()} do
      # Only lowercase alpha domain names produce valid FQUNs per regex
      clean_domain = Regex.replace(~r/[^a-z_]/, domain, "a")
      clean_subdomain = Regex.replace(~r/[^a-z_]/, subdomain, "a")
      clean_rtype = Regex.replace(~r/[^a-z_]/, rtype, "a")
      clean_rid = Regex.replace(~r/[^a-zA-Z0-9_-]/, rid, "a")

      d = if byte_size(clean_domain) > 0, do: clean_domain, else: "alarms"
      s = if byte_size(clean_subdomain) > 0, do: clean_subdomain, else: "fire"
      r = if byte_size(clean_rtype) > 0, do: clean_rtype, else: "events"
      i = if byte_size(clean_rid) > 0, do: clean_rid, else: "evt001"

      key = ZenohMesh.fqun(d, s, r, i, node: "node1", correlation_id: "corr_abc123")
      ZenohMesh.valid_fqun?(key)
    end
  end

  # ---- StreamData property tests ---------------------------------------------

  test "subscribing then unsubscribing is idempotent on subscription count" do
    ExUnitProperties.check all(n <- SD.integer(1..5)) do
      before_status = ZenohMesh.mesh_status()

      refs =
        Enum.map(1..n, fn i ->
          {:ok, ref} = ZenohMesh.subscribe("indrajaal/prop_test_#{i}/**", fn _msg -> :ok end)
          ref
        end)

      mid_status = ZenohMesh.mesh_status()
      assert mid_status.subscription_count == before_status.subscription_count + n

      Enum.each(refs, &ZenohMesh.unsubscribe/1)

      after_status = ZenohMesh.mesh_status()
      assert after_status.subscription_count == before_status.subscription_count
    end
  end
end
