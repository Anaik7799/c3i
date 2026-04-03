defmodule Mix.Tasks.WallabyCoverageAudit do
  @moduledoc """
  Audits Wallaby E2E test coverage against the fractal gold standard.

  Scans all Wallaby test files in `test/indrajaal_web/live/` and evaluates
  each file against the 8-category gold standard (C1-C8) defined in
  `.claude/rules/fractal-coverage-gold-standard.md`.

  For each file, computes:
  - Feature count and category distribution across C1-C8
  - Shannon entropy H = -Σ p_i × log2(p_i) (target: ≥ 2.5 bits)
  - C8 dual verification: flash assertions vs action button features
  - Priority threshold compliance (P0≥30, P1≥20, P2≥15, P3≥10)

  Cross-references against the corresponding LiveView source to identify:
  - Untested `handle_event` callbacks
  - Untested `phx-click` action buttons

  Outputs a per-file coverage matrix and aggregate metrics including ITQS
  (Information-Theoretic Quality Score) per SC-MATH-COV-007.

  ## Usage

      mix wallaby_coverage_audit                    # Full audit (all files)
      mix wallaby_coverage_audit --summary          # Aggregate metrics only
      mix wallaby_coverage_audit --file commands    # Single file (substring match)
      mix wallaby_coverage_audit --json             # Machine-readable JSON output
      mix wallaby_coverage_audit --fix              # Generate recommended additions

  ## STAMP
  SC-COV-008 (Wallaby E2E mandatory), SC-COV-009 to SC-COV-016 (8-category gold standard),
  SC-COV-017 to SC-COV-020 (priority thresholds, two-step, PubSub),
  SC-HMI-011 (8x8 Matrix path coverage), AOR-COV-008 to AOR-COV-015

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude | Initial implementation |

  ## Constitutional Alignment
  - Ψ₁ Regeneration: Audit state derived from source files, no external state
  - Ψ₃ Verification: All metrics computed via deterministic formulas
  """

  use Mix.Task

  @shortdoc "Audit Wallaby E2E test coverage against fractal gold standard"

  @version "21.3.1"

  # ── Category recognition patterns ──────────────────────────────────────────

  # Maps each C-category marker to its canonical integer.
  # We match "C1:", "C1 —", "C1 (", etc.
  @category_patterns %{
    1 => ~r/──\s*C1[\s:—(]/i,
    2 => ~r/──\s*C2[\s:—(]/i,
    3 => ~r/──\s*C3[\s:—(]/i,
    4 => ~r/──\s*C4[\s:—(]/i,
    5 => ~r/──\s*C5[\s:—(]/i,
    6 => ~r/──\s*C6[\s:—(]/i,
    7 => ~r/──\s*C7[\s:—(]/i,
    8 => ~r/──\s*C8[\s:—(]/i
  }

  @category_names %{
    1 => "Page Structure",
    2 => "Status/Badge Display",
    3 => "Data Grid/Summary",
    4 => "Timeline/History",
    5 => "Interactive Elements",
    6 => "Media/Rich Content",
    7 => "AI/Advisory Panels",
    8 => "Action Buttons (Dual)"
  }

  # Priority thresholds per SC-COV-017 to SC-COV-019
  @priority_thresholds %{p0: 30, p1: 20, p2: 15, p3: 10}

  # Minimum entropy per AOR-COV-012
  @min_entropy 2.5

  # Maximum entropy for 8 categories
  @max_entropy :math.log(8) / :math.log(2)

  # CCM weights per SC-MATH-COV-003
  @ccm_weights %{1 => 1.0, 2 => 1.5, 3 => 1.0, 4 => 1.2, 5 => 2.0, 6 => 1.0, 7 => 1.5, 8 => 3.0}
  @ccm_expected_min %{1 => 2, 2 => 2, 3 => 4, 4 => 3, 5 => 3, 6 => 3, 7 => 2, 8 => 4}

  # ITQS coefficients per SC-MATH-COV-007
  @itqs_alpha 0.25
  @itqs_beta 0.35
  @itqs_gamma 0.25
  @itqs_delta 0.15

  # ── Test search roots ───────────────────────────────────────────────────────

  @test_root "test/indrajaal_web/live"
  @live_roots [
    "lib/indrajaal_web/live",
    "lib/indrajaal_web/live/operations",
    "lib/indrajaal_web/live/prajna",
    "lib/indrajaal_web/live/prajna/knowledge",
    "lib/indrajaal_web/live/admin",
    "lib/indrajaal_web/live/crm"
  ]

  # ── Entry point ─────────────────────────────────────────────────────────────

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [
          summary: :boolean,
          file: :string,
          json: :boolean,
          fix: :boolean
        ]
      )

    wallaby_files = collect_wallaby_files()

    filtered =
      case opts[:file] do
        nil -> wallaby_files
        pattern -> Enum.filter(wallaby_files, &String.contains?(&1, pattern))
      end

    if filtered == [] do
      Mix.shell().error("No Wallaby test files found matching the given criteria.")
      exit({:shutdown, 1})
    end

    audits = Enum.map(filtered, &audit_file/1)

    # Compute suite-wide FSI (SC-MATH-COV-005) and per-file ITQS (SC-MATH-COV-007)
    fsi = compute_fsi(audits)
    audits = enrich_with_itqs(audits, fsi)

    if opts[:json] do
      output_json(audits)
    else
      unless opts[:summary] do
        Enum.each(audits, &print_file_box(&1, opts[:fix] || false))
      end

      print_aggregate(audits)
    end
  end

  # ── File collection ─────────────────────────────────────────────────────────

  @spec collect_wallaby_files() :: [String.t()]
  defp collect_wallaby_files do
    [@test_root]
    |> Enum.flat_map(&collect_recursive/1)
    |> Enum.filter(&String.contains?(&1, "wallaby"))
    |> Enum.sort()
  end

  @spec collect_recursive(String.t()) :: [String.t()]
  defp collect_recursive(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        Enum.flat_map(entries, fn entry ->
          full = Path.join(dir, entry)

          cond do
            File.dir?(full) -> collect_recursive(full)
            String.ends_with?(entry, ".exs") -> [full]
            true -> []
          end
        end)

      {:error, _} ->
        []
    end
  end

  # ── Per-file audit ──────────────────────────────────────────────────────────

  @typedoc "All metrics for a single Wallaby test file."
  @type file_audit :: %{
          path: String.t(),
          basename: String.t(),
          content: String.t(),
          lines: [String.t()],
          feature_count: non_neg_integer(),
          category_distribution: %{(1..8) => non_neg_integer()},
          categories_present: [1..8],
          entropy: float(),
          c8_buttons: non_neg_integer(),
          c8_flash: non_neg_integer(),
          c8_status: non_neg_integer(),
          c8_dual_coverage: float(),
          missing_flash_buttons: [String.t()],
          priority: :p0 | :p1 | :p2 | :p3,
          threshold: non_neg_integer(),
          threshold_pass: boolean(),
          entropy_pass: boolean(),
          source_handle_events: [String.t()],
          source_phx_clicks: [String.t()],
          tested_events: [String.t()],
          untested_events: [String.t()],
          untested_phx_clicks: [String.t()],
          recommendations: [String.t()],
          d_ea: float(),
          ccm_weighted: float(),
          itqs: float(),
          fsi: float()
        }

  @spec audit_file(String.t()) :: file_audit()
  defp audit_file(path) do
    content = File.read!(path)
    basename = Path.basename(path)
    lines = String.split(content, "\n")

    feature_count = count_features(content)
    cat_dist = compute_category_distribution(lines)
    categories_present = Enum.filter(1..8, &(Map.get(cat_dist, &1, 0) > 0))
    entropy = compute_entropy(cat_dist, feature_count)

    {c8_buttons, c8_flash, c8_status, missing_flash} = analyze_c8(lines)

    c8_dual =
      if c8_buttons > 0, do: min(c8_flash, c8_status) / c8_buttons, else: 1.0

    priority = infer_priority(path, content)
    threshold = @priority_thresholds[priority]
    threshold_pass = feature_count >= threshold
    entropy_pass = entropy >= @min_entropy or feature_count == 0

    # Cross-reference LiveView source
    {source_events, source_clicks} = find_source_file(path)
    tested_events = find_tested_events(content, source_events)
    untested_events = source_events -- tested_events
    tested_clicks = find_tested_clicks(content, source_clicks)
    untested_clicks = source_clicks -- tested_clicks

    # EXPECTED vs AS-IS divergence (SC-MATH-COV-006)
    f_expected_size = length(Enum.uniq(source_events ++ source_clicks))
    f_gap_size = length(Enum.uniq(untested_events ++ untested_clicks))
    d_ea = if f_expected_size > 0, do: Float.round(f_gap_size / f_expected_size, 4), else: 0.0

    # Weighted CCM per SC-MATH-COV-003
    ccm_weighted = compute_ccm_weighted(cat_dist, content)

    recommendations =
      build_recommendations(
        cat_dist,
        entropy,
        entropy_pass,
        threshold_pass,
        feature_count,
        threshold,
        priority,
        missing_flash,
        untested_events,
        untested_clicks,
        content
      )

    %{
      path: path,
      basename: basename,
      content: content,
      lines: lines,
      feature_count: feature_count,
      category_distribution: cat_dist,
      categories_present: categories_present,
      entropy: entropy,
      c8_buttons: c8_buttons,
      c8_flash: c8_flash,
      c8_status: c8_status,
      c8_dual_coverage: c8_dual,
      missing_flash_buttons: missing_flash,
      priority: priority,
      threshold: threshold,
      threshold_pass: threshold_pass,
      entropy_pass: entropy_pass,
      source_handle_events: source_events,
      source_phx_clicks: source_clicks,
      tested_events: tested_events,
      untested_events: untested_events,
      untested_phx_clicks: untested_clicks,
      recommendations: recommendations,
      d_ea: d_ea,
      ccm_weighted: ccm_weighted,
      itqs: 0.0,
      fsi: 0.0
    }
  end

  # ── Feature counting ────────────────────────────────────────────────────────

  @spec count_features(String.t()) :: non_neg_integer()
  defp count_features(content) do
    ~r/^\s+feature\s+"/m
    |> Regex.scan(content)
    |> length()
  end

  # ── Category distribution ───────────────────────────────────────────────────

  @spec compute_category_distribution([String.t()]) :: %{(1..8) => non_neg_integer()}
  defp compute_category_distribution(lines) do
    # Walk the lines: when we hit a C{n} header, track current category.
    # Count each `feature "` line against the active category.
    {dist, _active} =
      Enum.reduce(lines, {Map.new(1..8, &{&1, 0}), nil}, fn line, {dist, active} ->
        case detect_category_header(line) do
          {:category, n} ->
            {dist, n}

          :none ->
            if is_feature_line?(line) and not is_nil(active) do
              {Map.update!(dist, active, &(&1 + 1)), active}
            else
              {dist, active}
            end
        end
      end)

    dist
  end

  @spec detect_category_header(String.t()) :: {:category, 1..8} | :none
  defp detect_category_header(line) do
    Enum.find_value(@category_patterns, :none, fn {n, pattern} ->
      if Regex.match?(pattern, line), do: {:category, n}, else: nil
    end)
  end

  @spec is_feature_line?(String.t()) :: boolean()
  defp is_feature_line?(line), do: Regex.match?(~r/^\s+feature\s+"/, line)

  # ── Shannon entropy ─────────────────────────────────────────────────────────

  @spec compute_entropy(%{(1..8) => non_neg_integer()}, non_neg_integer()) :: float()
  defp compute_entropy(_dist, 0), do: 0.0

  defp compute_entropy(dist, total) do
    dist
    |> Map.values()
    |> Enum.filter(&(&1 > 0))
    |> Enum.reduce(0.0, fn count, acc ->
      p = count / total
      acc - p * (:math.log(p) / :math.log(2))
    end)
    |> Float.round(3)
  end

  # ── C8 dual-verification analysis ──────────────────────────────────────────

  @spec analyze_c8([String.t()]) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(), [String.t()]}
  defp analyze_c8(lines) do
    # Extract phx-click button names from C8 features
    c8_region = extract_c8_region(lines)

    button_names =
      ~r/phx-click=['"]([^'"]+)['"]/
      |> Regex.scan(Enum.join(c8_region, "\n"))
      |> Enum.map(fn [_, name] -> name end)
      |> Enum.uniq()

    c8_text = Enum.join(c8_region, "\n")

    has_flash =
      Regex.match?(~r/role='alert'|role="alert"|\[role='alert'\]|\[role="alert"\]/, c8_text)

    has_status_change = Regex.match?(~r/assert_has.*span.*text:/, c8_text)

    flash_count = count_flash_assertions(c8_region)
    status_count = count_status_assertions(c8_region)

    # Identify buttons that have status tests but no flash tests
    missing_flash =
      button_names
      |> Enum.filter(fn btn ->
        btn_region = extract_button_feature_region(lines, btn)
        not Regex.match?(~r/role='alert'|role="alert"/, Enum.join(btn_region, "\n"))
      end)

    button_count = length(button_names)

    _ = has_flash
    _ = has_status_change

    {button_count, flash_count, status_count, missing_flash}
  end

  @spec extract_c8_region([String.t()]) :: [String.t()]
  defp extract_c8_region(lines) do
    lines
    |> Enum.drop_while(&(not Regex.match?(~r/──\s*C8[\s:—(]/i, &1)))
    |> case do
      [] -> []
      [_ | rest] -> rest
    end
  end

  @spec extract_button_feature_region([String.t()], String.t()) :: [String.t()]
  defp extract_button_feature_region(lines, button_name) do
    # Find features in C8 that reference the given button
    lines
    |> Enum.chunk_by(&is_feature_line?/1)
    |> Enum.filter(fn chunk ->
      text = Enum.join(chunk, "\n")
      String.contains?(text, button_name)
    end)
    |> List.flatten()
  end

  @spec count_flash_assertions([String.t()]) :: non_neg_integer()
  defp count_flash_assertions(lines) do
    lines
    |> Enum.count(fn line ->
      Regex.match?(~r/role='alert'|role="alert"|\[role='alert'\]|\[role="alert"\]/, line)
    end)
  end

  @spec count_status_assertions([String.t()]) :: non_neg_integer()
  defp count_status_assertions(lines) do
    lines
    |> Enum.count(fn line ->
      Regex.match?(~r/assert_has\(css\("span"/, line)
    end)
  end

  # ── Priority inference ──────────────────────────────────────────────────────

  @spec infer_priority(String.t(), String.t()) :: :p0 | :p1 | :p2 | :p3
  defp infer_priority(path, content) do
    cond do
      # P0: Safety-critical pages
      String.contains?(content, "SC-SAFETY") or
        String.contains?(content, "two-step") or
        String.contains?(path, "alarm") or
        String.contains?(path, "command") or
        String.contains?(path, "guardian") or
        String.contains?(path, "dispatch") or
        String.contains?(path, "sentinel") or
          String.contains?(path, "shutdown") ->
        :p0

      # P1: Interactive pages with complex state
      String.contains?(path, "observability") or
        String.contains?(path, "cluster") or
        String.contains?(path, "topology") or
        String.contains?(path, "devices") or
        String.contains?(path, "mesh") or
        String.contains?(path, "analytics") or
        String.contains?(path, "compliance") or
          String.contains?(path, "copilot") ->
        :p1

      # P2: Infrastructure/informational
      String.contains?(path, "settings") or
        String.contains?(path, "register") or
        String.contains?(path, "knowledge") or
        String.contains?(path, "startup") or
        String.contains?(path, "containers") or
        String.contains?(path, "diagnostics") or
          String.contains?(path, "video") ->
        :p2

      # P3: Admin/auxiliary
      true ->
        :p3
    end
  end

  # ── LiveView source cross-reference ────────────────────────────────────────

  @spec find_source_file(String.t()) :: {[String.t()], [String.t()]}
  defp find_source_file(test_path) do
    # Derive the expected source filename from the test filename
    source_name =
      test_path
      |> Path.basename()
      |> String.replace("_wallaby_test.exs", ".ex")

    source_path =
      @live_roots
      |> Enum.map(&Path.join(&1, source_name))
      |> Enum.find(&File.exists?/1)

    case source_path do
      nil ->
        {[], []}

      path ->
        src = File.read!(path)
        {extract_handle_events(src), extract_phx_clicks(src)}
    end
  end

  @spec extract_handle_events(String.t()) :: [String.t()]
  defp extract_handle_events(source) do
    ~r/def handle_event\("([^"]+)"/
    |> Regex.scan(source)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.uniq()
  end

  @spec extract_phx_clicks(String.t()) :: [String.t()]
  defp extract_phx_clicks(source) do
    ~r/phx-click=['"]([^'"]+)['"]/
    |> Regex.scan(source)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.uniq()
  end

  @spec find_tested_events(String.t(), [String.t()]) :: [String.t()]
  defp find_tested_events(test_content, events) do
    Enum.filter(events, &String.contains?(test_content, &1))
  end

  @spec find_tested_clicks(String.t(), [String.t()]) :: [String.t()]
  defp find_tested_clicks(test_content, clicks) do
    Enum.filter(clicks, &String.contains?(test_content, &1))
  end

  # ── Recommendation builder ──────────────────────────────────────────────────

  @spec build_recommendations(
          %{(1..8) => non_neg_integer()},
          float(),
          boolean(),
          boolean(),
          non_neg_integer(),
          non_neg_integer(),
          atom(),
          [String.t()],
          [String.t()],
          [String.t()],
          String.t()
        ) :: [String.t()]
  defp build_recommendations(
         cat_dist,
         entropy,
         entropy_pass,
         threshold_pass,
         feature_count,
         threshold,
         priority,
         missing_flash,
         untested_events,
         untested_clicks,
         content
       ) do
    recs = []

    # Threshold violation
    recs =
      if not threshold_pass do
        deficit = threshold - feature_count

        [
          "Add #{deficit} more features to meet #{priority |> to_string() |> String.upcase()} threshold (#{feature_count}/#{threshold})"
          | recs
        ]
      else
        recs
      end

    # Entropy violation
    recs =
      if not entropy_pass and feature_count > 0 do
        [
          "Improve category balance to reach H ≥ 2.5 bits (current: #{Float.round(entropy, 2)} bits, AOR-COV-012)"
          | recs
        ]
      else
        recs
      end

    # Missing mandatory categories (C1, C2, C3, C8 always required)
    mandatory = [1, 2, 3, 8]

    recs =
      mandatory
      |> Enum.filter(fn c -> Map.get(cat_dist, c, 0) == 0 end)
      |> Enum.reduce(recs, fn c, acc ->
        [
          "Add #{@category_names[c]} tests (C#{c} is mandatory for all pages, SC-COV-00#{c + 8})"
          | acc
        ]
      end)

    # Optional categories that appear applicable from content
    optional_applicable =
      [
        {4, "timeline", "Timeline/History"},
        {5, "form|textarea|submit|fill_in", "Interactive Elements"},
        {6, "chart|svg|video|media|play", "Media/Rich Content"},
        {7, "AI|advisory|copilot|insight", "AI/Advisory Panels"}
      ]

    recs =
      optional_applicable
      |> Enum.filter(fn {c, pattern, _} ->
        Map.get(cat_dist, c, 0) == 0 and Regex.match?(~r/#{pattern}/i, content)
      end)
      |> Enum.reduce(recs, fn {c, _, name}, acc ->
        ["Add #{name} tests (C#{c} — page content detected, SC-COV-00#{c + 8})" | acc]
      end)

    # C8 dual verification gaps (SC-COV-016)
    recs =
      missing_flash
      |> Enum.take(5)
      |> Enum.reduce(recs, fn btn, acc ->
        ["Add flash assertion for \"#{btn}\" button (C8 dual verification, SC-COV-016)" | acc]
      end)

    # Untested handle_event callbacks
    recs =
      untested_events
      |> Enum.take(4)
      |> Enum.reduce(recs, fn ev, acc ->
        ["Add test for handle_event(\"#{ev}\") — present in LiveView source, not tested" | acc]
      end)

    # Untested phx-click buttons from source
    recs =
      untested_clicks
      |> Enum.reject(&(&1 in missing_flash))
      |> Enum.take(4)
      |> Enum.reduce(recs, fn btn, acc ->
        ["Add test for phx-click=\"#{btn}\" — button present in HEEx template, not tested" | acc]
      end)

    # PubSub refresh test recommendation (SC-COV-020)
    recs =
      if not String.contains?(content, ":refresh") and
           not String.contains?(content, "handle_info") do
        ["Consider adding PubSub refresh stability test (SC-COV-020): sleep + re-assert" | recs]
      else
        recs
      end

    Enum.reverse(recs)
  end

  # ── Box printer ─────────────────────────────────────────────────────────────

  @spec print_file_box(file_audit(), boolean()) :: :ok
  defp print_file_box(audit, show_fix) do
    width = 66

    border_h = String.duplicate("═", width)
    inner_w = width - 2

    line = fn text ->
      padded = String.pad_trailing(text, inner_w)
      "║ #{padded} ║"
    end

    separator = fn ->
      IO.puts("╠═#{border_h}═╣")
    end

    IO.puts("")
    IO.puts("╔═#{border_h}═╗")

    # File header
    IO.puts(line.("File: #{audit.basename}"))
    separator.()

    # Metrics line 1
    features_str = "Features: #{audit.feature_count}"
    cats_str = "Categories: #{length(audit.categories_present)}/8"
    entropy_flag = if audit.entropy_pass, do: "✓", else: "✗"
    h_str = "H: #{Float.round(audit.entropy, 2)} bits #{entropy_flag}"
    IO.puts(line.("#{features_str} | #{cats_str} | #{h_str}"))

    # Category distribution
    dist_str =
      1..8
      |> Enum.map(fn c -> "C#{c}:#{Map.get(audit.category_distribution, c, 0)}" end)
      |> Enum.join("  ")

    IO.puts(line.(dist_str))

    # Missing categories
    missing_cats =
      1..8
      |> Enum.filter(&(Map.get(audit.category_distribution, &1, 0) == 0))
      |> Enum.map(fn c -> "C#{c} (#{@category_names[c]})" end)

    if missing_cats != [] do
      missing_str = "Missing: " <> Enum.join(missing_cats, ", ")

      missing_str
      |> chunk_string(inner_w)
      |> Enum.each(&IO.puts(line.(&1)))
    end

    # C8 dual verification
    dual_pct = Float.round(audit.c8_dual_coverage * 100, 0) |> trunc()
    dual_flag = if audit.c8_dual_coverage >= 1.0, do: "✓", else: "✗"

    c8_str =
      "C8 Dual: #{audit.c8_flash}/#{audit.c8_buttons} flash, " <>
        "#{audit.c8_status}/#{audit.c8_buttons} status (#{dual_pct}%) #{dual_flag}"

    IO.puts(line.(c8_str))

    # Priority
    prio_str = audit.priority |> to_string() |> String.upcase()
    threshold_flag = if audit.threshold_pass, do: "✓", else: "✗"

    IO.puts(
      line.(
        "Priority: #{prio_str} (≥#{audit.threshold}) #{threshold_flag}" <>
          " | Source events: #{length(audit.source_handle_events)}" <>
          " | Untested: #{length(audit.untested_events)}"
      )
    )

    # ITQS score line
    grade = itqs_grade(audit.itqs)
    d_ea_pct = Float.round(audit.d_ea * 100, 1)
    ccm_pct = Float.round(audit.ccm_weighted * 100, 1)
    itqs_flag = if audit.itqs >= 0.75, do: "✓", else: "✗"

    IO.puts(
      line.("ITQS: #{audit.itqs} (#{grade}) #{itqs_flag} | CCM: #{ccm_pct}% | D_EA: #{d_ea_pct}%")
    )

    # Source cross-reference
    if audit.untested_events != [] do
      events_str = "Untested events: " <> Enum.join(Enum.take(audit.untested_events, 5), ", ")
      IO.puts(line.(events_str))
    end

    if audit.untested_phx_clicks != [] do
      clicks_str =
        "Untested buttons: " <> Enum.join(Enum.take(audit.untested_phx_clicks, 5), ", ")

      IO.puts(line.(clicks_str))
    end

    # Recommendations
    if audit.recommendations != [] do
      separator.()
      IO.puts(line.("RECOMMENDATIONS:"))

      audit.recommendations
      |> Enum.with_index(1)
      |> Enum.each(fn {rec, idx} ->
        "#{idx}. #{rec}"
        |> chunk_string(inner_w)
        |> Enum.each(&IO.puts(line.(&1)))
      end)
    end

    # Fix output
    if show_fix and audit.recommendations != [] do
      separator.()
      IO.puts(line.("GENERATED ADDITIONS (--fix):"))
      print_fix_suggestions(audit, line)
    end

    IO.puts("╚═#{border_h}═╝")
    :ok
  end

  @spec chunk_string(String.t(), pos_integer()) :: [String.t()]
  defp chunk_string(str, width) when byte_size(str) <= width, do: [str]

  defp chunk_string(str, width) do
    str
    |> String.graphemes()
    |> Enum.chunk_every(width)
    |> Enum.map(&Enum.join/1)
  end

  @spec print_fix_suggestions(file_audit(), (String.t() -> String.t())) :: :ok
  defp print_fix_suggestions(audit, line_fn) do
    # Generate skeleton feature blocks for the most impactful gaps
    missing_cats =
      1..8
      |> Enum.filter(&(Map.get(audit.category_distribution, &1, 0) == 0))

    Enum.each(missing_cats, fn c ->
      IO.puts(line_fn.(""))
      IO.puts(line_fn.("  # ── C#{c}: #{@category_names[c]} ───────────────────────────"))

      IO.puts(
        line_fn.("  feature \"#{String.downcase(@category_names[c])} — TODO\", %{session: s} do")
      )

      IO.puts(line_fn.("    s |> visit(@path) |> assert_has(css(\"\", text: \"\"))"))
      IO.puts(line_fn.("  end"))
    end)

    Enum.each(Enum.take(audit.missing_flash_buttons, 3), fn btn ->
      IO.puts(line_fn.(""))
      IO.puts(line_fn.("  # ── C8: #{btn} — flash test (SC-COV-016) ──────────────"))
      IO.puts(line_fn.("  feature \"clicking #{btn} triggers flash\", %{session: s} do"))
      IO.puts(line_fn.("    s |> visit(@path)"))
      IO.puts(line_fn.("    |> click(css(\"button[phx-click='#{btn}']\"))"))
      IO.puts(line_fn.("    |> assert_has(css(\"[role='alert']\", text: \"\"))"))
      IO.puts(line_fn.("  end"))
    end)

    :ok
  end

  # ── Aggregate metrics ───────────────────────────────────────────────────────

  @spec print_aggregate([file_audit()]) :: :ok
  defp print_aggregate(audits) do
    total_files = length(audits)
    total_features = Enum.sum(Enum.map(audits, & &1.feature_count))
    passing_threshold = Enum.count(audits, & &1.threshold_pass)
    passing_entropy = Enum.count(audits, & &1.entropy_pass)
    full_c8_dual = Enum.count(audits, &(&1.c8_dual_coverage >= 1.0))

    avg_entropy =
      if total_files > 0 do
        (Enum.sum(Enum.map(audits, & &1.entropy)) / total_files) |> Float.round(3)
      else
        0.0
      end

    avg_features =
      if total_files > 0, do: (total_features / total_files) |> Float.round(1), else: 0.0

    # Coverage Completeness Metric — fraction of files meeting all gates
    full_pass =
      Enum.count(audits, fn a ->
        a.threshold_pass and a.entropy_pass and a.c8_dual_coverage >= 1.0 and
          Enum.all?([1, 2, 3, 8], &(Map.get(a.category_distribution, &1, 0) > 0))
      end)

    ccm = if total_files > 0, do: (full_pass / total_files * 100) |> Float.round(1), else: 0.0

    # Risk-Weighted Coverage — weighted by priority
    rwc = compute_rwc(audits)

    # Fractal Standard Score Index
    fssi = compute_fssi(audits)

    # Missing test files for existing LiveView sources
    missing_test_files = find_missing_test_files()

    width = 66
    border_h = String.duplicate("═", width)
    inner_w = width - 2

    line = fn text ->
      padded = String.pad_trailing(text, inner_w)
      "║ #{padded} ║"
    end

    IO.puts("")
    IO.puts("╔═#{border_h}═╗")
    IO.puts(line.("WALLABY FRACTAL COVERAGE AUDIT — AGGREGATE              v#{@version}"))
    IO.puts("╠═#{border_h}═╣")
    IO.puts(line.("Files audited : #{total_files}"))
    IO.puts(line.("Total features: #{total_features} (avg #{avg_features}/file)"))
    IO.puts(line.("Avg entropy   : #{avg_entropy} bits (target ≥ #{@min_entropy})"))
    IO.puts("╠═#{border_h}═╣")
    IO.puts(line.("Gate            Pass  Fail  Rate"))
    IO.puts(line.("────────────    ────  ────  ────"))
    fail_thresh = total_files - passing_threshold
    fail_entropy = total_files - passing_entropy
    fail_c8 = total_files - full_c8_dual

    IO.puts(
      line.(
        "Priority thresh #{passing_threshold |> pad(4)}  #{fail_thresh |> pad(4)}  #{pct(passing_threshold, total_files)}"
      )
    )

    IO.puts(
      line.(
        "Entropy ≥2.5    #{passing_entropy |> pad(4)}  #{fail_entropy |> pad(4)}  #{pct(passing_entropy, total_files)}"
      )
    )

    IO.puts(
      line.(
        "C8 Dual verif.  #{full_c8_dual |> pad(4)}  #{fail_c8 |> pad(4)}  #{pct(full_c8_dual, total_files)}"
      )
    )

    # ITQS suite-wide metrics
    suite_fsi =
      if total_files > 0,
        do: List.first(audits).fsi,
        else: 0.0

    suite_itqs =
      if total_files > 0 do
        (Enum.sum(Enum.map(audits, & &1.itqs)) / total_files) |> Float.round(4)
      else
        0.0
      end

    suite_itqs_grade = itqs_grade(suite_itqs)

    avg_d_ea =
      if total_files > 0 do
        (Enum.sum(Enum.map(audits, & &1.d_ea)) / total_files) |> Float.round(4)
      else
        0.0
      end

    avg_ccm_w =
      if total_files > 0 do
        (Enum.sum(Enum.map(audits, & &1.ccm_weighted)) / total_files) |> Float.round(4)
      else
        0.0
      end

    IO.puts("╠═#{border_h}═╣")
    IO.puts(line.("CCM (all gates) : #{ccm}%  (target: 100%)"))
    IO.puts(line.("RWC (risk-wt)   : #{rwc}%  (target: ≥90%)"))
    IO.puts(line.("FSSI            : #{fssi}   (target: ≥0.85)"))
    IO.puts("╠═#{border_h}═╣")
    IO.puts(line.("ITQS METRICS (SC-MATH-COV)"))
    IO.puts(line.("────────────────────────────────────────────────────"))
    IO.puts(line.("FSI (self-sim)  : #{suite_fsi}  (target: ≥0.85, SC-MATH-COV-005)"))
    IO.puts(line.("Avg D_EA (div.) : #{avg_d_ea}  (target: ≤0.10, SC-MATH-COV-006)"))
    IO.puts(line.("Avg CCM (wt.)   : #{Float.round(avg_ccm_w * 100, 1)}%  (target: ≥90%)"))
    IO.puts(line.("Suite ITQS      : #{suite_itqs} Grade #{suite_itqs_grade}  (target: ≥0.85)"))

    IO.puts(
      line.(
        "  α=#{@itqs_alpha}×H_norm + β=#{@itqs_beta}×CCM + γ=#{@itqs_gamma}×(1-D_EA) + δ=#{@itqs_delta}×FSI"
      )
    )

    if missing_test_files != [] do
      IO.puts("╠═#{border_h}═╣")
      IO.puts(line.("MISSING TEST FILES (LiveView without Wallaby test):"))

      Enum.each(Enum.take(missing_test_files, 8), fn f ->
        IO.puts(line.("  - #{f}"))
      end)

      if length(missing_test_files) > 8 do
        IO.puts(line.("  ... and #{length(missing_test_files) - 8} more"))
      end
    end

    IO.puts("╠═#{border_h}═╣")

    failing =
      audits
      |> Enum.filter(&(not &1.threshold_pass or not &1.entropy_pass))
      |> Enum.sort_by(& &1.feature_count)
      |> Enum.take(5)

    if failing != [] do
      IO.puts(line.("PAGES BELOW THRESHOLD (lowest first):"))

      Enum.each(failing, fn a ->
        flags =
          [
            if(not a.threshold_pass, do: "threshold", else: nil),
            if(not a.entropy_pass, do: "entropy", else: nil)
          ]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(", ")

        IO.puts(line.("  #{a.basename} [#{a.feature_count} features, #{flags}]"))
      end)
    end

    IO.puts("╚═#{border_h}═╝")
    :ok
  end

  # ── RWC calculation ─────────────────────────────────────────────────────────

  @spec compute_rwc([file_audit()]) :: float()
  defp compute_rwc(audits) do
    weights = %{p0: 4.0, p1: 2.0, p2: 1.0, p3: 0.5}

    {weighted_pass, weighted_total} =
      Enum.reduce(audits, {0.0, 0.0}, fn audit, {pass_acc, total_acc} ->
        w = weights[audit.priority]
        pass = if audit.threshold_pass and audit.entropy_pass, do: w, else: 0.0
        {pass_acc + pass, total_acc + w}
      end)

    if weighted_total > 0,
      do: (weighted_pass / weighted_total * 100) |> Float.round(1),
      else: 0.0
  end

  # ── FSSI calculation ────────────────────────────────────────────────────────
  # Fractal Standard Score Index: composite of entropy, threshold, C8, and category balance

  @spec compute_fssi([file_audit()]) :: float()
  defp compute_fssi([]), do: 0.0

  defp compute_fssi(audits) do
    scores =
      Enum.map(audits, fn a ->
        max_entropy = :math.log(8) / :math.log(2)

        entropy_score = min(a.entropy / max_entropy, 1.0)

        threshold_score =
          if a.threshold_pass, do: 1.0, else: a.feature_count / max(a.threshold, 1)

        c8_score = a.c8_dual_coverage
        cats_present = length(a.categories_present) / 8.0

        # Weighted composite
        0.25 * entropy_score +
          0.35 * threshold_score +
          0.25 * c8_score +
          0.15 * cats_present
      end)

    (Enum.sum(scores) / length(scores)) |> Float.round(3)
  end

  # ── Weighted CCM per SC-MATH-COV-003 ────────────────────────────────────

  @spec compute_ccm_weighted(%{(1..8) => non_neg_integer()}, String.t()) :: float()
  defp compute_ccm_weighted(cat_dist, content) do
    # C1, C2, C3, C8 always apply; C4-C7 apply based on page content
    applicable = [1, 2, 3, 8] ++ applicable_optional_categories(content)

    {weighted_sum, weight_sum} =
      Enum.reduce(applicable, {0.0, 0.0}, fn c, {ws, wt} ->
        w = @ccm_weights[c]
        features = Map.get(cat_dist, c, 0)
        min_exp = @ccm_expected_min[c]
        coverage = min(features / max(min_exp, 1), 1.0)
        {ws + w * coverage, wt + w}
      end)

    if weight_sum > 0, do: Float.round(weighted_sum / weight_sum, 4), else: 0.0
  end

  @spec applicable_optional_categories(String.t()) :: [4..7]
  defp applicable_optional_categories(content) do
    optional = [
      {4, ~r/timeline|history|ordered.*event|chronolog/i},
      {5, ~r/form|textarea|submit|fill_in|phx-submit|phx-change/i},
      {6, ~r/chart|svg|video|media|play|external.*link/i},
      {7, ~r/AI|advisory|copilot|insight|recommendation|confidence/i}
    ]

    Enum.flat_map(optional, fn {c, pattern} ->
      if Regex.match?(pattern, content), do: [c], else: []
    end)
  end

  # ── FSI (Fractal Self-Similarity Index) per SC-MATH-COV-005 ────────────

  @spec compute_fsi([file_audit()]) :: float()
  defp compute_fsi(audits) do
    # Only include files with ≥10 features (per AOR-MATH-COV-006)
    entropies =
      audits
      |> Enum.filter(&(&1.feature_count >= 10))
      |> Enum.map(& &1.entropy)

    case entropies do
      [] ->
        0.0

      [_] ->
        1.0

      _ ->
        mu = Enum.sum(entropies) / length(entropies)

        if mu == 0.0 do
          0.0
        else
          variance =
            entropies
            |> Enum.map(fn h -> (h - mu) * (h - mu) end)
            |> Enum.sum()
            |> Kernel./(length(entropies))

          sigma = :math.sqrt(variance)
          Float.round(1.0 - sigma / mu, 4)
        end
    end
  end

  # ── ITQS enrichment per SC-MATH-COV-007 ────────────────────────────────

  @spec enrich_with_itqs([file_audit()], float()) :: [file_audit()]
  defp enrich_with_itqs(audits, fsi) do
    Enum.map(audits, fn a ->
      h_norm = if a.feature_count > 0, do: a.entropy / @max_entropy, else: 0.0

      itqs =
        @itqs_alpha * h_norm +
          @itqs_beta * a.ccm_weighted +
          @itqs_gamma * (1.0 - a.d_ea) +
          @itqs_delta * fsi

      %{a | itqs: Float.round(itqs, 4), fsi: Float.round(fsi, 4)}
    end)
  end

  @spec itqs_grade(float()) :: String.t()
  defp itqs_grade(itqs) when itqs >= 0.90, do: "A"
  defp itqs_grade(itqs) when itqs >= 0.85, do: "B"
  defp itqs_grade(itqs) when itqs >= 0.75, do: "C"
  defp itqs_grade(_itqs), do: "D"

  # ── Missing LiveView detection ──────────────────────────────────────────────

  @spec find_missing_test_files() :: [String.t()]
  defp find_missing_test_files do
    live_sources =
      @live_roots
      |> Enum.flat_map(fn root ->
        case File.ls(root) do
          {:ok, entries} ->
            entries
            |> Enum.filter(&String.ends_with?(&1, "_live.ex"))
            |> Enum.map(&String.replace(&1, "_live.ex", "_live_wallaby_test.exs"))

          {:error, _} ->
            []
        end
      end)
      |> Enum.uniq()

    existing_tests =
      collect_wallaby_files()
      |> Enum.map(&Path.basename/1)
      |> MapSet.new()

    Enum.reject(live_sources, &MapSet.member?(existing_tests, &1))
  end

  # ── JSON output ─────────────────────────────────────────────────────────────

  @spec output_json([file_audit()]) :: :ok
  defp output_json(audits) do
    payload =
      audits
      |> Enum.map(fn a ->
        %{
          file: a.basename,
          path: a.path,
          feature_count: a.feature_count,
          categories_present: a.categories_present,
          category_distribution: Map.new(a.category_distribution, fn {k, v} -> {"c#{k}", v} end),
          entropy: a.entropy,
          entropy_pass: a.entropy_pass,
          c8_dual_coverage: Float.round(a.c8_dual_coverage, 3),
          c8_buttons: a.c8_buttons,
          c8_flash: a.c8_flash,
          c8_status: a.c8_status,
          missing_flash_buttons: a.missing_flash_buttons,
          priority: a.priority,
          threshold: a.threshold,
          threshold_pass: a.threshold_pass,
          untested_events: a.untested_events,
          untested_phx_clicks: a.untested_phx_clicks,
          recommendations: a.recommendations,
          fssi: compute_fssi([a]),
          d_ea: a.d_ea,
          ccm_weighted: a.ccm_weighted,
          itqs: a.itqs,
          itqs_grade: itqs_grade(a.itqs),
          fsi: a.fsi
        }
      end)

    json = encode_json(payload)
    IO.puts(json)
    :ok
  end

  # ── Minimal JSON encoder (no Jason dependency required) ─────────────────────

  @spec encode_json(term()) :: String.t()
  defp encode_json(value) do
    cond do
      is_map(value) ->
        pairs =
          value
          |> Enum.map(fn {k, val} ->
            ~s("#{k}": #{encode_json(val)})
          end)
          |> Enum.join(", ")

        "{#{pairs}}"

      is_list(value) ->
        items = Enum.map(value, &encode_json/1) |> Enum.join(", ")
        "[#{items}]"

      is_binary(value) ->
        escaped = String.replace(value, "\"", "\\\"")
        ~s("#{escaped}")

      value == true ->
        "true"

      value == false ->
        "false"

      is_nil(value) ->
        "null"

      is_atom(value) ->
        ~s("#{value}")

      is_float(value) ->
        to_string(Float.round(value, 4))

      is_integer(value) ->
        to_string(value)

      true ->
        ~s("#{inspect(value)}")
    end
  end

  # ── Formatting helpers ──────────────────────────────────────────────────────

  @spec pad(non_neg_integer(), pos_integer()) :: String.t()
  defp pad(n, width), do: n |> to_string() |> String.pad_leading(width)

  @spec pct(non_neg_integer(), non_neg_integer()) :: String.t()
  defp pct(_n, 0), do: "  N/A"

  defp pct(n, total) do
    (n / total * 100)
    |> Float.round(1)
    |> to_string()
    |> Kernel.<>("%")
    |> String.pad_leading(6)
  end
end
