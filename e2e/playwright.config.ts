import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  outputDir: './test-results',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,

  use: {
    baseURL: process.env.E2E_BASE_URL ?? 'https://notebook.com:8443',
    ignoreHTTPSErrors: true,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    // Forward-looking convention so future tests can use page.getByTestId().
    // Confirm the exact attribute used by ui/ components when the auth UI lands.
    testIdAttribute: 'data-testid',
  },

  reporter: [
    ['list'],
    ['junit', { outputFile: './reports/junit-e2e.xml' }],
    ['html', { outputFolder: './playwright-report', open: 'never' }],
  ],

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
