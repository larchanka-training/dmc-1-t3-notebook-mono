---
name: task-spec-writer
description: Writes clear Russian task specifications and GitHub issues for this repository. Use when a feature, bugfix, research task, or backend/frontend/infrastructure change must be formulated so the team and coding agents can execute it with minimal ambiguity, correct scope, explicit acceptance criteria, verification, dependencies, and context boundaries.
---

# Task Spec Writer

## Overview

Create task descriptions that a strong engineer or coding agent can execute without guessing.

The goal is not to sound formal. The goal is to remove ambiguity, keep scope tight, and make verification obvious.

Use this skill for:

- GitHub issues
- sprint tasks
- implementation tickets
- research/design tasks
- follow-up tasks split from a larger feature

Do not use this skill for:

- casual brainstorming
- broad roadmap discussions without an immediate execution target
- tasks that are already fully specified and only need copy editing

## Task Artifacts

Prefer saving the generated task spec as a repository artifact instead of leaving it only in chat.

- Save issue-ready task specs under `docs/plans/tasks/` when the user asks to keep the result or when the task will be reviewed later
- Prefer filenames like `docs/plans/tasks/<task-slug>-01-<short-slice>.md`
- Put the shared task slug first and the execution order second so related specs stay grouped in directory listings
- If the spec comes from an existing plan artifact in `docs/plans/`, reference that plan in `Context` or `Dependencies`
- Chat-only output is acceptable for quick drafts, but repository files are preferred for reusable tasks

The saved spec should be ready for review or copy into the issue tracker with minimal editing.

## Invocation Examples

Use prompts like:

- `Use task-spec-writer. Based on docs/plans/01-auth-backend-plan.md, create an issue-ready task spec and save it to docs/plans/tasks/auth-backend-02-email-otp-verify-and-session.md.`
- `Use task-spec-writer. Read docs/plans/notebook-sync-plan.md, propose the split first, then write the approved task specs into docs/plans/tasks/.`
- `Use task-spec-writer. Draft a chat-only task spec for quick review before saving it.`

## Instruction Priority

Project-specific instructions have higher priority than this skill.

Always follow:

1. `AGENTS.md`
2. current approved task artifact, if one already exists
3. canonical docs such as `docs/requirements.md`, `docs/project.md`, `docs/system_architecture.md`, `docs/tech_stack.md`
4. repository-specific docs such as `ui/docs/ui_architecture.md` or `api/docs/api_architecture.md`
5. this skill

If a lower-level task description conflicts with canonical project docs, fix the task description rather than copying the conflict forward.

## What A Good Task Must Achieve

A good task should let another engineer or agent answer these questions immediately:

- What exactly is being built or changed?
- Why is this task needed now?
- What is explicitly in scope?
- What is explicitly out of scope?
- Which contracts, docs, modules, or files constrain the work?
- How will we know the task is done?
- How should it be verified?
- What dependencies must land first?

If the reader still needs to guess the route names, storage model, state ownership, or test scope, the task is not ready.

## Default Output Language

For this repository, write the task artifact in Russian when the team discussion is in Russian.

Keep:

- section titles short
- scope concrete
- terminology aligned with canonical English docs

Do not switch core product terms into ad hoc synonyms. Prefer the project vocabulary:

- `notebook`
- `block`
- `execution session`
- `sync`
- `auth`
- `session cookie`

## Required Sections

Every non-trivial task should contain these sections.

### 1. Title

Use a short imperative title that states the work type and area.

For this repository, use the established prefix format:

`<SPRINT_SHORT_NAME> -> AREA: Short imperative description`

Where `SPRINT_SHORT_NAME` is the short sprint name agreed for the current task batch.

Examples:

- sprint 2 -> `AI`
- another sprint can use its own short label when defined in the current plan or task context

Where `AREA` is one of:

- `BACK`
- `FRONT`
- `DEVOPS`
- `QA`
- `RESEARCH`

Good:

- `AI -> BACK: Реализовать session bootstrap для auth`
- `AI -> FRONT: Подключить notebook sync API`
- `AI -> DEVOPS: Настроить CI проверку API contracts`
- `AI -> QA: Подготовить smoke-проверку auth flow`
- `AI -> RESEARCH: Зафиксировать conflict UX для sync`

Bad:

- `Авторизация`
- `Исправления`
- `Нужно сделать sync`

### 2. Goal

One short paragraph:

- what outcome must exist after the task
- what user or system capability this unlocks

This is the business/engineering outcome, not an implementation checklist.

### 3. Context

List only the documents, contracts, and code areas that define the task boundaries.

Typical examples:

- canonical docs
- API contracts
- architecture docs
- current partial implementation
- blocking or parent task

Only include context that the implementer truly needs.

### 4. Scope

This is the core of the task. Describe what must be implemented in concrete bullets.

Scope should describe behavior and deliverables, not vague intent.

Good scope bullets:

