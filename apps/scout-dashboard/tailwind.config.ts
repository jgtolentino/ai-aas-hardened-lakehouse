import type { Config } from 'tailwindcss'
const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        brand: { 600: "#0057ff" }
      }
    }
  },
  plugins: []
}
export default config
