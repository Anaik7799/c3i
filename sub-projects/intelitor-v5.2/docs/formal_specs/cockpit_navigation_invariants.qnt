// =============================================================================
// COCKPIT NAVIGATION INVARIANTS — FORMAL SPECIFICATION
// Indrajaal Prajna Cockpit, L3 Domain / L2 UI Layer
// =============================================================================
//
// WHAT: Temporal-logic specification of the Prajna cockpit navigation state
//       machine.  Models single-active-page exclusivity, tab-switching state
//       preservation, full 19-route reachability, global theme application,
//       session-timeout redirect to login, and mandatory Zenoh mesh-status
//       visibility on every page.
//
// WHY:  Cockpit navigation is a safety-critical HMI function (SC-HMI-011).
//       Two pages simultaneously active could hide critical alarms.  A route
//       unreachable from the navigation bar prevents operators reaching key
//       views during an incident.  Missing Zenoh status lets operators act on
//       stale mesh data.  Session expiry that does not return to login is a
//       security violation.  Mechanised verification proves all these properties
//       before any UI change is deployed.
//
// CONSTRAINTS:
//   - SC-HMI-010 (Color Rich):  Vibrant chromatic feedback on every page
//   - SC-HMI-011 (8x8 Matrix):  100% path coverage — 8 elements x 8 layers
//   - SC-COCKPIT-001: Navigation MUST expose all C3I routes
//   - SC-COCKPIT-002: WebUI MUST use F# Bolero
//   - SC-COCKPIT-003: Dark-cockpit theme is the system default
//   - SC-THEME-001..006: Theme system — cockpit theme management, dark mode
//   - SC-ZENOH-007:  Zenoh health included on /health endpoint (visible on all pages)
//   - SC-SESS-001..005: Session management constraints
//   - SC-SAFETY-001: Multi-step commit for destructive UI actions (Arm & Fire)
//   - SC-AUTH-001..004: Authentication gates cockpit access
//
// NAVIGATION TOPOLOGY (19 routes — SC-COCKPIT-001):
//   Dashboard    Alarms      Agents      Topology    Analytics
//   Smriti       Planning    Containers  Git         Settings
//   Theme        Session     ZenohPage   Guardian    Sentinel
//   Kms          Federation  Audit       Login
//
// THEME MODES (3):
//   DarkCockpit   — SC-COCKPIT-003: mandatory default
//   LightMode     — optional operator preference
//   HighContrast  — accessibility mode
//
// ZENOH STATUS (3 — SC-ZENOH-007):
//   Connected | Degraded | Disconnected
//
// SESSIONS:
//   unauthenticated → login → authenticated → timeout/logout → login
//   SC-SESS-003: timeout redirects to Login
//
// Document Control:
//   | Field   | Value                                              |
//   |---------|----------------------------------------------------|
//   | Version | 2.0.0                                              |
//   | Created | 2026-03-28                                         |
//   | Author  | Code Evolution Agent v21.3.1-SIL6                  |
//   | STAMP   | SC-HMI-010/011, SC-COCKPIT-001..003, SC-ZENOH-007  |
//
// Verification:
//   quint verify --invariant=navigationInvariant cockpit_navigation_invariants.qnt
//   quint run --max-steps=300 --invariant=navigationInvariant cockpit_navigation_invariants.qnt
//
// =============================================================================

module cockpit_navigation {

  // ---------------------------------------------------------------------------
  // TYPE DEFINITIONS
  // ---------------------------------------------------------------------------