- implement `POST /api/v1/auth/session`
- add Alembic migration for auth sessions
- validate `base_revision` on sync requests
- connect router in `api/app/api/v1/router.py`

Bad scope bullets:

- finish auth
- improve API
- support edge cases

### 5. Out Of Scope

This section is mandatory when there is any realistic chance of scope creep.

Use it to stop the implementer from "being helpful" in the wrong direction.

Examples:

- Google OAuth is not part of this task
- frontend integration is not part of this task
- no real-time sync
- no migration of legacy data

### 6. Technical Constraints

Use this section only for constraints that affect implementation choices.

Examples:

- API must remain under `/api/v1`
- auth state must remain session-cookie based
- notebook content must stay `JSONB` snapshot based
- no new dependency without explicit approval

Do not restate generic engineering advice here.

### 7. Acceptance Criteria

Acceptance criteria must be observable and testable.

Rules:

- each bullet should describe one concrete done condition
- prefer behavior over internals
- if a route is required, name the route
- if persistence is required, name the stored entity
- if UI changes are required, name the user-visible state

Bad:

- auth works
- sync is implemented

Good:

- `GET /api/v1/auth/session` returns `authenticated: false` for anonymous requests
- successful logout invalidates the server-side session and clears the auth cookie
- sync conflict returns `409 Conflict` and does not overwrite newer server state

### 8. Verification

State how the work should be checked.

Use concrete commands or scenarios:

- unit tests
- integration tests
- lint
- typecheck
- build
- manual request flow
- UI smoke scenario

If a task changes behavior and has no verification section, it is underspecified.

### 9. Dependencies

State whether the task depends on earlier work.

Examples:

- requires auth persistence models and migrations
- depends on notebook sync contract doc
- none

This helps both humans and agents avoid starting blocked work.

Rules:

- name the concrete dependency when it exists
- prefer exact task titles, issue links, parent tasks, contracts, or migrations over generic phrases
- use `None` only when the task is independently executable
- if the dependency is blocking, do not write scope or verification that assumes the missing prerequisite is already implemented

Good:

- `Depends on AI -> BACK: Подготовить auth persistence и contract`
- `Requires merged Alembic migration for auth sessions`
- `Depends on approved notebook sync contract update`

Bad:

- `auth foundation`
- `previous backend work`
- `depends on other tasks`

### 10. Risks Or Notes

Only include real execution risks:

- contract drift
- security-sensitive behavior
- race conditions
- test environment caveats
- local/dev vs production differences

Do not use this section for generic warnings.

### 11. Status

Every persisted task spec should carry an explicit status.

Use:

- `planned`
- `in_progress`
- `blocked`
- `done`

Rules:

- default new task specs to `planned`
- update the status in the task artifact as work progresses
- do not mark a task `done` just because code was written; completion also requires verification and documentation review

### 12. Documentation Impact

State whether project documentation must change when the task lands.

Use one of these patterns:

- `None`
- `Required:` followed by exact document paths

Prefer concrete paths such as:

- `docs/project.md`
- `docs/system_architecture.md`
- `api/docs/api_architecture.md`
- `api/docs/auth.md`
- `ui/docs/ui_architecture.md`

Rules:

- if the task can change behavior, architecture, contracts, operational workflow, or developer workflow, assume documentation review is required
- list exact docs instead of saying `update docs`
- if the implementation diverges from the original task or plan, update both the affected docs and the task artifact notes

### 13. Completion Update

Add a short completion rule so Codex treats the task artifact as part of the work, not as a static brief.

Expected completion behavior:

- update the task status after implementation
- update affected documentation listed in `Documentation impact`, or explicitly confirm that no doc changes were needed
- record any material delta between the planned scope and the landed implementation
- do not leave the artifact in `planned` when the implementation is already merged or complete

## Split Tasks So Agents Can Finish Them

Default bias: split large work into small coherent tasks that preserve a working system.

Prefer tasks that satisfy all of these:

- one main outcome
- one primary subsystem or one thin vertical slice
- clear dependencies
- independently verifiable
- small enough for one focused implementation pass

Split when any of these is true:

- the task mixes persistence, business logic, UI, and infra at once
- the title contains multiple `and`
- the acceptance criteria exceed about 5-7 bullets
- different parts need different canonical docs
- the task cannot be verified without unfinished sibling work
- one part is research/design and another part is implementation

### Recommended Split Pattern

For medium or large work, split in this order:

1. contract or research foundation
2. persistence or backend foundation
3. primary behavior implementation
4. integration layer
5. hardening and verification

Example:

- `AI -> BACK: Подготовить auth persistence и contract`
- `AI -> BACK: Реализовать Email + OTP login`
- `AI -> BACK: Реализовать session bootstrap и logout`

This is usually better than one oversized "implement auth" task.

## Pre-Spec Feedback

Before generating one large task spec from a broad request or plan, pause and assess whether the work should be split.

If there is a realistic case for splitting:

