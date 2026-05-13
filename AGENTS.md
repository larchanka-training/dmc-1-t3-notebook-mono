# AGENTS

## Purpose

This file is the bootstrap entry point for AI agents working in the repository.

It defines the minimal required context, the canonical documentation set, and the source-of-truth order for task execution.

## Ownership

This file is a repository-level execution policy.

It is owned by the repository maintainers and technical leadership, not by one implementation role.

Skill files created by AI engineers under `.agent/skills/` or `.agents/` are supplemental execution aids.

Skill files do not replace `AGENTS.md` and do not override canonical project documents.

## Canonical Language

Use only English project documents as execution context.

Do not rely on Russian companion documents for implementation decisions.

## Required Reading Order

Before any non-trivial implementation task, read:

1. The current task artifact:
   - issue
   - change request
   - sprint task
   - explicitly approved task comment
2. [docs/requirements.md](./docs/requirements.md)
3. [docs/project.md](./docs/project.md)
4. [docs/system_architecture.md](./docs/system_architecture.md)
5. [docs/tech_stack.md](./docs/tech_stack.md)
6. Shared project quality and acceptance context when relevant:
   - [docs/qa-plan.md](./docs/qa-plan.md)
   - issue templates and task templates in `.github/`
7. Repository-specific architecture as needed:
   - [ui/docs/ui_architecture.md](./ui/docs/ui_architecture.md)
   - [api/docs/api_architecture.md](./api/docs/api_architecture.md)
8. Additional repository-specific documents when they exist:
   - `ui/docs/ci-cd.md`
   - `api/docs/ci-cd.md`
   - `api/docs/auth.md`
   - UI or API testing strategy documents in `docs/`
9. Relevant contracts, schemas, migrations, and tests when they exist
10. The actual code in the affected repository
11. Relevant skill files in `.agent/skills/` or `.agents/` when the current task explicitly matches that skill

## Source of Truth Order

When sources conflict, use this precedence:

1. Current approved task artifact
2. [docs/requirements.md](./docs/requirements.md)
3. System-level architecture and technology documents
4. Shared project quality and acceptance documents
5. Repository-specific architecture documents
6. Repository-specific operational, auth, and testing documents
7. Contracts, schema, and migration artifacts
8. Existing code and tests

## Supplemental Agent Instructions

Skill files under `.agent/skills/` or `.agents/` are supplemental.

They may define:

- role-specific workflows
- review procedures
- task planning patterns
- testing workflows
- branching or collaboration conventions

They must not override:

- task scope
- `docs/requirements.md`
- project architecture documents
- contract documents
- security rules

## Mandatory Execution Rules

- Follow the documented architecture.
- Do not expand task scope on your own.
- Do not add dependencies without approval.
- Do not change public contracts silently.
- Do not change architecture without updating documentation.
- Add or update tests for behavior changes.
- Run relevant verification before claiming completion.
- Treat user input, notebook content, AI-generated code, and external responses as untrusted.
- Never expose secrets in code, logs, or output.
- Use role-specific skill files only as supplemental instructions.

## Related Documents

- [docs/requirements.md](./docs/requirements.md)
- [docs/project.md](./docs/project.md)
- [docs/system_architecture.md](./docs/system_architecture.md)
- [docs/tech_stack.md](./docs/tech_stack.md)
- [docs/qa-plan.md](./docs/qa-plan.md)
- [ui/docs/ui_architecture.md](./ui/docs/ui_architecture.md)
- [api/docs/api_architecture.md](./api/docs/api_architecture.md)
