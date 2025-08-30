import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        'scout-bg': '#0b0d12',
        'scout-panel': '#121622',
        'scout-text': '#e6e9f2',
        'scout-muted': '#9aa3b2',
        'scout-accent': '#0057ff',
        'scout-border': '#1a1d29',
        'scout-hover': '#1a1d29',
      },
      borderRadius: {
        'scout': '10px',
      },
    },
  },
  plugins: [],
}
export default config
