---
name: submodule-pr-workflow
description: Guides commit, push, PR, and merge sequencing when a task touches the root monorepo and/or the `api` and `ui` git submodules. Use when changes span multiple repositories, when submodule pointers must be updated, when `git submodule update --init --recursive` must remain correct after merge, or when commit/PR workflow needs explicit verification and team communication.
---

# Submodule PR Workflow

## Overview

Use this skill when work touches any combination of:

- root repository files such as `docs/`, `.github/`, `docker-compose`, or proxy config;
- `api/` submodule files;
- `ui/` submodule files.

The goal is to prevent broken PR sequencing, stale submodule pointers, and confusion about what `git submodule update --init --recursive` will actually fetch after merge.

## Instruction Priority

Project-specific instructions have higher priority than this skill.

When working in this repository, always check and follow:

1. `AGENTS.md`
2. Canonical project documentation
3. [docs/guides/git-workflow.md](../../../docs/guides/git-workflow.md)
4. This skill

If this skill conflicts with repository policy or the git guide, follow the higher-priority source.

## When to Use

Use this skill when:

- the task changes files in both root and one or more submodules;
- the user asks how to commit or open PRs correctly;
- the user needs to update submodule pointers in root;
- a PR was merged but `git submodule update --init --recursive` did not pull the expected version;
- the user needs a short explanation for team chat after merge.

Do not use this skill for ordinary single-repository changes with no submodule pointer updates.

## Workflow

### 1. Classify the change first

Before suggesting commands, determine which repositories are actually affected:

- `root only`
- `api only`
- `ui only`
- `api + root`
- `ui + root`
- `api + ui + root`

Never assume that a root PR can replace an `api` or `ui` PR. Root only records submodule commit pointers.

### 2. Inspect repository state before proposing commits

Check:

```bash
git status -sb
git submodule status
git -C api status -sb
git -C ui status -sb
git diff --submodule
```

Use these outputs to distinguish:

- root file changes;
- uncommitted changes inside a submodule;
- already-committed submodule movement relative to root.

### 3. Commit in the correct repository first

Rules:

- files under `api/` are committed inside `api`;
- files under `ui/` are committed inside `ui`;
- files under `docs/`, `.github/`, and other root paths are committed in root;
- a root commit that includes `api` or `ui` means only the pointer changed unless root files also changed.

Never recommend `git add api` or `git add ui` in root before the underlying submodule changes are committed.

### 4. Sequence PRs safely

Preferred order:

1. merge `api` PR if `api` changed;
2. merge `ui` PR if `ui` changed;
3. update submodule pointers in root;
4. merge root PR.

Reason:

- `git submodule update --init --recursive` checks out the SHA recorded in root;
- if root merges before the relevant submodule commit is reachable in the remote repository, the recorded pointer can be wrong for consumers and CI.

Be especially careful after `Squash and merge`, because the final SHA in `develop` may differ from the feature branch SHA. In that case, re-sync root against the merged `develop` branches of `api` and `ui` before opening or merging the pointer-update PR.

### 5. Use a dedicated pointer-update PR when needed

When the only remaining change is “root should point to newer `api`/`ui` commits”, prefer a dedicated root PR such as:

- `chore/update-api-submodule-pointer`
- `chore/update-ui-submodule-pointer`
- `chore/update-submodule-pointers`

This keeps the intent clear and makes post-merge verification easier.

### 6. Verify the final state explicitly

Before telling the user the workflow is complete, verify:

```bash
git ls-tree HEAD api ui
git submodule status
git diff --submodule
```

When checking the remote `develop` branch, verify:

```bash
git fetch --all --prune
git ls-tree origin/develop api ui
git -C api fetch --all --prune
git -C ui fetch --all --prune
```

Interpretation:

- `git ls-tree origin/develop api ui` shows which exact submodule SHAs root `develop` records;
- submodule branches must contain those SHAs on the remote side;
- only then should `git submodule update --init --recursive` produce the expected checkout for consumers.

## Required Explanations

When helping the user, explain these distinctions clearly:

- a submodule branch existing is not enough;
- merge in `api` or `ui` is not enough by itself;
- root must be updated to point to the intended submodule SHAs;
- `git submodule update --init --recursive` fetches recorded SHAs, not “latest branch heads”.

## Output Patterns

### Command guidance

Prefer exact command sequences grouped by repository:

- `api` commands
- `ui` commands
- `root` commands

Do not mix unrelated commands into one opaque block when the user needs to understand sequencing.

### Team chat update

When asked to describe a merged pointer-update PR, use wording like:

`Merged <branch-or-pr-name>: root now points to the intended api/ui submodule SHAs. After updating develop, git submodule update --init --recursive will check out the versions of api and ui recorded in root develop.`

### PR summary

When asked for a PR description, state:

- which repositories changed;
- whether the PR changes content or only updates pointers;
- what order the dependent PRs must merge in;
- how to verify the final state locally.

## Guardrails

- Do not recommend destructive history rewrites unless the user explicitly asks for them and understands the impact.
- Do not claim that submodules will “pull the latest version” unless you explicitly mean “the latest SHAs recorded in root”.
- Do not assume `api` and `ui` local branch names match root branch names.
- Do not skip verification when root `develop` must be trusted by other engineers or CI.
