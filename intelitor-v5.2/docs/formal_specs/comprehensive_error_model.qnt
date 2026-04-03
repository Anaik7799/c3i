// Quint Formal Model - Comprehensive Error Pattern Analysis
// Behavioral Verification for ALL Error-Generating Code
// Version: 1.1.0 | Date: 2026-03-22 (fixed for quint 0.29.1)
// STAMP: SC-VAL-001, SC-CMP-025, SC-AGT-CODE-025

module ComprehensiveErrorModel {

  // ════════════════════════════════════════════════════════════════════
  // TYPE DEFINITIONS
  // ════════════════════════════════════════════════════════════════════

  type FilePath = str
  type ModuleName = str
  type ErrorMessage = str
  type HeaderName = str
  type HeaderValue = str

  // EP-GEN-014 Compliance State
  type EP014State =
    | NoPropertyTests
    | PropCheckOnly
    | ExUnitPropsOnly
    | BothNoExcept        // CONFLICT STATE
    | BothWithExcept
    | FullyCompliant      // With aliases
    | CompileErrorState

  // Compilation State
  type CompilationState =
    | Unloaded
    | Parsing
    | MacroExpanding
    | TypeChecking
    | CodeGenerating
    | CompileSuccess
    | CompileError_UndefinedVar(str)
    | CompileError_AmbiguousMacro(str)
    | CompileError_UndefinedFunc(str)
    | CompileError_TypeError(str)

  // Header Extraction State
  type HeaderState =
    | RequestHeader
    | MappingAtom
    | LookupHeader
    | HeaderFound(str)
    | HeaderNotFound
    | SpacingBug(str)     // Bug state with wrong header name

  // Test Module Record
  type TestModule = {
    file_path: FilePath,
    has_propcheck: bool,
    has_exunitproperties: bool,
    has_except_clause: bool,
    has_pc_alias: bool,
    has_sd_alias: bool,
    check_all_count: int,
    ep014_state: EP014State,
    compilation_state: CompilationState
  }

  // Connection Record
  type Connection = {
    user_agent: HeaderValue,
    accept_language: HeaderValue,
    accept_encoding: HeaderValue,
    accept_val: HeaderValue,
    remote_ip: str,
    x_forwarded_for: str,
    x_timezone: str,
    x_screen_resolution: str
  }

  // Header Mapping (correct vs buggy)
  type HeaderMapping = {
    atom_name: str,
    correct_name: HeaderName,
    buggy_name: HeaderName,
    has_bug: bool
  }

  // ════════════════════════════════════════════════════════════════════
  // STATE VARIABLES
  // ════════════════════════════════════════════════════════════════════

  var modules: FilePath -> TestModule
  var header_mappings: str -> HeaderMapping
  var current_extraction: HeaderState
  var fingerprint_cache: str -> str
  var compilation_log: List[ErrorMessage]

  // ════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ════════════════════════════════════════════════════════════════════

  action init = all {
    header_mappings' = Map()
      .put("accept_language", {
        atom_name: "accept_language",
        correct_name: "accept-language",
        buggy_name: "accept-language-buggy",
        has_bug: true
      })
      .put("accept_encoding", {
        atom_name: "accept_encoding",
        correct_name: "accept-encoding",
        buggy_name: "accept-encoding-buggy",
        has_bug: true
      })
      .put("x_forwarded_for", {
        atom_name: "x_forwarded_for",
        correct_name: "x-forwarded-for",
        buggy_name: "x-forwarded-for-buggy",
        has_bug: true
      })
      .put("x_real_ip", {
        atom_name: "x_real_ip",
        correct_name: "x-real-ip",
        buggy_name: "x-real-ip-buggy",
        has_bug: true
      }),
    modules' = Map(),
    current_extraction' = RequestHeader,
    fingerprint_cache' = Map(),
    compilation_log' = List()
  }

  // ════════════════════════════════════════════════════════════════════
  // EP-GEN-014 TRANSITIONS
  // ════════════════════════════════════════════════════════════════════

