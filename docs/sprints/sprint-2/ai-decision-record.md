# AI Decision Record

## Status

For Team Discussion

## Purpose

This document captures the main AI architecture options that should be discussed by the team before treating the current AI architecture as final.

It exists to answer three practical questions from the sprint task:

1. How should generation work?
2. What output artifact should the system produce?
3. Should the LLM run through backend API only, in the browser only, or in both modes?

This document is not the final architecture. It is the decision record that explains the alternatives and why the current architecture prefers one direction over the others.

## Discussion Inputs

The team should evaluate options against these constraints:

- Version 1 is a `JavaScript` notebook product
- AI must support notebook workflow, not replace it with chat
- backend access to Bedrock must remain private
- generated code is untrusted
- frontend and backend are developed by different people and need a stable contract
- offline/demo usage is useful, but browser capabilities are inconsistent

## Questions To Decide

### 1. How should generation work?

Options:

1. Direct generation with no validation
2. Generation with code extraction only
3. Generation with extraction, syntax validation, and bounded repair retry

### 2. What should the output artifact be?

Options:

1. Raw provider text
2. Normalized validated code string
3. A new durable `ai` notebook block
4. Metadata plus code proposal for insertion into a normal `code` block after the source `text` block

### 3. Where should the model run?

Options:

1. Backend API only
2. Browser `WebLLM` only
3. Hybrid model: backend-first with browser local mode

## Option Analysis

### A. Backend API Only

Description:

- frontend sends AI requests to backend
- backend calls Bedrock
- browser never talks to provider directly

Advantages:

- best security boundary for credentials and provider control
- stable observability, timeout policy, and error handling
- one canonical integration path for frontend and backend teams
- easier to enforce prompt policy and validation consistently

Disadvantages:

- no local fallback if backend is unavailable
- requires backend readiness before full end-to-end AI flow works
- less useful for offline demo scenarios

Assessment:

- strong default for production
- best fit for the sprint security and DevOps constraints

### B. Browser `WebLLM` Only

Description:

- model runs in the browser
- frontend builds context and generates code locally
- backend is not required for generation

Advantages:

- works without provider credentials on the client
- useful for demos and local experiments
- reduced server dependency for generation

Disadvantages:

- inconsistent browser and device support
- model download and performance may be heavy
- weaker centralized control over behavior, logging, and validation
- harder to guarantee one consistent team-wide integration path

Assessment:

- useful as an experiment or demo path
- weak as the only Version 1 architecture decision

### C. Hybrid: Backend-First With Local Browser Mode

Description:

- backend path remains canonical
- `WebLLM` is optional for explicit local mode or retry after backend failure

Advantages:

- keeps the secure canonical path
- still supports demo/local/offline-style scenarios
- gives the product a graceful fallback story

Disadvantages:

- more product and UX complexity
- two execution paths require more testing
- results may differ between Bedrock and local model

Assessment:

- best balanced choice if the team accepts extra complexity
- should be `backend-first`, not equal-priority dual providers

## Generation Pipeline Options

### 1. Direct Generation Without Validation

Flow:

- prompt -> model -> return answer

Pros:

- fastest to implement

Cons:

- weak quality control
- may return markdown, explanations, or invalid code
- poor fit for the sprint requirement to validate syntax

Assessment:

- acceptable only as an early mock
- not acceptable as final Version 1 pipeline

### 2. Generation With Extraction Only

Flow:

- prompt -> model -> extract code -> return code

Pros:

- removes markdown wrappers and explanations
- still relatively simple

Cons:

- invalid JavaScript can still pass through
- does not satisfy the full backend validation requirement

Assessment:

- better than raw output
- still incomplete for the sprint

### 3. Generation With Extraction, Validation, And Repair Retry

Flow:

- prompt -> model -> extract code -> validate syntax
- if invalid -> ask model to fix once or twice with error feedback
- return validated code or normalized error