- first return a short proposed split in chat
- explain the split in terms of dependencies, verification, or scope boundaries
- ask for confirmation if the split materially changes the number or shape of the resulting task specs
- do not write `docs/plans/tasks/...` artifacts until this pre-spec feedback step is complete
- after confirmation, or when the user already asked for decomposition explicitly, write the task spec files

Do not generate one oversized task spec first and only then suggest a better split afterward.
Do not write a persisted general-purpose task spec as a placeholder before the split decision is made.

Typical triggers for pre-spec feedback:

- auth or sync work that mixes persistence, API behavior, external providers, and QA
- tasks that would produce more than about 5-7 acceptance criteria
- requests that mention multiple subsystems or distinct deliverables
- plans where later tasks are clearly blocked by earlier foundation work

Good pre-spec feedback:

- `Proposed split: 1) auth persistence and contract, 2) OTP + session endpoints, 3) Google OAuth integration. This keeps dependencies explicit and makes each task independently verifiable.`

Bad pre-spec feedback:

- generating one large auth task spec and only then saying it should probably be 2-3 issues

Default rule:

- if the request spans multiple subsystems, phases, or external integrations, assume pre-spec feedback is required before writing files
- only skip pre-spec feedback when the task is already clearly singular and independently verifiable

## Context Budget Rules For Agent-Friendly Tasks

Tasks should be specific, but not bloated.

Include:

- exact routes
- exact docs to follow
- exact modules likely to change
- exact success behavior

Avoid:

- long background narratives
- duplicated architecture prose
- repeated quotations from docs
- full API schemas when one short summary is enough

Assume the implementer can read referenced docs. The task should tell them where to look and what matters there.

When a plan artifact exists in `docs/plans/`, include that file in `Context` and avoid retyping the entire plan into the task.
When multiple specs are produced from one plan, keep one shared task slug and increment the execution-order suffix consistently.
When the task is completed by Codex, the task artifact should also be updated to reflect the landed state.

## Russian Issue Template

Use this default template for GitHub issues in this repository:

```md
## Status

- `planned`

## Цель

[1 короткий абзац: какой результат должен появиться после задачи]

## Контекст

- [doc/file/issue]
- [doc/file/issue]
- [если есть, текущее ограничение или существующая частичная реализация]

## Scope

- [конкретная реализация или deliverable]
- [конкретная реализация или deliverable]
- [конкретная реализация или deliverable]

## Out of scope

- [что специально не входит]
- [что специально не входит]

## Технические ограничения

- [архитектурное ограничение]
- [контрактное ограничение]

## Acceptance criteria

- [ ] [наблюдаемое условие done]
- [ ] [наблюдаемое условие done]
- [ ] [наблюдаемое условие done]

## Verification

- [ ] [команда, тест или ручной сценарий]
- [ ] [команда, тест или ручной сценарий]

## Dependencies

- [None / номер задачи / краткое описание зависимости]

## Documentation impact

- [None / Required: doc/path.md]
- [если Required, перечислить точные документы]

## Риски / заметки

- [только реальные риски или важные оговорки]

## Completion update

- [после выполнения обновить статус]
- [обновить затронутые документы или явно указать, что изменений в docs не потребовалось]
- [если реализация отклонилась от исходного task scope, зафиксировать это]
```

## Writing Style Rules

When writing the issue:

- be direct
- use short sections
- keep bullets concrete
- use the `<SPRINT_SHORT_NAME> -> AREA: ...` title format consistently
- prefer exact routes, models, states, files
- prefer repository artifact references over long pasted chat summaries
- prefer `docs/plans/tasks/<task-slug>-NN-<short-slice>.md` naming over ad hoc filenames
- prefer explicit status and documentation-impact tracking over implicit completion
- avoid motivational or vague language
- avoid mixing desired behavior with speculative implementation

Good:

- `AI -> BACK: Подключить auth router в api/app/api/v1/router.py`

Bad:

- `доделать роутинг`

Good:

- `после logout GET /api/v1/auth/session возвращает anonymous state`

Bad:

- `проверить, что logout работает корректно`

## Final Checklist

Before considering the task ready:

- [ ] goal is clear in one paragraph
- [ ] scope is concrete and bounded
- [ ] out-of-scope items prevent likely scope creep
- [ ] acceptance criteria are observable
- [ ] verification is executable
- [ ] dependencies are stated
- [ ] dependencies are concrete enough that another engineer can tell whether the task is blocked
- [ ] pre-spec feedback was given before file generation when the task was broad or naturally splittable
- [ ] initial `Status` is present and correct
- [ ] `Documentation impact` is present and names exact docs or `None`
- [ ] completion rules make it clear that Codex must update status and docs after implementation
- [ ] save to `docs/plans/tasks/` when the task should persist beyond the chat
- [ ] filename uses a shared task slug and execution-order prefix that matches the planned sequence
- [ ] the task can be executed without guessing hidden requirements
- [ ] the task is small enough for one agent pass, or has been split
