/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
    "./public/**/*.html"
  ],
  theme: {
    extend: {
      colors: {
        scout: {
          blue: '#1e40af',
          green: '#059669',
          yellow: '#d97706',
          red: '#dc2626'
        }
      }
    },
  },
  plugins: [],
}