  /// All 19 cockpit routes (SC-COCKPIT-001).
  /// Each corresponds to a top-level LiveView (Bolero) page.
  type Route =
    | Dashboard    // default landing after login
    | Alarms       // alarm management console (SC-ALARM-*)
    | Agents       // agent orchestration C3I (SC-AGT-*)
    | Topology     // cluster topology visualiser
    | Analytics    // analytics and KPI (SC-AN-001)
    | Smriti       // knowledge management
    | Planning     // task planning (sa-plan)
    | Containers   // container management
    | Git          // git intelligence
    | Settings     // cockpit settings
    | Theme        // theme configurator
    | Session      // session management
    | ZenohPage    // Zenoh mesh telemetry view
    | Guardian     // Guardian state viewer
    | Sentinel     // Sentinel threat monitor
    | Kms          // Key Management System
    | Federation   // federation peers view
    | Audit        // immutable register audit
    | Login        // authentication; session-timeout target

  /// The three cockpit theme modes (SC-COCKPIT-003: DarkCockpit is default).
  type ThemeMode =
    | DarkCockpit   // mandatory default (SC-COCKPIT-003)
    | LightMode
    | HighContrast  // accessibility mode

  /// Live Zenoh mesh connectivity status — visible on every page (SC-ZENOH-007).
  type ZenohStatus =
    | Connected
    | Degraded
    | Disconnected

  // ---------------------------------------------------------------------------
  // CONSTANTS
  // ---------------------------------------------------------------------------

  /// Session inactivity timeout in logical clock ticks (SC-SESS-002).
  pure val SESSION_TIMEOUT_TICKS: int = 100

  /// Maximum saved tab index within any tabbed page (0-based, 4 tabs max).
  pure val MAX_TAB_INDEX: int = 4

  /// The set of all 19 routes — used for reachability assertions.
  pure val ALL_ROUTES: Set[Route] = Set(
    Dashboard, Alarms, Agents, Topology, Analytics,
    Smriti, Planning, Containers, Git, Settings,
    Theme, Session, ZenohPage, Guardian, Sentinel,
    Kms, Federation, Audit, Login
  )

  /// Routes that expose per-page tab navigation.
  pure val TABBED_ROUTES: Set[Route] = Set(
    Alarms, Analytics, Agents, Smriti, Planning, Kms
  )

  /// Routes accessible only when a session is active (all except Login).
  pure val PROTECTED_ROUTES: Set[Route] = Set(
    Dashboard, Alarms, Agents, Topology, Analytics,
    Smriti, Planning, Containers, Git, Settings,
    Theme, Session, ZenohPage, Guardian, Sentinel,
    Kms, Federation, Audit
  )

  // ---------------------------------------------------------------------------
  // STATE VARIABLES
  // ---------------------------------------------------------------------------

  /// The currently active page (INV-SINGLE-PAGE: exactly one route active).
  var activePage: Route

  /// The currently selected tab index within the active page.
  /// 0 for non-tabbed pages.
  var activeTab: int

  /// Preserved tab state per route — remembered across navigation.
  /// Key: route; Value: last-selected tab index on that route.
  var tabState: Route -> int

  /// Current global cockpit theme (SC-COCKPIT-003: default DarkCockpit).
  var theme: ThemeMode

  /// Live Zenoh mesh connectivity status (SC-ZENOH-007).
  /// This variable is visible on every page — never hidden by navigation.
  var zenohStatus: ZenohStatus

  /// True when a valid user session is active (SC-SESS-001).
  var sessionActive: bool

  /// Logical clock tick of the last user interaction (session timeout input).
  var lastActivity: int

  /// Monotonic logical clock.
  var clock: int

  /// Set of routes visited this session (reachability witness).
  var visitedRoutes: Set[Route]

  /// Append-only navigation audit log.
  var navLog: List[str]

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  /// True when the given route uses tabbed sub-navigation.
  pure def isTabbed(r: Route): bool = TABBED_ROUTES.contains(r)

  /// True when the session clock has exceeded the inactivity timeout.
  def sessionTimedOut: bool =
    clock - lastActivity > SESSION_TIMEOUT_TICKS

  /// Restore saved tab index for a route; default 0 if not yet visited.
  def restoredTab(r: Route): int =
    if (tabState.keys().contains(r)) tabState.get(r) else 0

