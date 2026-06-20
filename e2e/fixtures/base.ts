import { test as base, expect, type Page, type APIRequestContext } from '@playwright/test';

// Env with local defaults — see e2e/README.md for full list
const API_BASE_URL = process.env.E2E_API_BASE_URL ?? 'https://api.notebook.com:8443';
const TEST_USER_EMAIL = process.env.E2E_TEST_USER_EMAIL ?? '';
const TEST_OTP = process.env.E2E_TEST_OTP ?? '';
const GOOGLE_AUTH_ENABLED = process.env.E2E_GOOGLE_AUTH_ENABLED === 'true';

type Fixtures = {
  authenticatedPage: Page;
  apiClient: APIRequestContext;
};

export const test = base.extend<Fixtures>({
  /**
   * authenticatedPage
   *
   * Provides a Page with an active authenticated session.
   * Authentication is established via Email + OTP (system_architecture.md §8.6) using
   * E2E_TEST_USER_EMAIL and E2E_TEST_OTP env vars. The session is stored in an
   * HTTP-only session cookie managed by the backend (system_architecture.md §3 decision 9).
   *
   * TODO (QA-64 follow-up): implement OTP login flow once the auth UI is stable.
   *   Required E2E scenario: qa_plan.md §5.2 scenario 1 — login → notebook list → create → open.
   *   Steps:
   *     1. POST /api/v1/auth/otp/request with TEST_USER_EMAIL
   *     2. POST /api/v1/auth/otp/verify with TEST_OTP
   *     3. Assert HTTP-only session cookie is set
   *     4. Return page in authenticated state
   *
   * TODO (QA-64 follow-up): add Google OAuth path.
   *   Required E2E scenario: qa_plan.md §5.2 scenario 1 (Google OAuth branch).
   *   Skip when E2E_GOOGLE_AUTH_ENABLED is false (see test.skip usage below).
   */
  authenticatedPage: async ({ page }, use) => {
    // TODO: implement — see comments above
    await use(page);
  },

  /**
   * apiClient
   *
   * Provides an APIRequestContext scoped to E2E_API_BASE_URL.
   * Session state (cookies + localStorage) from the browser context is forwarded
   * via storageState so the API client reuses the same authenticated session as
   * the page (system_architecture.md §8.6–8.7).
   *
   * Using storageState is the correct Playwright approach: it avoids manual
   * Cookie header serialisation which can break when cookie values contain ';'.
   *
   * TODO (QA-64 follow-up): storageState will carry the HTTP-only session cookie
   * automatically once authenticatedPage completes the OTP login flow.
   *   Used by: qa_plan.md §5.2 scenarios 5 (offline sync verification via API),
   *             6 (conflict — verify no server-side merge), 7 (export structure check).
   */
  apiClient: async ({ playwright, context }, use) => {
    const storageState = await context.storageState();
    const apiContext = await playwright.request.newContext({
      baseURL: API_BASE_URL,
      ignoreHTTPSErrors: true,
      storageState,
    });
    await use(apiContext);
    await apiContext.dispose();
  },
});

// Re-export expect so tests import only from this file
export { expect };

/**
 * Helper: skip a test when Google OAuth is not available in the current environment.
 * Usage:  skipIfGoogleAuthDisabled();
 *
 * TODO (QA-64 follow-up): apply to all tests tagged @auth that exercise the Google flow.
 *   Reference: qa_plan.md §5.2 scenario 1 (Google OAuth branch), §3 (test doubles).
 */
export function skipIfGoogleAuthDisabled() {
  if (!GOOGLE_AUTH_ENABLED) {
    test.skip(true, 'E2E_GOOGLE_AUTH_ENABLED is not true — Google OAuth tests skipped');
  }
}
