# Planning Skills Guide

## Goal

This document explains what `task-planner` and `task-spec-writer` do and how the team should use them with Codex.

It is a team-facing usage guide, not a replacement for:

- `AGENTS.md`
- `docs/requirements.md`
- `docs/project.md`
- `docs/system_architecture.md`
- `docs/tech_stack.md`

## Two Different Skills

The repository uses two different planning skills for two different outputs:

1. `task-planner`
2. `task-spec-writer`

They are related, but they should not be used for the same job.

## What `task-planner` Does

`task-planner` creates a direction plan.

Use it when the work is still broad and the team needs to decide:

- what the implementation stream is
- what order the work should follow
- which tasks depend on earlier tasks
- where the main risks and boundaries are

Typical output:

- one file in `docs/plans/`
- a dependency-ordered implementation plan
- a proposed task sequence for later task specs

Examples:

- `docs/plans/01-auth-backend-plan.md`
- `docs/plans/02-notebook-persistence-plan.md`

`task-planner` is for decomposition and sequencing.

It is not for writing one final executable task.

## What `task-spec-writer` Does

`task-spec-writer` creates executable task specs.

Use it when the next work item is already clear and the team needs:

- one task artifact that Codex can execute
- scope boundaries
- explicit dependencies
- verification
- documentation follow-up

Typical output:

- one or more files in `docs/plans/tasks/`
- issue-ready or execution-ready task specs

Examples:

- `docs/plans/tasks/auth-backend-01-persistence-and-session-foundation.md`
- `docs/plans/tasks/auth-backend-02-email-otp-request.md`

`task-spec-writer` is for final task definition.

It is not for deciding the full implementation stream from scratch.

## When To Use Which Skill

Use `task-planner` first when:

- the feature is large
- several subsystems are involved
- ordering is unclear
- dependencies are not obvious
- the team first needs a plan in `docs/plans/`

Use `task-spec-writer` when:

- the plan already exists
- the next slice is clear
- the team wants a concrete task for Codex
- the result should be saved in `docs/plans/tasks/`

## Recommended Team Workflow

For non-trivial work, use this sequence:

1. Create or update the direction plan with `task-planner`.
2. Review the proposed sequence and dependencies.
3. Ask `task-spec-writer` to propose the split before writing files if the work may become several tasks.
4. Generate task specs in `docs/plans/tasks/`.
5. Execute the task specs with Codex one by one.
6. After implementation, update task status and documentation impact in the task artifact.

Short version:

- `task-planner` creates the plan
- `task-spec-writer` creates the executable tasks

## Important Rule About Splitting

If a direction plan naturally becomes several tasks, do not ask `task-spec-writer` to immediately write one large general-purpose task.

Instead:

1. ask for a proposed split first
2. review the split
3. only then generate files in `docs/plans/tasks/`

This avoids oversized tasks and keeps dependencies explicit.

## Artifact Locations

Use these locations consistently.

### Direction Plans

Save in:

- `docs/plans/01-<topic>-plan.md`
- `docs/plans/02-<topic>-plan.md`

Example:

- `docs/plans/01-auth-backend-plan.md`

### Task Specs

Save in:

- `docs/plans/tasks/<task-slug>-01-<short-slice>.md`
- `docs/plans/tasks/<task-slug>-02-<short-slice>.md`

Example:

- `docs/plans/tasks/auth-backend-01-persistence-and-session-foundation.md`
- `docs/plans/tasks/auth-backend-02-email-otp-request.md`

Rules:

- keep one shared task slug for one direction
- use the number for execution order
- do not number files by creation order if execution order is different

## Prompt Templates For The Team

### 1. Create A New Direction Plan

Use this when a roadmap stage needs its own plan.

```text
Use task-planner.

Create a direction plan for notebook persistence backend.

Output:
- save the result to docs/plans/02-notebook-persistence-plan.md

Requirements:
- follow AGENTS.md and canonical docs
- align with docs/plans/mvp-roadmap.md
- keep tasks dependency-ordered
- include assumptions, architecture notes, tasks, checkpoints, risks, and open questions
```

### 2. Update An Existing Direction Plan

Use this when scope or dependencies changed.

```text
Use task-planner.

Update docs/plans/02-notebook-persistence-plan.md.

Requirements:
- keep the existing plan structure
- revise task ordering, dependencies, and risks if needed
- reflect the latest approved scope
```

### 3. Ask For A Split Before Writing Task Specs

Use this when the plan may become several tasks.

```text
Use task-spec-writer.

Read docs/plans/02-notebook-persistence-plan.md.

Before writing any files:
- propose the task split in chat
- explain dependencies between the proposed tasks
- wait for confirmation before saving files
```

### 4. Generate One Task Spec

Use this when the next task is already obvious.

```text
Use task-spec-writer.

Based on docs/plans/02-notebook-persistence-plan.md, create the first task spec.

Output:
- save to docs/plans/tasks/notebook-persistence-01-persistence-model-and-migrations.md

Requirements:
- use the repository task-spec format
- set Status to planned
- include Dependencies
- include Documentation impact
- include Completion update
```

### 5. Generate A Full Task Set

Use this when the split is already approved.

```text
Use task-spec-writer.

Read docs/plans/02-notebook-persistence-plan.md and create the approved task set.

Output:
- docs/plans/tasks/notebook-persistence-01-persistence-model-and-migrations.md
- docs/plans/tasks/notebook-persistence-02-notebook-crud-api.md
- docs/plans/tasks/notebook-persistence-03-owner-access-control.md
- docs/plans/tasks/notebook-persistence-04-integration-tests-and-contract-alignment.md

Requirements:
- keep one shared task slug
- keep numbering aligned with execution order
- make dependencies explicit across the files
```

## What The Team Should Expect From Output

From `task-planner`, expect:

- one plan in `docs/plans/`
- ordered tasks
- explicit blockers
- architecture-aware sequencing

From `task-spec-writer`, expect:

- one or more specs in `docs/plans/tasks/`
- exact scope
- out-of-scope limits
- verification
- dependencies
- status tracking
- documentation follow-up

## Common Mistakes

Avoid these:

- using `task-spec-writer` before the plan is stable
- asking for one giant task when the work clearly has several slices
- keeping planning output only in chat when the team will reuse it
- saving task specs outside `docs/plans/tasks/`
- forgetting `Status`, `Documentation impact`, or `Completion update`
- renumbering plan or task files without a real roadmap reason

## Related Documents

- [AGENTS.md](../../AGENTS.md)
- [mvp-roadmap.md](./mvp-roadmap.md)
- [plan-files-priorityRU.md](./plan-files-priorityRU.md)
- [01-auth-backend-plan.md](./01-auth-backend-plan.md)
