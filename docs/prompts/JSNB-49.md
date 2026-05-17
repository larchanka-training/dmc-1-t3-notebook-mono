# Prompts archive — JSNB-49 (D-01 Frontend Foundation: login screen + auth guard)

> Reconstructed record of the agent prompts used to execute JSNB-49 — the
> driver layer. Task bodies are not duplicated here.

## Methodology

Executed via the `superpowers` skill chain:

1. **`superpowers:brainstorming`** — explored the login-screen/auth-guard
   intent with the operator; design locked.
2. **`superpowers:writing-plans`** — produced the task-by-task implementation
   plan (Tasks 1–8).
3. **`superpowers:subagent-driven-development`** — each task dispatched to a
   fresh `general-purpose` subagent, then reviewed.

Per-subagent prompts were **generated at dispatch time** from the
`superpowers:subagent-driven-development` templates (v5.1.0): implementer,
spec-compliance reviewer, code-quality reviewer.

## Dispatch grouping (as actually run)

| Tasks                        | Implementer                    | Review                                          |
|------------------------------|--------------------------------|-------------------------------------------------|
| 1, 2, 3, 4 (each separately) | one fresh implementer per task | spec-compliance **then** code-quality, per task |
| 5 + 6 (combined)             | one combined implementer       | —                                               |
| 7 (green gate)               | one implementer                | —                                               |
| 8 (localStorage persist)     | one implementer                | —                                               |
| 5–8 together                 | —                              | one combined spec + code-quality review         |

Combined runs for 5–8 were an operator-requested cost reduction (fewer
subagents), not a methodology change. The earlier 3-task foundation
(tooling / store / shell) was executed the same way on 2026-05-15.

Working directory for every implementer/reviewer:
`dmc-1-t3-notebook-mono/ui` (the `ui` submodule; branch `feature/JSNB-49`).

---

## Implementer prompts

Each was the implementer-prompt template with these fields filled.

| #     | `description`                                          | Task gist (as dispatched)                                                                                                                                                                                             |
|-------|--------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| T1    | `Implement Task 1: Brand component`                    | New reusable logo+wordmark; no props; consumed next by `AppHeader`. TDD: failing `Brand.test.tsx` first.                                                                                                              |
| T2    | `Implement Task 2: AppHeader uses Brand, gated nav`    | Depends on T1. Nav (`Notebooks` link) renders only when `useAppStore(s => s.auth.isAuthenticated)`.                                                                                                                   |
| T3    | `Implement Task 3: RequireAuth guard`                  | New `src/app/RequireAuth.tsx`: `Outlet` if authed else `<Navigate to="/login" replace/>`. Test with `createMemoryRouter`.                                                                                             |
| T4    | `Implement Task 4: Routing restructure`                | Depends on T3. Single `AppLayout` root; `index`+catch-all → `/login`; `/notebooks*` under `RequireAuth`.                                                                                                              |
| T5+T6 | `Implement Tasks 5–6: LoginPage two-step + mock auth`  | Combined per operator. Two-step `request → verify`, local React state, `setAuthenticated(true,email)` on `MOCK_OTP`, redirect-if-authed, wrong-code inline error, Google = no-op stub, native HTML5 email validation. |
| T7    | `Implement Task 7: full green gate + stale-test sweep` | Run lint/typecheck/test/build; sweep tests stale after the routing/login rework (none needed).                                                                                                                        |
| T8    | `Implement Task 8: persist mock auth across reload`    | zustand `persist` + `createJSONStorage` on `localStorage`, key `js-notebook-auth`, `partialize` auth only; no new dependency; test isolation added to `src/test/setup.ts`.                                            |

Template-fixed sections passed unchanged each time: **Before You Begin**
(ask before starting), **Your Job** (implement → TDD tests → verify →
commit → self-review → report), **Code Organization**, **When You're in
Over Your Head** (escalate BLOCKED/NEEDS_CONTEXT), **Self-Review**
(completeness/quality/discipline/testing), **Report Format**
(DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT).

Executor conventions in scope for every implementer: no DOM-lib type
identifiers (ESLint `no-undef`); `FormEvent` without generic; untyped inline
`onChange`; jsdom doesn't enforce HTML5 validation; `createMemoryRouter` for
guard/redirect tests; `--max-warnings 0`; commit per task (consolidation by
operator at round close).

---

## Spec-compliance reviewer prompts

Dispatched after each implementer (per-task for T1–T4; one combined pass for T5–T8).

- `description`: `Review spec compliance for Task N`
- **What Was Requested**: the same task requirements pasted to the implementer.
- **What Implementer Claims**: the implementer's report.
- Fixed directive: *do not trust the report* — read the actual code, compare
  to requirements line by line, flag missing pieces and unrequested extras.

## Code-quality reviewer prompts

Dispatched only after the matching spec review passed.