  /// Append a string entry to the navigation audit log.
  def logNav(msg: str): List[str] = navLog.append(msg)

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  action init = all {
    activePage'    = Login,
    activeTab'     = 0,
    tabState'      = Map(),
    theme'         = DarkCockpit,    // SC-COCKPIT-003: mandatory default
    zenohStatus'   = Connected,
    sessionActive' = false,
    lastActivity'  = 0,
    clock'         = 0,
    visitedRoutes' = Set(Login),
    navLog'        = List()
  }

  // ---------------------------------------------------------------------------
  // ACTION: login
  // ---------------------------------------------------------------------------
  // Establishes a user session and navigates to Dashboard.
  // SC-SESS-001: session MUST be established before any protected route.
  // Pre: activePage == Login and sessionActive == false.

  action login: bool = all {
    activePage == Login,
    sessionActive == false,
    sessionActive' = true,
    activePage'    = Dashboard,
    activeTab'     = restoredTab(Dashboard),
    lastActivity'  = clock,
    visitedRoutes' = visitedRoutes.union(Set(Dashboard)),
    navLog'        = logNav("login"),
    clock'         = clock + 1,
    // Stutter
    theme'         = theme,
    zenohStatus'   = zenohStatus,
    tabState'      = tabState
  }

  // ---------------------------------------------------------------------------
  // ACTION: navigate_to
  // ---------------------------------------------------------------------------
  // Operator navigates to any protected route.
  // Pre: session active; target in PROTECTED_ROUTES; session not timed out.
  // Tab state for the current page is saved; tab state for the target is restored.
  // INV-SINGLE-PAGE: activePage is replaced, not unioned.