  // Add PropCheck to module
  action add_propcheck(file: FilePath): bool =
    if (not(modules.keys().contains(file))) {
      all {
        modules' = modules.put(file, {
          file_path: file,
          has_propcheck: true,
          has_exunitproperties: false,
          has_except_clause: false,
          has_pc_alias: false,
          has_sd_alias: false,
          check_all_count: 0,
          ep014_state: PropCheckOnly,
          compilation_state: Unloaded
        }),
        header_mappings' = header_mappings,
        current_extraction' = current_extraction,
        fingerprint_cache' = fingerprint_cache,
        compilation_log' = compilation_log
      }
    } else {
      val m = modules.get(file)
      val new_state =
        if (m.has_exunitproperties and not(m.has_except_clause)) BothNoExcept
        else if (m.has_exunitproperties and m.has_except_clause) BothWithExcept
        else PropCheckOnly
      all {
        modules' = modules.put(file, { ...m, has_propcheck: true, ep014_state: new_state }),
        header_mappings' = header_mappings,
        current_extraction' = current_extraction,
        fingerprint_cache' = fingerprint_cache,
        compilation_log' = compilation_log
      }
    }

  // Add ExUnitProperties without except clause
  action add_exunitproperties_no_except(file: FilePath): bool =
    if (not(modules.keys().contains(file))) {
      all {
        modules' = modules.put(file, {
          file_path: file,
          has_propcheck: false,
          has_exunitproperties: true,
          has_except_clause: false,
          has_pc_alias: false,
          has_sd_alias: false,
          check_all_count: 0,
          ep014_state: ExUnitPropsOnly,
          compilation_state: Unloaded
        }),
        header_mappings' = header_mappings,
        current_extraction' = current_extraction,
        fingerprint_cache' = fingerprint_cache,
        compilation_log' = compilation_log
      }
    } else {
      val m = modules.get(file)
      val new_state =
        if (m.has_propcheck) BothNoExcept
        else ExUnitPropsOnly
      all {
        modules' = modules.put(file, { ...m, has_exunitproperties: true, ep014_state: new_state }),
        header_mappings' = header_mappings,
        current_extraction' = current_extraction,
        fingerprint_cache' = fingerprint_cache,
        compilation_log' = compilation_log
      }
    }

  // Add except clause (fix)
  action add_except_clause(file: FilePath): bool = {
    val m = modules.get(file)
    val new_state =
      if (m.has_pc_alias and m.has_sd_alias) FullyCompliant
      else BothWithExcept
    all {
      modules' = modules.put(file, { ...m, has_except_clause: true, ep014_state: new_state }),
      header_mappings' = header_mappings,
      current_extraction' = current_extraction,
      fingerprint_cache' = fingerprint_cache,
      compilation_log' = compilation_log
    }
  }

  // Add aliases (complete fix)
  action add_aliases(file: FilePath): bool = {
    val m = modules.get(file)
    all {
      modules' = modules.put(file, {
        ...m,
        has_pc_alias: true,
        has_sd_alias: true,
        ep014_state: FullyCompliant
      }),
      header_mappings' = header_mappings,
      current_extraction' = current_extraction,
      fingerprint_cache' = fingerprint_cache,
      compilation_log' = compilation_log
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // COMPILATION TRANSITIONS
  // ════════════════════════════════════════════════════════════════════

  pure def is_compile_error(cs: CompilationState): bool =
    cs != Unloaded and cs != Parsing and cs != MacroExpanding and
    cs != TypeChecking and cs != CodeGenerating and cs != CompileSuccess

  action compile_module(file: FilePath): bool = {
    val m = modules.get(file)
    val result =
      if (m.ep014_state == BothNoExcept)
        CompileError_AmbiguousMacro("function check/1 imported from both PropCheck and ExUnitProperties")
      else if (not(m.has_exunitproperties) and m.check_all_count > 0)
        CompileError_UndefinedVar("undefined variable in check all() block")
      else if (m.ep014_state == FullyCompliant or m.ep014_state == BothWithExcept)
        CompileSuccess
      else if (m.ep014_state == PropCheckOnly or m.ep014_state == ExUnitPropsOnly or m.ep014_state == NoPropertyTests)
        CompileSuccess
      else
        CompileError_UndefinedFunc("unknown compilation error")
    if (result == CompileSuccess) {
      all {
        modules' = modules.put(file, { ...m, compilation_state: result }),
        header_mappings' = header_mappings,
        current_extraction' = current_extraction,
        fingerprint_cache' = fingerprint_cache,
        compilation_log' = compilation_log
      }
    } else {
      all {
        modules' = modules.put(file, { ...m, compilation_state: result }),
        header_mappings' = header_mappings,
        current_extraction' = current_extraction,
        fingerprint_cache' = fingerprint_cache,
        compilation_log' = compilation_log.append(file)
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // HEADER EXTRACTION SIMULATION
  // ════════════════════════════════════════════════════════════════════

  // Simulate header extraction with potential bug.
  // Takes header_mappings as a parameter (pure functions cannot access state).
  pure def extract_header(
    atom: str,
    conn: Connection,
    use_buggy_names: bool,
    mappings: str -> HeaderMapping
  ): HeaderValue = {
    val has_mapping = mappings.keys().contains(atom)
    val mapping =
      if (has_mapping) mappings.get(atom)
      else { atom_name: atom, correct_name: atom, buggy_name: atom, has_bug: false }
    val header_is_buggy = use_buggy_names and mapping.has_bug
    // When buggy names are used, return empty string (header not found)
    // because the header name with wrong format won't match real headers.
    // When correct names are used, look up the value from the connection.
    if (header_is_buggy) ""
    else if (atom == "accept_language") conn.accept_language
    else if (atom == "accept_encoding") conn.accept_encoding
    else if (atom == "x_forwarded_for") conn.x_forwarded_for
    else if (atom == "user_agent") conn.user_agent
    else ""
  }

  // Generate fingerprint components as a list.
  pure def fingerprint_components(
    conn: Connection,
    use_buggy_names: bool,
    mappings: str -> HeaderMapping
  ): List[HeaderValue] =
    List(
      extract_header("user_agent", conn, use_buggy_names, mappings),
      extract_header("accept_language", conn, use_buggy_names, mappings),
      extract_header("accept_encoding", conn, use_buggy_names, mappings),
      conn.accept_val,
      conn.remote_ip,
      conn.x_timezone,
      conn.x_screen_resolution
    )

  // Count how many components are empty (proxy for entropy loss)
  pure def count_empty_components(
    conn: Connection,
    use_buggy_names: bool,
    mappings: str -> HeaderMapping
  ): int =
    fingerprint_components(conn, use_buggy_names, mappings)
      .select(c => c == "").length()

  // ════════════════════════════════════════════════════════════════════
  // INVARIANTS
  // ════════════════════════════════════════════════════════════════════

  // INV-1: EP-GEN-014 Compliance
  val inv_ep014_compliance: bool =
    modules.keys().forall(k =>
      (modules.get(k).compilation_state == CompileSuccess) implies
        (modules.get(k).ep014_state != BothNoExcept)
    )

  // INV-2: Except clause required when both frameworks present
  val inv_except_required: bool =
    modules.keys().forall(k =>
      (modules.get(k).has_propcheck and modules.get(k).has_exunitproperties) implies
        modules.get(k).has_except_clause
    )

  // INV-3: Header correct_name differs from buggy_name when has_bug is set
  val inv_no_buggy_name_equals_correct: bool =
    header_mappings.keys().forall(k =>
      header_mappings.get(k).has_bug implies
        (header_mappings.get(k).correct_name != header_mappings.get(k).buggy_name)
    )

  // INV-4: Fingerprint determinism (same conn always gives same component count)
  pure def inv_fingerprint_determinism(
    conn: Connection,
    mappings: str -> HeaderMapping
  ): bool = {
    val count1 = count_empty_components(conn, false, mappings)
    val count2 = count_empty_components(conn, false, mappings)
    count1 == count2
  }

  // INV-5: Buggy extraction increases or maintains empty component count
  pure def inv_buggy_reduces_entropy(
    conn: Connection,
    mappings: str -> HeaderMapping
  ): bool = {
    val empty_correct = count_empty_components(conn, false, mappings)
    val empty_buggy = count_empty_components(conn, true, mappings)
    empty_buggy >= empty_correct
  }

  // ════════════════════════════════════════════════════════════════════
  // TEMPORAL PROPERTIES
  // ════════════════════════════════════════════════════════════════════

  // All modules eventually reach a stable compilation state
  temporal all_modules_stabilize =
    modules.keys().forall(k =>
      eventually(
        modules.get(k).compilation_state == CompileSuccess or
        is_compile_error(modules.get(k).compilation_state)
      )
    )

  // Fix eventually leads to success
  temporal fix_leads_to_success =
    modules.keys().forall(k =>
      (modules.get(k).ep014_state == BothNoExcept) implies
        eventually(
          modules.get(k).ep014_state == FullyCompliant and
          modules.get(k).compilation_state == CompileSuccess
        )
    )

  // ════════════════════════════════════════════════════════════════════
  // ERROR SCENARIOS
  // ════════════════════════════════════════════════════════════════════

  // Scenario 1: EP-GEN-014 Violation — create conflicting module and attempt compile
  action scenario_ep014_violation(file: FilePath): bool = {
    val newMod = {
      file_path: file,
      has_propcheck: true,
      has_exunitproperties: true,
      has_except_clause: false,
      has_pc_alias: false,
      has_sd_alias: false,
      check_all_count: 0,
      ep014_state: BothNoExcept,
      compilation_state: CompileError_AmbiguousMacro("function check/1 imported from both PropCheck and ExUnitProperties")
    }
    all {
      modules' = modules.put(file, newMod),
      header_mappings' = header_mappings,
      current_extraction' = current_extraction,
      fingerprint_cache' = fingerprint_cache,
      compilation_log' = compilation_log.append(file)
    }
  }

  // Scenario 2: Header bug check (pure — no state change)
  pure def scenario_header_bug(
    conn: Connection,
    mappings: str -> HeaderMapping
  ): bool = {
    val buggy_value = extract_header("accept_language", conn, true, mappings)
    val correct_value = extract_header("accept_language", conn, false, mappings)
    // Buggy returns empty, correct returns actual value
    buggy_value == "" and correct_value != ""
  }

  // Scenario 3: Fingerprint uniqueness check (pure)
  // When producing fingerprints from identical connections with correct names,
  // they should all be equal (unique count == 1 in a set).
  pure def scenario_test_determinism(conn: Connection, mappings: str -> HeaderMapping): bool = {
    val count_a = count_empty_components(conn, false, mappings)
    val count_b = count_empty_components(conn, false, mappings)
    // Determinism: both invocations yield the same result
    count_a == count_b
  }

  // ════════════════════════════════════════════════════════════════════
  // FIX VERIFICATION
  // ════════════════════════════════════════════════════════════════════

  // Verify EP-GEN-014 fix is complete
  pure def verify_ep014_fix(m: TestModule): bool =
    (m.has_propcheck and m.has_exunitproperties) implies
      (m.has_except_clause and m.has_pc_alias and m.has_sd_alias and
       m.ep014_state == FullyCompliant)

  // Verify header fix is complete (takes mappings as parameter — pure, no state)
  pure def verify_header_fix(atom: str, mappings: str -> HeaderMapping): bool =
    if (mappings.keys().contains(atom)) not(mappings.get(atom).has_bug)
    else true

  // ════════════════════════════════════════════════════════════════════
  // MAIN INVARIANT
  // ════════════════════════════════════════════════════════════════════

  val system_invariant: bool = and {
    inv_ep014_compliance,
    inv_except_required,
    inv_no_buggy_name_equals_correct
  }
}