- `DESCRIPTION`: task summary from the implementer's report
- `PLAN_OR_REQUIREMENTS`: Task N
- `BASE_SHA`: commit before the task · `HEAD_SHA`: commit after the task
- Extra checks: one responsibility per file with a clear interface;
  independently testable units; file structure matches the plan; no
  newly-created-but-already-large files.
- Returns: Strengths · Issues (Critical/Important/Minor) · Assessment.

> Note on SHAs: per-task commits were later consolidated by the operator
> (`git reset --soft 15fb536` + selective re-add) into the 4 by-meaning
> commits on `feature/JSNB-49`. Base ref `15fb536`; consolidated heads
> `6fcceeb` (tooling) · `8becbe0` (store) · `2f3cc66` (shell/routing) ·
> `26202d7` (login + guard). The pre-consolidation per-task SHAs used in
> the original review dispatches are not all preserved after the soft-reset
> rewrite.

## Outcome

All spec and code-quality reviews returned "ready to merge" (no Critical
issues). One implementer-resolved item: `tsc` middleware-mutator mismatch in
`store/index.ts` from composing `persist` over the slice `StateCreator` —
resolved with a cast `as StateCreator<AppState,[["zustand/persist",unknown]],[],AppState>`
(no slice files touched), confirmed idiomatic by the combined review.

---

## User instructions (verbatim, chronological)

_В цитатах пути к не-git / удалённым файлам элидированы (`…`); внешние
GitHub-URL сохранены как первоисточник._

0. `Спланируй выполнение задача https://github.com/larchanka-training/js-notebook/issues/49 согласно документации, архитектуре тех стеку и др. данным. Если версии библиотек нигде не указаны, то выбере те которые сомвестимы между собой и безопасны. В плане также должны быт тесты.` → план задачи из issue #49 по канон-докам/архитектуре/тех-стеку; безопасные совместимые версии библиотек; тесты в плане обязательны.

### Фаза A — закрытие foundation-раунда

1. `кол-во коммитов сам выбери` → выбрано 3 foundation-коммита.
2. `как запустить локально?` → инструкция локального запуска (`cd ui && npm i && npm run dev`).
3. `запушу сам, дальше что по задаче?` → push/PR — на операторе; план остатка.
4. `сверь с acceptance criteria issue #49` → фактчек по критериям issue #49.

### Фаза B — фича: экран логина + auth guard

5.
`1. страница логина должна быть тоже с логтиппом и тд, тоесть внутри базового шаблона, подумай еще норм или нет, как обычно делают в лучших компаниях. 2. на странице логина должен быть какой то переключать в плане выбора авторизации, что думаешь?` →
логин внутри `AppLayout` + `Brand`; обсуждение способов авторизации.
6. `2 точне one time code олжен появляться когда отправили запрос на смс` → двухшаговый OTP (request → verify).
7.
`3. первая странциа должна быть логин, а не notebook. 4. и без авторизации нельзя открыть другие страницы. Пока можно замокать, что при любом email потом можно внести 1234 и попасть дальше` →
`/login` стартовый, `RequireAuth` guard, mock `1234`.
8. `подтверждаю` → дизайн утверждён (HARD-GATE снят → реализация).
9. `… зачем сбда сохраегяешь. Есть ведь …` → дизайн+план свёрнуты в единый task spec (single source).
10. `почему так много тратиться токенов и 20 tools используется?` → экономный режим (объединённые implementer/review для T5–T8).

### Фаза C — коммиты, правила, доки

11. `мок одноразовый пароль, к примеру 1234 не нужно показывать в коммите` → `1234` убран из commit-message (`--amend`, дерево сохранено).
12. `еще можно сгруппировать?` / `сгруппируй коммиты` → доп. консолидация коммитов по смыслу.
13. `в коммитах должно быть обознаение задачи, доабвь это в правила и примени к моим коммитам` → правило `[<TICKET>]` в
    воркфлоу-инструкции + filter-branch префикс `[JSNB-49]`.
14. `создай шаблон для мр. что добалвено, что изменено, что удалено, как проверить, риски. И покажи шаблон для мр для этой задачи` → создан
    PR-шаблон.
15. `в гитхаб не нужно добавлять шаблон мр` / `в docs` / `или в клоде темплейтес` / `… есть что-то такое что клод может использовать?` →
    шаблон не добавлять в GitHub-репо; память-указатель.
16.
`можешь добавить в флоу задачи, что когда я говорю что задача готова к ревью, то ты автоматом мне показываешь шаблон заполненый по обрзцу` →
авто-триггер «ready for review → заполненный PR-шаблон».
17. `добавь правило отвечать на русском` → язык интерфейса = ru + память.

### Фаза D — ревью

18. `/aif-review jsnb 49` (дважды) → прогон ревью-скилла (status `warn`, блокеров нет).
19. `отправил на ревью` → ветка/PR отправлены.
20. `Замечаний пока нет, жду апрува` → ждём апрув.
21. `обнови доку по задаче` → синхронизация документации.