Pros:

- matches the sprint backend requirement
- best balance of quality and implementation realism
- easier for QA to reason about

Cons:

- more latency than a naive pipeline
- more backend logic to implement

Assessment:

- recommended Version 1 pipeline

## Output Artifact Options

### 1. Raw Provider Text

Pros:

- simplest transport shape

Cons:

- frontend must parse explanations and markdown
- weak contract between frontend and backend

Assessment:

- not recommended as the main product contract

### 2. Normalized Validated Code String

Description:

- backend returns a `code` string plus metadata such as provider, model, request id, and validation status

Pros:

- clear API contract
- easy frontend insertion
- aligns with notebook model where code remains normal editable content

Cons:

- backend takes on more responsibility

Assessment:

- recommended Version 1 output

### 3. Durable `ai` Notebook Block

Pros:

- explicit AI provenance

Cons:

- introduces a new notebook content type
- expands sync, export, ordering, and schema complexity

Assessment:

- too large for Version 1

### 4. Code Block Plus Optional Metadata

Description:

- source `text` block remains canonical notebook documentation and AI specification
- generated `code` block remains canonical executable content
- optional future metadata may store last prompt/provider information

Pros:

- preserves notebook simplicity
- supports future provenance without changing block types

Cons:

- should be treated as future scope, not immediate baseline

Assessment:

- good future extension

## Recommended Decision Package

The current architecture is easiest to defend if the team accepts this package:

1. Provider access is `backend-first`.
2. `WebLLM` is optional local mode and retry path, not the main production path.
3. Explicit local `WebLLM` mode is allowed for unsynced local working copies; this does not change the synced-notebook prerequisite for the backend AI path.
4. Backend returns normalized validated code, not raw provider text.
5. AI uses an existing `text` block as the prompt source and inserts generated code into a normal `code` block placed after that `text` block.
6. Backend performs prompt screening, code extraction, syntax validation, and bounded repair retry.
7. Version 1 does not require a user-facing durable or pseudo-durable AI prompt block; any transient UI state stays implementation-only.
8. Optional AI provenance metadata is future scope, not baseline.

## Why This Direction Was Chosen

This direction is preferred because it:

- best matches the sprint requirement around Bedrock and backend privacy
- keeps notebook schema simple
- uses notebook documentation itself as the generation specification
- gives frontend a clean contract
- contains security-sensitive logic on backend
- supports later local mode without making local mode the main architecture
- preserves the offline-first product story by allowing explicit local generation on unsynced local working copies
- satisfies the hardest sprint requirement: extract, validate, and repair invalid code

## Output Expected From This Design Work

The design work should produce:

1. A final architecture document:
   - `docs/ai-architecture.md`
   - `docs/ai-architectureRU.md`
2. A decision record explaining alternatives:
   - `docs/sprints/sprint-2/ai-decision-record.md`
   - `docs/sprints/sprint-2/ai-decision-recordRU.md`
3. A stable backend/frontend AI contract
4. A list of open questions that still require team agreement

## Remaining Questions For Team Discussion

- Should `WebLLM` be available in production as explicit local mode, or only in dev/demo?
- What exactly counts as an empty `code` block for insertion?
- Should Version 1 support pasted text only, or also CSV/file import?
- Should any AI provenance metadata be stored in block `meta` later?
- Should Version 1 support only implicit context from the source `text` block by default, or also a lightweight `scope:` directive such as `scope: this` and `scope: notebook`?

## Implementation Freeze For WebLLM Scope

The following points are now fixed for implementation planning:

- `WebLLM` remains optional local mode and retry fallback, not the default provider path
- automatic provider routing based on prompt length or frontend heuristics is out of scope
- explicit local `WebLLM` mode may run on unsynced local working copies
- the backend AI path still requires a synced server-backed notebook and is not relaxed by local mode
- local-mode results must be explicitly labeled as coming from `WebLLM`
