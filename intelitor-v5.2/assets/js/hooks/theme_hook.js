/**
 * Theme Hook for Phoenix LiveView
 * L4-A03: JavaScript Theme Hook - TPS/Jidoka Compliant
 *
 * Handles:
 * - Theme switching without page reload
 * - System preference detection (prefers-color-scheme)
 * - LocalStorage persistence for immediate load
 * - LiveView push event integration
 *
 * STAMP Compliance: SC-HMI-001, SC-HMI-008
 */

const THEME_KEY = 'indrajaal-theme';
const VALID_THEMES = ['light', 'dark', 'high-contrast', 'system', 'color-rich', 'google-compliant', 'functionally-clean'];

export const ThemeHook = {
  mounted() {
    // Listen for theme changes from LiveView
    this.handleEvent("set_theme", ({ theme }) => {
      this.setTheme(theme);
    });

    // Listen for theme toggle
    this.handleEvent("toggle_theme", () => {
      this.toggleTheme();
    });

    // Watch for system preference changes
    this.mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    this.systemChangeHandler = (e) => {
      if (this.getCurrentTheme() === 'system') {
        this.applySystemTheme();
      }
    };
    this.mediaQuery.addEventListener('change', this.systemChangeHandler);

    // Apply initial theme
    this.initTheme();
  },

  destroyed() {
    if (this.mediaQuery && this.systemChangeHandler) {
      this.mediaQuery.removeEventListener('change', this.systemChangeHandler);
    }
  },

  initTheme() {
    // Priority: 1. Server-pushed, 2. LocalStorage, 3. System default
    const serverTheme = this.el.dataset.theme;
    const storedTheme = localStorage.getItem(THEME_KEY);
    const theme = serverTheme || storedTheme || 'system';

    this.setTheme(theme, false);
  },

  getCurrentTheme() {
    return localStorage.getItem(THEME_KEY) || 'system';
  },

  setTheme(theme, persist = true) {
    if (!VALID_THEMES.includes(theme)) {
      console.warn(`[ThemeHook] Invalid theme: ${theme}`);
      return;
    }

    // Add transition-blocking class
    document.documentElement.classList.add('theme-switching');

    // Remove all theme classes
    document.documentElement.classList.remove('dark', 'high-contrast', 'color-rich', 'google-compliant', 'functionally-clean');

    // Apply new theme
    if (theme === 'system') {
      this.applySystemTheme();
    } else if (theme === 'dark') {
      document.documentElement.classList.add('dark');
    } else if (theme === 'high-contrast') {
      document.documentElement.classList.add('dark', 'high-contrast');
    } else if (theme === 'color-rich') {
      document.documentElement.classList.add('color-rich');
    } else if (theme === 'google-compliant') {
      document.documentElement.classList.add('google-compliant');
    } else if (theme === 'functionally-clean') {
      document.documentElement.classList.add('functionally-clean');
    }
    // 'light' needs no class (default)

    // Persist to localStorage
    if (persist) {
      localStorage.setItem(THEME_KEY, theme);
    }

    // Update data attribute for server sync
    this.el.dataset.theme = theme;

    // Remove transition-blocking class after a tick
    requestAnimationFrame(() => {
      document.documentElement.classList.remove('theme-switching');
    });

    // Push to server for persistence
    this.pushEvent("theme_changed", { theme });

    console.log(`[ThemeHook] Theme set to: ${theme}`);
  },

  toggleTheme() {
    const current = this.getCurrentTheme();
    const themes = ['light', 'dark', 'system'];
    const currentIndex = themes.indexOf(current);
    const nextIndex = (currentIndex + 1) % themes.length;
    this.setTheme(themes[nextIndex]);
  },

  applySystemTheme() {
    const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    document.documentElement.classList.remove('dark', 'high-contrast');
    if (isDark) {
      document.documentElement.classList.add('dark');
    }
  }
};

/**
 * Inline script for preventing FOUC (Flash of Unstyled Content)
 * Add to <head> of root.html.heex before CSS loads
 */
export const themeInitScript = `
  (function() {
    try {
      var theme = localStorage.getItem('indrajaal-theme') || 'system';
      var isDark = theme === 'dark' ||
        (theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
      var isHighContrast = theme === 'high-contrast';
      var isColorRich = theme === 'color-rich';
      var isGoogle = theme === 'google-compliant';
      var isClean = theme === 'functionally-clean';

      if (isDark || isHighContrast) {
        document.documentElement.classList.add('dark');
      }
      if (isHighContrast) {
        document.documentElement.classList.add('high-contrast');
      }
      if (isColorRich) {
        document.documentElement.classList.add('color-rich');
      }
      if (isGoogle) {
        document.documentElement.classList.add('google-compliant');
      }
      if (isClean) {
        document.documentElement.classList.add('functionally-clean');
      }
    } catch (e) {
      // localStorage may be blocked
    }
  })();
`;

export default ThemeHook;
