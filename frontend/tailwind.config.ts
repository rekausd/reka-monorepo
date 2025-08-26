import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: { DEFAULT: "#14b8a6", dark: "#0f766e" },
        pendle: {
          navy: "#0B1929",
          "navy-dark": "#050D17",
          purple: "#6366F1",
          "purple-light": "#818CF8",
          teal: "#14B8A6",
          "teal-light": "#5EEAD4",
          indigo: "#4F46E5",
          "indigo-light": "#6366F1",
          emerald: "#10B981",
          "emerald-light": "#34D399",
          gray: {
            800: "#1F2937",
            700: "#374151",
            600: "#4B5563",
            500: "#6B7280",
            400: "#9CA3AF",
            300: "#D1D5DB",
          },
        },
      },
      backgroundImage: {
        "gradient-radial": "radial-gradient(var(--tw-gradient-stops))",
        "gradient-pendle": "linear-gradient(135deg, #0B1929 0%, #4F46E5 50%, #14B8A6 100%)",
        "gradient-subtle": "linear-gradient(135deg, #0B1929 0%, #050D17 100%)",
        "gradient-button": "linear-gradient(135deg, #4F46E5 0%, #6366F1 100%)",
        "gradient-button-hover": "linear-gradient(135deg, #6366F1 0%, #818CF8 100%)",
        "gradient-emerald": "linear-gradient(135deg, #10B981 0%, #14B8A6 100%)",
        "gradient-text": "linear-gradient(135deg, #818CF8 0%, #5EEAD4 100%)",
      },
      fontFamily: {
        sans: ['"Inter"', 'system-ui', 'sans-serif'],
      },
      animation: {
        "gradient-shift": "gradient-shift 8s ease infinite",
        "glow": "glow 2s ease-in-out infinite alternate",
      },
      keyframes: {
        "gradient-shift": {
          "0%, 100%": {
            "background-size": "200% 200%",
            "background-position": "left center",
          },
          "50%": {
            "background-size": "200% 200%",
            "background-position": "right center",
          },
        },
        "glow": {
          from: {
            "box-shadow": "0 0 20px rgba(99, 102, 241, 0.3)",
          },
          to: {
            "box-shadow": "0 0 30px rgba(99, 102, 241, 0.5), 0 0 40px rgba(99, 102, 241, 0.2)",
          },
        },
      },
      backdropBlur: {
        xs: "2px",
      },
    },
  },
  plugins: [],
};

export default config;