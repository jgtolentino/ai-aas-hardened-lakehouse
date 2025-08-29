import { defineConfig } from "vitest/config";
export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    passWithNoTests: false,
    include: ["tests/**/*.spec.js"],
    timeout: 10000
  }
});
