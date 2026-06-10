---
name: task-planner
description: Breaks product or engineering work into ordered, implementable tasks. Use when requirements are too large, vague, risky, or multi-step. Use before implementation when a plan, sequencing, dependencies, acceptance criteria, or parallelization strategy is needed.
---

# Task Planner

## Overview

Convert requirements into a clear implementation plan. The output should help an engineer or coding agent start work without guessing what to do next.

Planning is read-only. Do not write implementation code while planning.

## Instruction Priority

Project-specific instructions have higher priority than this skill.

When planning work in a repository, always check and follow:

1. `AGENTS.md`
2. Canonical project documentation
3. Existing architecture and codebase conventions
4. This skill

If this skill conflicts with `AGENTS.md`, canonical documentation, or established repository patterns, follow the project-specific source instead.

## When to Use

Use this skill when:

- A feature is too large to implement directly
- Requirements need sequencing
- The work spans frontend, backend, database, infrastructure, or tests
- Dependencies between tasks are unclear
- Work may be parallelized
- Risks or unknowns need to be surfaced
- A human needs a clear scope breakdown

Do not use this skill for trivial single-file changes with obvious scope.

## Plan Artifacts

Prefer saving substantial planning output as a repository artifact instead of leaving it only in chat.

- Save implementation plans under `docs/plans/` when the user asks to keep the result or when the plan will be reused later
- Prefer numbered direction-plan filenames when the repository uses roadmap ordering, for example `docs/plans/01-auth-backend-plan.md`
- Save derived task specs under `docs/plans/tasks/`
- If a related task spec already exists, reference it from the plan
- If no file path is requested and the plan is small or one-off, chat output is acceptable

The plan artifact should be the source plan that later task specs derive from.

## Invocation Examples

Use prompts like:

- `Use task-planner. Plan backend auth work and save the result to docs/plans/01-auth-backend-plan.md.`
- `Use task-planner. Break this feature into dependency-ordered tasks and keep the plan in docs/plans/05-sync-plan.md.`
- `Use task-planner. After planning, keep the derived task specs under docs/plans/tasks/.`
- `Use task-planner. Produce a chat-only plan for this small research task.`

## Planning Process

### 0. Place The Plan In The Roadmap Order

When the repository has a roadmap with numbered direction plans, keep direction-plan filenames aligned with the implementation order from that roadmap.

Use this convention:

- `docs/plans/01-<topic>-plan.md`
- `docs/plans/02-<topic>-plan.md`
- `docs/plans/03-<topic>-plan.md`

Rules:

- the number reflects recommended implementation order, not file creation order
- do not renumber existing plans casually; keep numbering stable unless the roadmap itself changes
- task specs under `docs/plans/tasks/` keep their own numbering inside the direction, for example `auth-backend-01-...`
- when a roadmap exists, reference the numbered plan filename consistently in task specs

### 1. Understand the Goal

Identify:

- What is being built or changed
- Who the user is
- What behavior must exist after the work is complete
- What constraints are known
- What is explicitly out of scope

If requirements are incomplete, make reasonable assumptions and list them.

### 2. Inspect Existing Context

Before planning implementation, inspect:

- Relevant code structure
- Existing patterns
- Existing APIs or models
- Existing tests
- Existing conventions
- Similar completed features

Do not plan against an imaginary architecture.

### 3. Identify Dependencies

Map what must exist before other work can proceed.

Typical dependency order:

1. Data model or contract
2. Backend validation and business logic
3. API endpoint or interface
4. Client/API integration
5. UI or consumer behavior
6. Tests and quality checks
7. Documentation or rollout steps

Prefer dependency-aware plans over arbitrary task lists.

### 4. Slice Work Vertically Where Possible

Prefer small end-to-end slices that leave the system working.

Bad:

- Build all database changes
- Build all backend endpoints
- Build all frontend screens
- Connect everything at the end

Better:

- Implement one complete user-visible capability
- Verify it
- Then implement the next capability

Vertical slices reduce integration risk.

### 5. Define Acceptance Criteria

Every task must have testable acceptance criteria.

Good acceptance criteria are:

- Specific
- Observable
- Verifiable
- Small enough to complete in one focused work session

Avoid vague criteria like "works correctly" or "improve UX."

### 6. Define Verification

Each task should include how to verify it:

- Unit tests
- Integration tests
- Typecheck
- Lint
- Build
- Manual scenario
- API call
- Screenshot or UI check, if relevant

Verification should be executable by another agent or engineer.

## Task Format

Use this format:

