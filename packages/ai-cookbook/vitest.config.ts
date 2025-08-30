import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    coverage: {
      reporter: ['text', 'json', 'html'],
      include: ['src/**/*'],
      exclude: ['src/tests/**/*', 'src/**/*.test.ts', 'src/**/*.spec.ts'],
    },
  },
});