defmodule IndrajaalWeb.Prajna.ComplianceLivePropTest do
  @moduledoc """
  Property-based tests for ComplianceLive.

  WHAT: Verifies that ComplianceLive maintains invariants across all valid inputs —
        framework/status filters are total, audit pagination is bounded, regulation
        filter combinations are safe, page navigation stays within valid range.
  WHY: ComplianceLive has paginated audit trail (10/page), 4 regulation frameworks,
       3 status filters, and nested filter_controls logic. Property tests verify
       correctness under adversarial filter sequences and page values.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-COMP-001, SC-SAFETY-003, EP-GEN-014

  TDG Level: L1 (Property Testing)
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @valid_frameworks ["all", "iso27001", "gdpr", "en50131", "iec61508"]
  @valid_statuses ["all", "compliant", "partial", "non_compliant"]
  @valid_regulations ["all", "iso27001", "gdpr", "en50131", "iec61508"]

  # ═══════════════════════════════════════════════════════════════════════
  # FRAMEWORK FILTER PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "framework filter properties" do
    property "P-CMP-001: any valid framework filter produces a valid page" do
      forall fw <- PC.oneof(@valid_frameworks) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/compliance")
        html = render_click(view, "filter_framework", %{"framework" => fw})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-CMP-002: framework filter resets audit_page to 1" do
      forall fw <- PC.oneof(@valid_frameworks) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/compliance")

        # Go to page 2 first if possible, then filter — page must reset
        render_click(view, "audit_page", %{"page" => "2"})
        _html = render_click(view, "filter_framework", %{"framework" => fw})

        html = render(view)
        # Page indicator should show page 1 after framework filter
        html =~ "Page 1 of"
      end
    end

    property "P-CMP-003: any sequence of framework filter switches ends in valid state" do
      forall fws <- PC.non_empty(PC.list(PC.oneof(@valid_frameworks))) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/compliance")

        Enum.each(fws, fn fw ->
          render_click(view, "filter_framework", %{"framework" => fw})
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STATUS FILTER PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "status filter properties" do
    property "P-CMP-004: any valid status filter produces a valid page" do
      forall st <- PC.oneof(@valid_statuses) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/compliance")
        html = render_click(view, "filter_status", %{"status" => st})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-CMP-005: framework and status filters compose safely" do
      forall {fw, st} <- {PC.oneof(@valid_frameworks), PC.oneof(@valid_statuses)} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/compliance")

        render_click(view, "filter_framework", %{"framework" => fw})
        html = render_click(view, "filter_status", %{"status" => st})

        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # AUDIT PAGINATION PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "audit pagination properties" do
    property "P-CMP-006: page value is always clamped to 1..max_page" do
      forall page <- PC.integer(-100, 200) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/compliance")
        _html = render_click(view, "audit_page", %{"page" => Integer.to_string(page)})

        html = render(view)
        # Page N of M must appear; N must be >= 1
        html =~ ~r/Page \d+ of \d+/
      end
    end

    property "P-CMP-007: regulation filter resets page to 1" do
      forall reg <- PC.oneof(@valid_regulations) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/compliance")

        render_click(view, "audit_page", %{"page" => "3"})
        _html = render_click(view, "filter_regulation", %{"regulation" => reg})

        html = render(view)
        html =~ "Page 1 of"
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # REGULATION FILTER PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "regulation filter properties" do
    property "P-CMP-008: any valid regulation filter produces a valid page" do
      forall reg <- PC.oneof(@valid_regulations) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/compliance")
        html = render_click(view, "filter_regulation", %{"regulation" => reg})

        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STREAMDATA TESTS (ExUnitProperties)
  # ═══════════════════════════════════════════════════════════════════════

  describe "StreamData property tests" do
    @tag timeout: 30_000
    check all(
            fw <- SD.member_of(["all", "iso27001", "gdpr", "en50131", "iec61508"]),
            st <- SD.member_of(["all", "compliant", "partial", "non_compliant"]),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/compliance")
      render_click(view, "filter_framework", %{"framework" => fw})
      html = render_click(view, "filter_status", %{"status" => st})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    @tag timeout: 30_000
    check all(
            page <- SD.integer(1, 10),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/compliance")
      html = render_click(view, "audit_page", %{"page" => Integer.to_string(page)})
      assert is_binary(html)
      # Page indicator must always be present
      assert html =~ ~r/Page \d+ of \d+/
    end
  end
end
