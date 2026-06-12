import { test, expect } from '../fixtures/base';

test(
  'canary — UI is reachable and returns a page title',
  { tag: '@smoke' },
  async ({ page }) => {
    // page.goto follows redirects. For an unauthenticated SPA the proxy returns the
    // app shell (200) and any redirect to /login happens client-side. A server-side
    // redirect to a login page is also acceptable — both stay below 400.
    const response = await page.goto('/');
    expect(
      response?.status(),
      'UI entry point should respond without an HTTP error',
    ).toBeLessThan(400);

    const title = await page.title();
    expect(title.trim().length, 'document.title should not be empty').toBeGreaterThan(0);
  },
);
