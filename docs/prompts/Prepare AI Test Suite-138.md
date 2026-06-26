# Task 138 — Prepare AI Test Suite

## Context

The AI generation feature (`POST /api/v1/ai/code-blocks/generate`) is designed and architecturally fixed in `docs/ai-architecture.md` but not yet implemented in `api/app/features/ai/` or `ui/src/features/ai/`.

This task prepares the test suite infrastructure **before** the feature lands, so it is ready for validation the moment implementation begins.

The test artifact is `docs/ai-test-cases.md`.

---

## Scope

Test the following aspects of the AI pipeline according to `docs/ai-architecture.md`:

| Area | What to cover |
|---|---|
| Function generation | Simple functions, multi-param, async, utility helpers |
| Class generation | ES6 classes, inheritance, static methods |
| React component generation | Functional components, with props, with hooks |
| Error handling | All normalized error codes, frontend/backend behavior, request validation (`mode`, `context.language`, `sourceBlockId` block type) |
| Empty responses | LLM returns empty string, whitespace, no code block |
| Timeouts | Provider timeout, request-level timeout, frontend timeout |
| Code revision (`revise` mode) | Convert `code` block to `text` source, `mode: "revise"` flow, code preservation, insertion below converted block |

---

## Required Artifact

Create `docs/ai-test-cases.md` with:

- 50–65 test cases
- Coverage across all seven areas above
- Each test case includes: ID, category, input prompt, expected code structure, expected behavior, and expected error code (where relevant)
- Edge cases for prompt policy rejection and prompt-injection screening
- Request-validation edge cases for invalid `mode`, unsupported `context.language`, and a `sourceBlockId` that does not reference a `text` block
- Code-revision cases covering the `mode: "revise"` flow from `docs/ai-architecture.md §4.1`

---

## Canonical Contract References

All test cases must be consistent with:

- `docs/ai-architecture.md` — full AI pipeline spec
- `docs/system_architecture.md` — system-level contracts
- `api/docs/api_architecture.md` — backend route and error conventions

### API Endpoint

```
POST /api/v1/ai/code-blocks/generate
```

### Request Shape

```json
{
  "notebookId": "nb_123",
  "sourceBlockId": "blk_text_2",
  "mode": "generate",
  "prompt": "<user prompt text>",
  "context": {
    "language": "javascript",
    "scope": "this",
    "sourceText": "<source block content>",
    "globals": [],
    "relevantBlocks": [],
    "insertion": {
      "strategy": "next-empty-or-new-after-source"
    }
  }
}
```

`mode` must be `generate` or `revise`. `context.language` must be `javascript` in Version 1. `sourceBlockId` must reference a notebook `text` block.

### Success Response Shape

```json
{
  "requestId": "air_123",
  "status": "success",
  "code": "...",
  "provider": "bedrock",
  "model": "deepseek.v3.2",
  "warnings": [],
  "validation": {
    "extractionApplied": true,
    "syntaxOk": true
  }
}
```

### Error Response Shape

```json
{
  "requestId": "air_123",
  "status": "error",
  "errorCode": "<ERROR_CODE>",
  "message": "...",
  "retryable": true
}
```

### Normalized Error Codes

| Code | Condition |
|---|---|
| `AI_INVALID_REQUEST` | Malformed request payload |
| `AI_FORBIDDEN` | Notebook not owned by requester |
| `AI_PROMPT_REJECTED` | Non-code prompt (explain, summarize, chat) |
| `AI_PROMPT_UNSAFE` | Prompt injection or policy evasion |
| `AI_PROVIDER_TIMEOUT` | Bedrock did not respond in time |
| `AI_PROVIDER_UNAVAILABLE` | Bedrock unavailable |
| `AI_RESPONSE_INVALID` | Malformed provider response |
| `AI_CODE_EXTRACTION_FAILED` | No code block found in response |
| `AI_CODE_SYNTAX_INVALID` | Extracted code fails JS syntax check |
| `AI_FALLBACK_UNAVAILABLE` | WebLLM not available for local fallback |

---

## Acceptance Criteria

1. `docs/ai-test-cases.md` exists and is committed to the repository.
2. The file contains 50–65 distinct test cases.
3. Test cases cover: function generation, class generation, React component generation, empty responses, error handling, timeouts, and code revision (`revise` mode).
4. Each test case specifies prompt, expected output structure, and expected system behavior.
5. Edge cases include prompt policy rejection, injection attempts, repair-retry scenarios, WebLLM fallback, request-validation failures (`mode`, `context.language`, `sourceBlockId` block type), and the `revise` code-revision flow.
6. The file is structured so it can be directly used to drive both manual QA and future automated test implementation.

---

## Implementation Notes

Since the AI backend and frontend are not yet implemented, this task produces specification-level test cases only.

The file format must allow:

- direct manual execution by a QA engineer once implementation lands
- straightforward conversion to automated Pytest / Vitest tests
- future parameterization via test data fixtures

When the backend is implemented, test cases in the "Happy path" and "Repair retry" categories should map to Pytest integration tests against `POST /api/v1/ai/code-blocks/generate`.

When the frontend is implemented, "Insertion rule", "Fallback", and "Code revision" cases should map to Vitest unit tests or Playwright E2E tests.

### Expected Test Case Inventory

The regenerated `docs/ai-test-cases.md` must reproduce the following structure and counts:

| Category | ID prefix | Count |
|---|---|---|
| Function generation | `TC-F-` | 10 |
| Class generation | `TC-C-` | 7 |
| React component generation | `TC-R-` | 10 |
| Error handling | `TC-E-` | 18 |
| Empty responses | `TC-EMP-` | 6 |
| Timeouts | `TC-T-` | 6 |
| Code revision (`revise` mode) | `TC-RV-` | 4 |
| **Total** | | **61** |

The error-handling category must cover every normalized error code plus the three request-validation cases (`TC-E-16` invalid `mode`, `TC-E-17` unsupported `context.language`, `TC-E-18` non-`text` `sourceBlockId`). The file must also include Appendix A (context scope variants), Appendix B (insertion rule variants), Appendix C (prompt policy reference), and a final test-case count summary table.
