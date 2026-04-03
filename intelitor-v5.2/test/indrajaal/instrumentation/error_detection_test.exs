defmodule Indrajaal.Instrumentation.ErrorDetectionTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Instrumentation.ErrorDetection

  describe "instrument_header_extraction/3" do
    test "returns :ok when header name has no spaces" do
      assert :ok =
               ErrorDetection.instrument_header_extraction(
                 :x_request_id,
                 "x-request-id",
                 "abc123"
               )
    end

    test "returns {:error, :spacing_bug} when header name contains a space" do
      assert {:error, :spacing_bug} =
               ErrorDetection.instrument_header_extraction(
                 :x_request_id,
                 "x request id",
                 "abc123"
               )
    end

    test "returns :ok for empty value with valid header name" do
      assert :ok = ErrorDetection.instrument_header_extraction(:content_type, "content-type", "")
    end

    test "returns {:error, :spacing_bug} for header with leading space" do
      assert {:error, :spacing_bug} =
               ErrorDetection.instrument_header_extraction(:bad, " authorization", "Bearer tok")
    end

    test "returns {:error, :spacing_bug} for header with trailing space" do
      assert {:error, :spacing_bug} =
               ErrorDetection.instrument_header_extraction(:bad, "authorization ", "Bearer tok")
    end

    test "returns :ok for standard HTTP header names" do
      for header <- ["authorization", "content-type", "accept", "x-forwarded-for"] do
        assert :ok = ErrorDetection.instrument_header_extraction(:h, header, "value"),
               "Expected :ok for header #{inspect(header)}"
      end
    end
  end

  describe "instrument_fingerprint_generation/2" do
    test "returns :ok when 0 empty components (high entropy)" do
      components = ["192.168.1.1", "Mozilla/5.0", "en-US", "1920x1080", "UTC", "screen", "fonts"]
      fingerprint = "abc123"
      assert :ok = ErrorDetection.instrument_fingerprint_generation(components, fingerprint)
    end

    test "returns :ok when 2 or fewer empty components (acceptable entropy)" do
      components = ["192.168.1.1", "Mozilla/5.0", "", "1920x1080", "UTC", "screen", "fonts"]
      assert :ok = ErrorDetection.instrument_fingerprint_generation(components, "fp123")
    end

    test "returns {:warning, :low_entropy} when more than 2 components are empty" do
      components = ["192.168.1.1", "", "", "", "UTC", "screen", "fonts"]

      assert {:warning, :low_entropy} =
               ErrorDetection.instrument_fingerprint_generation(components, "low_fp")
    end

    test "returns {:warning, :low_entropy} when all components are empty" do
      components = ["", "", "", "", "", "", ""]

      assert {:warning, :low_entropy} =
               ErrorDetection.instrument_fingerprint_generation(components, "empty_fp")
    end

    test "handles single-element component list with non-empty value" do
      components = ["value"]
      assert :ok = ErrorDetection.instrument_fingerprint_generation(components, "fp")
    end
  end

  describe "check_ep014_compliance/2" do
    test "returns :compliant for code without any property testing" do
      code = """
      defmodule MyModule do
        use ExUnit.Case
        test "basic" do
          assert 1 + 1 == 2
        end
      end
      """

      assert :compliant = ErrorDetection.check_ep014_compliance(code)
    end

    test "returns :compliant for code with PropCheck only (no ExUnitProperties)" do
      code = """
      defmodule MyTest do
        use PropCheck
        property "something" do
          forall x <- integer() do
            x == x
          end
        end
      end
      """

      assert :compliant = ErrorDetection.check_ep014_compliance(code)
    end

    test "returns :compliant for fully compliant dual-framework code" do
      code = """
      defmodule MyTest do
        use PropCheck
        import ExUnitProperties, except: [property: 2]
        alias PropCheck.BasicTypes, as: PC
        alias StreamData, as: SD
        ExUnitProperties.check all(x <- SD.integer()) do
          assert x == x
        end
      end
      """

      assert :compliant = ErrorDetection.check_ep014_compliance(code)
    end

    test "returns {:violation, violations} when both frameworks imported without except clause" do
      code = """
      defmodule BadTest do
        use PropCheck
        import ExUnitProperties
      end
      """

      assert {:violation, violations} = ErrorDetection.check_ep014_compliance(code)
      violation_types = Enum.map(violations, fn {type, _msg} -> type end)
      assert :missing_except_clause in violation_types
    end

    test "returns {:violation, violations} when check all() used without ExUnitProperties import" do
      code = """
      defmodule BadTest do
        use ExUnit.Case
        ExUnitProperties.check all(x <- something()) do
          assert x
        end
      end
      """

      assert {:violation, violations} = ErrorDetection.check_ep014_compliance(code)
      violation_types = Enum.map(violations, fn {type, _msg} -> type end)
      assert :missing_import in violation_types
    end

    test "returns {:violation, violations} when both frameworks present but no PC/SD aliases" do
      code = """
      defmodule BadTest do
        use PropCheck
        import ExUnitProperties, except: [property: 2]
      end
      """

      assert {:violation, violations} = ErrorDetection.check_ep014_compliance(code)
      violation_types = Enum.map(violations, fn {type, _msg} -> type end)
      assert :missing_aliases in violation_types
    end

    test "accepts file_path option for reporting" do
      code = "defmodule X do end"
      assert :compliant = ErrorDetection.check_ep014_compliance(code, file_path: "lib/x.ex")
    end

    test "returns list of violations when multiple violations present" do
      code = """
      defmodule MultiViolation do
        use PropCheck
        import ExUnitProperties
        ExUnitProperties.check all(x <- something()) do
          x
        end
      end
      """

      assert {:violation, violations} = ErrorDetection.check_ep014_compliance(code)
      assert length(violations) >= 1
    end
  end

  describe "instrument_state_transition/4" do
    test "returns :ok for valid session state transition" do
      assert :ok = ErrorDetection.instrument_state_transition(:session, :created, :active)
    end

    test "returns :ok for another valid session transition" do
      assert :ok = ErrorDetection.instrument_state_transition(:session, :active, :terminated)
    end

    test "returns :ok even for invalid session transition (warns but does not raise)" do
      # The function always returns :ok — it only logs warnings for invalid transitions
      assert :ok = ErrorDetection.instrument_state_transition(:session, :terminated, :active)
    end

    test "returns :ok for valid ep014 state transition" do
      assert :ok =
               ErrorDetection.instrument_state_transition(
                 :ep014,
                 :no_property_tests,
                 :propcheck_only
               )
    end

    test "returns :ok for unknown entity types (permissive fallback)" do
      assert :ok = ErrorDetection.instrument_state_transition(:alarm, :new, :acknowledged)
    end

    test "accepts an optional context map as fourth argument" do
      assert :ok =
               ErrorDetection.instrument_state_transition(
                 :session,
                 :created,
                 :active,
                 %{user_id: "u123"}
               )
    end

    test "uses empty map as default context" do
      assert :ok = ErrorDetection.instrument_state_transition(:session, :active, :validated)
    end
  end

  describe "attach_handlers/0" do
    test "returns :ok" do
      assert :ok = ErrorDetection.attach_handlers()
    end

    test "can be called multiple times without raising" do
      # telemetry.attach is idempotent-ish — second call may fail silently
      ErrorDetection.attach_handlers()
      assert :ok = ErrorDetection.attach_handlers()
    end
  end
end
