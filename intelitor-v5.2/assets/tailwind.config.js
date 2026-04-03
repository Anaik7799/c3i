// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration
// L4-A01: Tailwind Dark Mode Configuration - TPS/Jidoka Compliant

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  // SC-HMI-001: Enable class-based dark mode for theme switching
  darkMode: 'class',

  content: [
    "./js/**/*.js",
    "../lib/indrajaal_web.ex",
    "../lib/indrajaal_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",

        // Semantic surface colors (backgrounds)
        surface: {
          primary: 'var(--surface-primary)',
          secondary: 'var(--surface-secondary)',
          tertiary: 'var(--surface-tertiary)',
          elevated: 'var(--surface-elevated)',
        },

        // Semantic content colors (text)
        content: {
          primary: 'var(--content-primary)',
          secondary: 'var(--content-secondary)',
          muted: 'var(--content-muted)',
          inverse: 'var(--content-inverse)',
        },

        // Semantic border colors
        'border-theme': {
          primary: 'var(--border-primary)',
          secondary: 'var(--border-secondary)',
          focus: 'var(--border-focus)',
        },

        // Status colors (SC-HMI-001 compliant - consistent across themes)
        status: {
          healthy: 'var(--status-healthy)',
          advisory: 'var(--status-advisory)',
          caution: 'var(--status-caution)',
          warning: 'var(--status-warning)',
          critical: 'var(--status-critical)',
        },

        // Cockpit-specific grays for fine control
        cockpit: {
          900: '#111827',
          850: '#18202f',
          800: '#1f2937',
          750: '#293548',
          700: '#374151',
          600: '#4b5563',
          500: '#6b7280',
          400: '#9ca3af',
          300: '#d1d5db',
          200: '#e5e7eb',
          100: '#f3f4f6',
          50: '#f9fafb',
        }
      },

      // Animation for status indicators
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'blink': 'blink 1s step-end infinite',
      },

      keyframes: {
        blink: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0' },
        }
      },

      // Cockpit-specific font settings
      fontFamily: {
        mono: ['JetBrains Mono', 'Fira Code', 'Monaco', 'Consolas', 'monospace'],
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // High contrast variant for accessibility (SC-HMI-008)
    plugin(({addVariant}) => addVariant("high-contrast", [".high-contrast&", ".high-contrast &"])),
  ]
}
