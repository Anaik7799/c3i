Feature: Zenoh NIF Safety & Resilience
  As a biomorphic organism
  The Indrajaal system requires its native nervous system to be stable
  To ensure zero-latency signaling without VM crashes.

  Scenario: NIF Resuscitation and Load Handshake
    Given the "zenoh_nif" library is compiled with Rustler 0.37.2
    When the Elixir module "Indrajaal.Native.Zenoh" is loaded
    Then it should return a "healthy" status from "zenoh_session_status/1"
    And it should not fail with "bad_lib" symbol errors.

  Scenario: Panic Resistance
    Given a running Zenoh NIF session
    When I call a NIF function with malformed binary data
    Then it should return a "{:error, :bad_arg}" tuple
    And it should not crash the BEAM node.

  Scenario: Scheduler Fairness (Dirty Schedulers)
    Given a high-throughput telemetry stream
    When the NIF performs a heavy I/O operation
    Then it must execute on a ":dirty_io" scheduler
    And the main BEAM schedulers must remain responsive (<1ms lag).
