import type { Config } from 'tailwindcss'

export default {
  content: [
    './src/**/*.{ts,tsx}',
    '../../apps/scout-ui/src/**/*.{ts,tsx}',
    './app/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      borderRadius: {
        sk: 'var(--radius)',
      },
      colors: {
        bg: 'var(--bg)',
        panel: 'var(--panel)',
        text: 'var(--text)',
        muted: 'var(--muted)',
        accent: 'var(--accent)',
        danger: 'var(--danger)',
        warn: 'var(--warn)',
        info: 'var(--info)',
      },
    },
  },
  plugins: [],
} satisfies Config