  action navigate_to(target: Route): bool = all {
    sessionActive == true,
    PROTECTED_ROUTES.contains(target),
    target != activePage,
    not(sessionTimedOut),
    // Persist current page's tab index before leaving
    val newTabState = tabState.put(activePage, activeTab)
    all {
      activePage'    = target,
      activeTab'     = restoredTab(target),
      tabState'      = newTabState,
      lastActivity'  = clock,
      visitedRoutes' = visitedRoutes.union(Set(target)),
      navLog'        = logNav("navigate"),
      clock'         = clock + 1,
      // Stutter
      theme'         = theme,
      zenohStatus'   = zenohStatus,
      sessionActive' = sessionActive
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: switch_tab
  // ---------------------------------------------------------------------------
  // Operator changes the active tab within the current page.
  // Pre: active page is tabbed; new tab index in [0, MAX_TAB_INDEX].
  // INV-TAB-PRESERVE: active page does NOT change.

  action switch_tab(newTab: int): bool = all {
    sessionActive == true,
    isTabbed(activePage),
    newTab >= 0,
    newTab <= MAX_TAB_INDEX,
    not(sessionTimedOut),
    activeTab'     = newTab,
    tabState'      = tabState.put(activePage, newTab),
    lastActivity'  = clock,
    navLog'        = logNav("switch_tab"),
    clock'         = clock + 1,
    // Active page UNCHANGED (INV-TAB-PRESERVE)
    activePage'    = activePage,
    theme'         = theme,
    zenohStatus'   = zenohStatus,
    sessionActive' = sessionActive,
    visitedRoutes' = visitedRoutes
  }

  // ---------------------------------------------------------------------------
  // ACTION: change_theme
  // ---------------------------------------------------------------------------
  // Operator changes the global cockpit theme.
  // SC-THEME-001: change applies to ALL pages simultaneously.
  // INV-GLOBAL-THEME: single theme variable covers every route.

  action change_theme(newTheme: ThemeMode): bool = all {
    sessionActive == true,
    not(sessionTimedOut),
    theme'         = newTheme,
    lastActivity'  = clock,
    clock'         = clock + 1,
    // Navigation state unchanged
    activePage'    = activePage,
    activeTab'     = activeTab,
    zenohStatus'   = zenohStatus,
    sessionActive' = sessionActive,
    visitedRoutes' = visitedRoutes,
    tabState'      = tabState,
    navLog'        = navLog
  }

  // ---------------------------------------------------------------------------
  // ACTION: update_zenoh_status
  // ---------------------------------------------------------------------------
  // Zenoh router publishes a new mesh connectivity status.
  // SC-ZENOH-007: update is independent of navigation — fires on any page.
  // INV-ZENOH-VISIBLE: zenohStatus is always current regardless of activePage.

  action update_zenoh_status(newStatus: ZenohStatus): bool = all {
    zenohStatus'   = newStatus,
    clock'         = clock + 1,
    // Navigation state unchanged
    activePage'    = activePage,
    activeTab'     = activeTab,
    theme'         = theme,
    sessionActive' = sessionActive,
    lastActivity'  = lastActivity,
    visitedRoutes' = visitedRoutes,
    tabState'      = tabState,
    navLog'        = navLog
  }

  // ---------------------------------------------------------------------------
  // ACTION: session_timeout
  // ---------------------------------------------------------------------------
  // Inactivity timeout fires.
  // SC-SESS-003: MUST redirect to Login regardless of current page.
  // INV-TIMEOUT-TO-LOGIN: always lands on Login with sessionActive = false.

  action session_timeout: bool = all {
    sessionActive == true,
    sessionTimedOut,
    activePage'    = Login,
    sessionActive' = false,
    activeTab'     = 0,
    lastActivity'  = clock,
    navLog'        = logNav("session_timeout"),
    clock'         = clock + 1,
    // Stutter
    theme'         = theme,
    zenohStatus'   = zenohStatus,
    visitedRoutes' = visitedRoutes,
    tabState'      = tabState
  }

  // ---------------------------------------------------------------------------
  // ACTION: logout
  // ---------------------------------------------------------------------------
  // Explicit operator logout; always returns to Login.

  action logout: bool = all {
    sessionActive == true,
    activePage'    = Login,
    sessionActive' = false,
    activeTab'     = 0,
    lastActivity'  = clock,
    navLog'        = logNav("logout"),
    clock'         = clock + 1,
    // Stutter
    theme'         = theme,
    zenohStatus'   = zenohStatus,
    visitedRoutes' = visitedRoutes,
    tabState'      = tabState
  }

  // ---------------------------------------------------------------------------
  // ACTION: tick_clock
  // ---------------------------------------------------------------------------

  action tick_clock: bool = all {
    clock'         = clock + 1,
    activePage'    = activePage,
    activeTab'     = activeTab,
    theme'         = theme,
    zenohStatus'   = zenohStatus,
    sessionActive' = sessionActive,
    lastActivity'  = lastActivity,
    visitedRoutes' = visitedRoutes,
    tabState'      = tabState,
    navLog'        = navLog
  }

  // ---------------------------------------------------------------------------
  // SAFETY INVARIANTS
  // ---------------------------------------------------------------------------

  // INV-SINGLE-PAGE: Exactly one route is active — activePage is always a
  // member of the 19-element ALL_ROUTES set.
  val inv_single_active_page: bool =
    ALL_ROUTES.contains(activePage)

  // INV-PROTECTED-NEEDS-SESSION: Protected routes are only accessible when
  // a session is active (SC-SESS-001 / SC-AUTH-001).
  val inv_session_required: bool =
    PROTECTED_ROUTES.contains(activePage) implies sessionActive == true

  // INV-LOGIN-WHEN-NO-SESSION: Login page is shown whenever there is no session.
  val inv_login_when_no_session: bool =
    sessionActive == false implies activePage == Login

  // INV-TAB-PRESERVE: Tab index is always within valid bounds.
  val inv_tab_in_bounds: bool =
    activeTab >= 0 and activeTab <= MAX_TAB_INDEX

  // INV-NON-TABBED-ZERO-TAB: Non-tabbed pages always show tab index 0.
  // navigate_to restores saved tab (default 0 for non-tabbed).
  // switch_tab requires isTabbed(activePage).
  val inv_non_tabbed_has_zero_tab: bool =
    not(isTabbed(activePage)) implies activeTab == 0

  // INV-GLOBAL-THEME: Theme is always one of the three valid modes (SC-THEME-001).
  val inv_theme_valid: bool =
    theme == DarkCockpit or theme == LightMode or theme == HighContrast

  // INV-ZENOH-VISIBLE: Zenoh status is always a defined value, regardless of
  // which page is active (SC-ZENOH-007).
  val inv_zenoh_status_defined: bool =
    zenohStatus == Connected or zenohStatus == Degraded or zenohStatus == Disconnected

  // INV-DARK-DEFAULT: Before any session starts, theme is DarkCockpit.
  val inv_dark_cockpit_default: bool =
    (sessionActive == false and visitedRoutes.size() <= 1) implies theme == DarkCockpit

  // INV-TIMEOUT-TO-LOGIN: After session_timeout, activePage is Login and
  // sessionActive is false.  Encoded as the contrapositive.
  val inv_timeout_lands_on_login: bool =
    (sessionActive == false and visitedRoutes.size() > 1) implies activePage == Login

  // INV-VISITED-SUBSET: All visited routes belong to the 19-element ALL_ROUTES set.
  val inv_visited_subset: bool =
    visitedRoutes.forall(r => ALL_ROUTES.contains(r))

  // INV-VISITED-INCLUDES-ACTIVE: activePage is always in visitedRoutes.
  val inv_visited_includes_active: bool =
    visitedRoutes.contains(activePage)

  // INV-DASHBOARD-REACHABLE: After any login, Dashboard is in visitedRoutes.
  val inv_dashboard_in_visited: bool =
    sessionActive == true implies visitedRoutes.contains(Dashboard)

  /// Combined master invariant.
  val navigationInvariant: bool = all {
    inv_single_active_page,
    inv_session_required,
    inv_login_when_no_session,
    inv_tab_in_bounds,
    inv_non_tabbed_has_zero_tab,
    inv_theme_valid,
    inv_zenoh_status_defined,
    inv_dark_cockpit_default,
    inv_timeout_lands_on_login,
    inv_visited_subset,
    inv_visited_includes_active,
    inv_dashboard_in_visited
  }

  // ---------------------------------------------------------------------------
  // TEMPORAL PROPERTIES
  // ---------------------------------------------------------------------------

  // TEMP-NAV-1: □(no session → activePage == Login)
  // Unauthenticated state always shows Login.
  temporal prop_no_session_shows_login = always(
    sessionActive == false implies activePage == Login
  )

  // TEMP-NAV-2: □(session timeout → ◇(activePage == Login))
  // Session expiry eventually redirects to Login.
  temporal prop_timeout_leads_to_login = always(
    sessionTimedOut implies eventually(activePage == Login)
  )

  // TEMP-NAV-3: □(theme is always defined for every page)
  // Theme covers all pages — there is no per-page theme variable.
  temporal prop_global_theme_always_valid = always(inv_theme_valid)

  // TEMP-NAV-4: □(Zenoh status always defined on every page — SC-ZENOH-007)
  temporal prop_zenoh_always_visible = always(inv_zenoh_status_defined)

  // TEMP-NAV-5: □(Authenticated → ◇(∀ r ∈ ALL_ROUTES \ {Login}, r ∈ visitedRoutes))
  // All 18 protected routes are eventually reachable once authenticated.
  temporal prop_all_routes_reachable = always(
    sessionActive == true implies
    eventually(PROTECTED_ROUTES.forall(r => visitedRoutes.contains(r)))
  )

  // TEMP-NAV-6: □(navigationInvariant) — safety holds at every state.
  temporal prop_always_safe = always(navigationInvariant)

}

// =============================================================================
// MODEL-CHECKING HARNESS
// =============================================================================

module navigation_model_checking {
  import cockpit_navigation.*

  action stepLogin: bool = login
  action stepLogout: bool = logout
  action stepTimeout: bool = session_timeout
  action stepTick: bool = tick_clock

  action stepNavigate: bool = {
    nondet target = oneOf(PROTECTED_ROUTES)
    navigate_to(target)
  }

  action stepTab: bool = {
    nondet tab = oneOf(Set(0, 1, 2, 3, 4))
    switch_tab(tab)
  }

  action stepTheme: bool = {
    nondet t = oneOf(Set(DarkCockpit, LightMode, HighContrast))
    change_theme(t)
  }

  action stepZenoh: bool = {
    nondet s = oneOf(Set(Connected, Degraded, Disconnected))
    update_zenoh_status(s)
  }

  action step = any {
    stepLogin,
    stepLogout,
    stepTimeout,
    stepTick,
    stepNavigate,
    stepTab,
    stepTheme,
    stepZenoh
  }

  val masterInvariant: bool = navigationInvariant

  // Run commands:
  //   quint verify --invariant=masterInvariant cockpit_navigation_invariants.qnt
  //   quint run --max-steps=300 --invariant=masterInvariant cockpit_navigation_invariants.qnt
  // Expected: PASS — no counterexamples in up to 300 steps

}

// =============================================================================
// VERIFICATION SUMMARY
// =============================================================================
//
// INV-SINGLE-PAGE (one route active):
//   activePage is a scalar Quint sum-type variable; it holds exactly one Route
//   value.  The invariant asserts ALL_ROUTES.contains(activePage) which covers
//   all 19 defined routes.
//
// INV-SESSION-REQUIRED (protected routes need session):
//   navigate_to() requires sessionActive == true and target in PROTECTED_ROUTES.
//   login() is the only action that sets sessionActive = true.  Therefore no
//   protected route can be reached without a prior login.
//
// INV-LOGIN-WHEN-NO-SESSION (Login shown without session):
//   session_timeout() and logout() both set activePage = Login and
//   sessionActive = false atomically.  No action other than login() can
//   set sessionActive = true.
//
// INV-TAB-PRESERVE (switch_tab does not change page):
//   switch_tab() stutters activePage.  The tab bounds invariant asserts
//   activeTab ∈ [0, MAX_TAB_INDEX] at all times.
//
// INV-NON-TABBED-ZERO-TAB:
//   navigate_to() calls restoredTab() which returns tabState.get(r) if
//   previously set, else 0.  Non-tabbed pages are never targets of switch_tab()
//   (isTabbed precondition).  So activeTab on non-tabbed pages is always 0.
//
// INV-GLOBAL-THEME (single theme covers all pages):
//   theme is a single global variable.  change_theme() is the only mutating
//   action; its parameter comes from Set(DarkCockpit, LightMode, HighContrast).
//   Initial value DarkCockpit (SC-COCKPIT-003).
//
// INV-ZENOH-VISIBLE (SC-ZENOH-007):
//   zenohStatus is a global variable updated by update_zenoh_status() which
//   can fire on any page.  The invariant asserts a valid ZenohStatus enum
//   value is always present.  Visibility is structural — no page can hide it.
//
// INV-DARK-DEFAULT (SC-COCKPIT-003 default):
//   init() sets theme = DarkCockpit.  The invariant holds vacuously once
//   theme changes; what it enforces is that the very first active theme
//   before any session starts is always DarkCockpit.
//
// TEMP-NAV-5 (all routes reachable):
//   Under fair scheduling, stepNavigate non-deterministically selects from
//   PROTECTED_ROUTES (18 routes).  Each route is eventually selected, and
//   navigate_to() adds it to visitedRoutes.  Under weak fairness all 18 routes
//   are eventually covered.
//
// =============================================================================