```markdown
## Task N: `T3/BTF -> AREA: Short imperative title`

**Description:** One paragraph explaining what this task accomplishes.

**Acceptance criteria:**
- [ ] Specific, testable condition
- [ ] Specific, testable condition
- [ ] Specific, testable condition

**Verification:**
- [ ] Command or test to run
- [ ] Manual check, if needed

**Dependencies:** Exact task titles or `None`

**Initial status:** `planned`

**Documentation impact:**
- `None`, or exact docs that must be updated when the task lands
- Prefer concrete paths such as `docs/project.md`, `docs/system_architecture.md`, `api/docs/auth.md`

**Likely files or areas:**
- `path/or/module`
- `path/or/module`

**Scope:** XS / S / M / L
```

Use the established title format consistently:

- `T3/BTF -> BACK: ...`
- `T3/BTF -> FRONT: ...`
- `T3/BTF -> DEVOPS: ...`
- `T3/BTF -> QA: ...`
- `T3/BTF -> RESEARCH: ...`

## Task Sizing

Use these sizes:

- XS: one small function, config, or copy change
- S: one file or one isolated behavior
- M: one coherent feature slice across a few files
- L: broad change that should probably be split
- XL: too large; must be broken down

Prefer S and M tasks.

Break a task down further if:

- It has more than three acceptance criteria
- The title contains "and"
- It touches unrelated subsystems
- It cannot be verified independently
- It would leave the system broken until a later task

When one task depends on another, name the dependency concretely using the exact planned task title rather than a generic phrase.

For tasks that may change product behavior, architecture, contracts, or developer workflow, plan the documentation follow-up explicitly instead of assuming it will be done later.

## Plan Output Template

```markdown
# Implementation Plan: [Name]

## Goal

[Concise description of the intended outcome.]

## Assumptions

- [Assumption 1]
- [Assumption 2]

## Architecture Notes

- [Relevant existing pattern]
- [Important design decision]
- [Boundary or contract to preserve]

## Tasks

### Phase 1: Foundation

[Tasks]

### Phase 2: Core Implementation

[Tasks]

### Phase 3: Quality and Finish

[Tasks]

## Checkpoints

- [ ] After Phase 1: tests/build still pass
- [ ] After Phase 2: core flow works end-to-end
- [ ] Before completion: quality review completed

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---:|---|
| [Risk] | High/Medium/Low | [Mitigation] |

## Open Questions

- [Question]
```

When listing planned tasks and dependencies, use the exact task titles consistently so the plan can be converted directly into task specs or issues without renaming.

## Repository Planning Conventions

If the repository uses a three-level planning structure, preserve it:

1. roadmap file in `docs/plans/` for the whole product
2. numbered direction plans in `docs/plans/`
3. task specs in `docs/plans/tasks/`

Example:

- `docs/plans/mvp-roadmap.md`
- `docs/plans/01-auth-backend-plan.md`
- `docs/plans/02-notebook-persistence-plan.md`
- `docs/plans/tasks/auth-backend-01-persistence-and-session-foundation.md`
- `docs/plans/tasks/auth-backend-02-email-otp-request.md`

Use roadmap files to describe stages and blockers, direction plans to describe one implementation stream, and task specs to define executable work items.

When the plan will produce multiple task spec files, define a shared task slug and a stable execution order so downstream filenames can follow:

- `docs/plans/tasks/<task-slug>-01-<short-slice>.md`
- `docs/plans/tasks/<task-slug>-02-<short-slice>.md`
- `docs/plans/tasks/<task-slug>-03-<short-slice>.md`

Example:

- `docs/plans/01-auth-backend-plan.md`
- `docs/plans/tasks/auth-backend-01-persistence-and-contract.md`
- `docs/plans/tasks/auth-backend-02-email-otp-request.md`
- `docs/plans/tasks/auth-backend-03-email-otp-verify-and-session.md`

For executable task specs, assume the task lifecycle is tracked in the artifact itself:

- `planned`
- `in_progress`
- `blocked`
- `done`

Use `planned` as the initial status in generated task specs unless the user explicitly asks for another state.

## Completion Checklist

Before finalizing the plan:

- [ ] Tasks are ordered by dependency
- [ ] Each task has acceptance criteria
- [ ] Each task has verification steps
- [ ] Each task has an initial status and explicit documentation impact
- [ ] Large tasks were split
- [ ] Risks are explicit
- [ ] Save to `docs/plans/` when the output should be reused for task specs or later review
- [ ] Unknowns are listed
- [ ] The plan can be executed by another engineer or agent
