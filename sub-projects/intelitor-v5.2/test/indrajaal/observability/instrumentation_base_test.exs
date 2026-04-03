defmodule Indrajaal.Observability.InstrumentationBaseTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Indrajaal.STAMPTestHelpers

  # Test module that uses InstrumentationBase
  defmodule TestInstrumentation do
    use Indrajaal.Observability.InstrumentationBase
  end

  # Test module with custom domain
  defmodule CustomDomainInstrumentation do
    use Indrajaal.Observability.InstrumentationBase, domain: :custom_domain
  end

  # Test module with custom otp_app
  defmodule CustomOtpAppInstrumentation do
    use Indrajaal.Observability.InstrumentationBase, otp_app: :custom_app
  end

  # Test module with both custom domain and otp_app
  defmodule FullyCustomInstrumentation do
    use Indrajaal.Observability.InstrumentationBase,
      domain: :fully_custom,
      otp_app: :fully_custom_app
  end

  # Test module with overridden setup
  defmodule OverriddenSetupInstrumentation do
    use Indrajaal.Observability.InstrumentationBase

    def setup do
      Logger.info("Custom setup for overridden instrumentation")
      attach_handlers()
      :custom_setup_ok
    end
  end

  # Test module with overridden attach_handlers
  defmodule OverriddenHandlersInstrumentation do
    use Indrajaal.Observability.InstrumentationBase

    def attach_handlers do
      Logger.debug("Custom attach_handlers implementation")
      {:ok, :custom_handlers_attached}
    end
  end

  describe "__using__ macro" do
    test "imports required modules" do
      # Logger should be required
      assert_nothing_raised(fn ->
        TestInstrumentation.setup()
      end)
    end

    test "sets default domain from module name" do
      # Domain should be extracted from module name (second to last segment)
      assert TestInstrumentation.domain() == "testinstrumentation"
    end

    test "sets custom domain when provided" do
      assert CustomDomainInstrumentation.domain() == :custom_domain
    end

    test "sets default otp_app to :indrajaal" do
      assert TestInstrumentation.otp_app() == :indrajaal
    end

    test "sets custom otp_app when provided" do
      assert CustomOtpAppInstrumentation.otp_app() == :custom_app
    end

    test "handles both custom domain and otp_app" do
      assert FullyCustomInstrumentation.domain() == :fully_custom
      assert FullyCustomInstrumentation.otp_app() == :fully_custom_app
    end

    test "implements InstrumentationBase.Behaviour" do
      # Check that behaviour callbacks are implemented
      behaviours = TestInstrumentation.__info__(:attributes)[:behaviour] || []

      assert Indrajaal.Observability.InstrumentationBase.Behaviour in behaviours
    end
  end

  describe "default setup/0 implementation" do
    test "logs setup message with domain name" do
      log =
        capture_log(fn ->
          TestInstrumentation.setup()
        end)

      assert log =~ "Setting up instrumentation for domain"
      assert log =~ "testinstrumentation"
    end

    test "calls attach_handlers during setup" do
      log =
        capture_log(fn ->
          TestInstrumentation.setup()
        end)

      # Should see both setup and attach_handlers logs
      assert log =~ "Setting up instrumentation"
      assert log =~ "Attaching telemetry handlers"
    end

    test "returns :ok" do
      capture_log(fn ->
        assert :ok = TestInstrumentation.setup()
      end)
    end

    test "works with custom domain" do
      log =
        capture_log(fn ->
          CustomDomainInstrumentation.setup()
        end)

      assert log =~ "custom_domain"
    end
  end

  describe "default attach_handlers/0 implementation" do
    test "logs attach_handlers message with domain name" do
      log =
        capture_log(fn ->
          TestInstrumentation.attach_handlers()
        end)

      assert log =~ "Attaching telemetry handlers for domain"
      assert log =~ "testinstrumentation"
    end

    test "returns :ok" do
      capture_log(fn ->
        assert :ok = TestInstrumentation.attach_handlers()
      end)
    end

    test "can be called independently of setup" do
      log =
        capture_log(fn ->
          assert :ok = TestInstrumentation.attach_handlers()
        end)

      assert log =~ "Attaching telemetry handlers"
    end
  end

  describe "defoverridable functionality" do
    test "allows overriding setup/0" do
      log =
        capture_log(fn ->
          result = OverriddenSetupInstrumentation.setup()
          assert result == :custom_setup_ok
        end)

      assert log =~ "Custom setup for overridden instrumentation"
    end

    test "allows overriding attach_handlers/0" do
      log =
        capture_log(fn ->
          result = OverriddenHandlersInstrumentation.attach_handlers()
          assert result == {:ok, :custom_handlers_attached}
        end)

      assert log =~ "Custom attach_handlers implementation"
    end

    test "overridden setup can still call attach_handlers" do
      log =
        capture_log(fn ->
          OverriddenSetupInstrumentation.setup()
        end)

      # Should see the custom setup message
      assert log =~ "Custom setup for overridden instrumentation"
      # And also the attach_handlers message
      assert log =~ "Attaching telemetry handlers"
    end
  end

  describe "domain/0 function" do
    test "returns module-specific domain" do
      assert is_binary(TestInstrumentation.domain()) or is_atom(TestInstrumentation.domain())
    end

    test "returns correct custom domain" do
      assert CustomDomainInstrumentation.domain() == :custom_domain
    end

    test "returns consistent value on multiple calls" do
      domain1 = TestInstrumentation.domain()
      domain2 = TestInstrumentation.domain()

      assert domain1 == domain2
    end
  end

  describe "otp_app/0 function" do
    test "returns otp_app configuration" do
      assert is_atom(TestInstrumentation.otp_app())
    end

    test "returns correct custom otp_app" do
      assert CustomOtpAppInstrumentation.otp_app() == :custom_app
    end

    test "returns consistent value on multiple calls" do
      app1 = TestInstrumentation.otp_app()
      app2 = TestInstrumentation.otp_app()

      assert app1 == app2
    end
  end

  describe "Behaviour module" do
    test "defines setup/0 callback" do
      callbacks = Indrajaal.Observability.InstrumentationBase.Behaviour.behaviour_info(:callbacks)

      assert {:setup, 0} in callbacks
    end

    test "defines attach_handlers/0 callback" do
      callbacks = Indrajaal.Observability.InstrumentationBase.Behaviour.behaviour_info(:callbacks)

      assert {:attach_handlers, 0} in callbacks
    end

    test "setup/0 callback returns :ok or {:error, term()}" do
      # Test that modules implementing the behaviour conform to spec
      capture_log(fn ->
        result = TestInstrumentation.setup()
        assert result == :ok or match?({:error, _}, result)
      end)
    end

    test "attach_handlers/0 callback returns :ok or {:error, term()}" do
      capture_log(fn ->
        result = TestInstrumentation.attach_handlers()
        assert result == :ok or match?({:error, _}, result)
      end)
    end
  end

  describe "common aliases and imports" do
    test "Logger is available in using modules" do
      # If Logger wasn't required, this would fail during compilation
      assert_nothing_raised(fn ->
        capture_log(fn ->
          TestInstrumentation.setup()
        end)
      end)
    end

    test "module can access domain attribute" do
      # @domain should be accessible
      assert TestInstrumentation.domain() != nil
    end

    test "module can access otp_app attribute" do
      # @otp_app should be accessible
      assert TestInstrumentation.otp_app() != nil
    end
  end

  describe "integration tests" do
    test "complete instrumentation workflow" do
      log =
        capture_log(fn ->
          # Full workflow: setup -> attach_handlers
          assert :ok = TestInstrumentation.setup()
        end)

      # Should see both setup and attach logs
      assert log =~ "Setting up instrumentation"
      assert log =~ "Attaching telemetry handlers"
    end

    test "multiple instrumentation modules can coexist" do
      log =
        capture_log(fn ->
          TestInstrumentation.setup()
          CustomDomainInstrumentation.setup()
          CustomOtpAppInstrumentation.setup()
        end)

      # All should work independently
      assert log =~ "testinstrumentation"
      assert log =~ "custom_domain"
    end

    test "modules with same base work independently" do
      log =
        capture_log(fn ->
          domain1 = TestInstrumentation.domain()
          domain2 = CustomDomainInstrumentation.domain()

          assert domain1 != domain2
        end)
    end

    test "overridden and default implementations can coexist" do
      capture_log(fn ->
        # Default implementation
        assert :ok = TestInstrumentation.setup()

        # Overridden implementation
        assert :custom_setup_ok = OverriddenSetupInstrumentation.setup()
      end)
    end
  end

  describe "error handling" do
    test "setup handles errors gracefully in overridden implementations" do
      defmodule ErroringInstrumentation do
        use Indrajaal.Observability.InstrumentationBase

        def setup do
          Logger.error("Setup failed")
          {:error, :setup_failed}
        end
      end

      capture_log(fn ->
        result = ErroringInstrumentation.setup()
        assert result == {:error, :setup_failed}
      end)
    end

    test "attach_handlers handles errors in overridden implementations" do
      defmodule ErroringHandlersInstrumentation do
        use Indrajaal.Observability.InstrumentationBase

        def attach_handlers do
          Logger.error("Handler attachment failed")
          {:error, :handler_attachment_failed}
        end
      end

      capture_log(fn ->
        result = ErroringHandlersInstrumentation.attach_handlers()
        assert result == {:error, :handler_attachment_failed}
      end)
    end

    test "domain extraction handles edge cases" do
      defmodule SingleSegmentModule do
        use Indrajaal.Observability.InstrumentationBase
      end

      # Should not crash with single segment module names
      assert_nothing_raised(fn ->
        SingleSegmentModule.domain()
      end)
    end
  end

  describe "domain name extraction" do
    test "extracts domain from nested module structure" do
      defmodule Indrajaal.Observability.Domains.TestDomain do
        use Indrajaal.Observability.InstrumentationBase
      end

      domain = Indrajaal.Observability.Domains.TestDomain.domain()
      assert is_binary(domain) or is_atom(domain)
    end

    test "handles deeply nested modules" do
      defmodule Very.Deeply.Nested.Module.Structure.TestInstr do
        use Indrajaal.Observability.InstrumentationBase
      end

      assert_nothing_raised(fn ->
        Very.Deeply.Nested.Module.Structure.TestInstr.domain()
      end)
    end

    test "uses 'unknown' for modules without sufficient structure" do
      # This tests the Enum.at(-2, "unknown") fallback
      defmodule SingleLevelTest do
        use Indrajaal.Observability.InstrumentationBase
      end

      # Should handle gracefully
      assert_nothing_raised(fn ->
        SingleLevelTest.domain()
      end)
    end
  end
end
