# T3/BTF -> FRONT: Добавить rollout guardrails и feature-flag control для WebLLM

## Status

- `done`

## Цель

Сделать `WebLLM` управляемой и обратимой опцией, чтобы local mode можно было включать поэтапно, отключать без регрессии для canonical backend path и не выкатывать в неподдерживаемые environments случайно или без понятной product policy.

## Контекст

- `docs/plans/06-webllm-local-mode-plan.md`
- `docs/ai-architecture.md`
- `docs/tech_stack.md`
- frontend config boundaries:
  - `ui/src/shared/config/`
  - `ui/src/features/ai/`
- local mode UI task:
  - `docs/plans/tasks/webllm-local-mode-05-local-mode-and-retry-ui.md`

## Scope

- добавить frontend feature flag или equivalent runtime toggle для `WebLLM`
- зафиксировать intended rollout policy:
  - disabled by default
  - internal-only / dev-only
  - или public opt-in
- обеспечить, что disabled local mode не оставляет dead UI controls
- задокументировать expected browser/runtime caveats для developers и QA
- обеспечить, что выключение `WebLLM` не ломает backend-first AI flow

## Out of scope

- полноценная remote config platform
- analytics dashboards for local mode usage
- performance telemetry program
- изменения backend deployment model

## Технические ограничения

- canonical backend-first flow должен работать при полностью выключенном `WebLLM`
- rollout guard не должен зависеть от backend changes
- feature flag не должен вводить случайное расхождение между tests и runtime behavior без явной конфигурации

## Acceptance criteria

- [ ] `WebLLM` controlled by explicit frontend feature flag or equivalent runtime config
- [ ] Disabled local mode не показывает пользователю нерабочие local controls
- [ ] Rollout policy documented clearly enough for developers, QA, and product owner
- [ ] Полное отключение local mode не ломает existing backend AI UX
- [ ] Browser/model support caveats documented for implementation and QA

## Verification

- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] вручную проверить disabled-mode scenario
- [ ] вручную проверить enabled-mode scenario
- [ ] вручную сверить, что backend-first flow unaffected when local mode is off

## Dependencies

- `T3/BTF -> FRONT: Добавить explicit local-mode и retry-fallback UI для WebLLM`

## Files likely to change

- `ui/src/shared/config/`
- `ui/src/features/ai/`
- optional frontend env/docs
- `docs/ai-architecture.md`
- `docs/tech_stack.md`

## Documentation impact

- `Primary:`
- `docs/plans/tasks/webllm-local-mode-08-rollout-guards-and-feature-flag.md`
- `Likely:`
- `docs/ai-architecture.md`
- `docs/tech_stack.md`
- frontend config notes if needed

## Риски / заметки

- если local mode выкатывается без guardrails, он быстро станет неявным support burden для всех environments
- feature flag policy должна быть понятной не только инженерам, но и QA, иначе acceptance scenarios будут расходиться по средам
- хороший критерий: при выключенном flag пользователь должен видеть ровно тот же AI product, что и до появления `WebLLM`

## Completion update

- после выполнения обновить `Status` на `done` или `blocked`
- если rollout policy была выбрана как dev-only/internal-only/public opt-in, зафиксировать финальный выбор здесь

Выполнено:

- `WebLLM` переведен на явный frontend rollout guard через `VITE_WEBLLM_LOCAL_MODE_ROLLOUT_POLICY` + `VITE_WEBLLM_LOCAL_MODE_ENABLED`.
- Базовый режим оставлен `disabled by default`; для текущего delivery slice выбран intended rollout policy `dev-opt-in`.
- При выключенном rollout policy local `WebLLM` controls не рендерятся, а canonical backend-first AI flow остается единственным пользовательским путем.
- Caveats по secure context, `Web Worker`, `WebAssembly`, `WebGPU`, lazy bootstrap и environment-dependent model startup зафиксированы в `docs/ai-architecture.md`, `docs/tech_stack.md` и `ui/README.md`.
