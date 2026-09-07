# Independent manual-failure analysis — multi-monitor runtime regression

- Task ID: `RUN-20260907-OPENCODE-MUSE13-MANUAL-MULTIMON-INDEPENDENT-ANALYSIS-01`
- Run ID: `RUN-20260907-OPENCODE-MUSE13-MANUAL-MULTIMON-INDEPENDENT-ANALYSIS-01`
- Agent/client: `OpenCode`
- Model: `Muse Spark 1.3 Contributor Free`
- Chat/session ID: `NOT_EXPOSED`
- Chat title: `NOT_EXPOSED`
- Search anchor: `Drawer TASK MANUAL-MULTIMON-INDEPENDENT-ANALYSIS-01 — opencode-muse13/20260907`
- Started at: `2026-09-07T07:03:31+03:00`
- Finished at: `2026-09-07T10:36:47+03:00`
- Worktree: `C:\Users\nerza\Projects\drawer-settings-integration`
- Branch: `analysis/manual-multimon-regression-muse13`
- Base SHA: `cd6dc00b3d58c6abea709687618ea3702432bc45`
- Code SHA: `NONE`
- Report tip SHA: `PENDING_FINAL_COMMIT`
- Remote: `dev`

> INDEPENDENT DRAFT — собственная гипотеза/evidence зафиксированы ДО чтения `docs/agent-reports/2026-09-07-antigravity-manual-multimon-failure-analysis.md`. Сравнение с Antigravity — в разделе 9 после фиксации.

## 1. Goal

Независимо локализовать регрессию ручного приёма на failed candidate `cd6dc00` vs accepted `6bfa010`: monitor-2 deployment стартует/анимируется с monitor-1, origin не совпадает с cursor/target, одна кромка исчезала, при зелёных narrow/validate. Определить first bad lineage, проверить делят ли анимация и handle-loss общую причину, предложить regression test. Analysis-only, без правок production/tests.

## 2. Result

- Сравнение `6bfa010..cd6dc00`: 9 линейных коммитов, без merge/conflict resolutions: `2bab75c` (focus extract), `42a16ee` (focus fix F1/F2/P17), `a31bb41` (test-only), `5ed8b9a` (geometry extract A03S1), `26b1133` (geometry brace fix B1), `815e0e9`/`6e5a71c`/`fae1850` (handles A04S1/S2/S3), `cd6dc00` (test-only).
- `ResolveMonitor`, `HitsMonitor`, `CaptureOrigin`, `ResolveMonitorForExisting`, `Slide`, `ToggleWindow`, `Show`/`Hide` скелет, `HandlesSync` группировка `mi|edge` — логически сохранены. `Slots.ahk` пуст (no diff).
- Доказанный first bad commit: `5ed8b9a` — небрасованный `Loop MonitorGetCount()` с двумя строками тела (`MonitorGet` + `monitors.Push`). В AHK v2 без braces циклится только первая строка, `Push` выполняется один раз после цикла → `monitors` из 1 rect (последний монитор) вместо N. Для внутреннего края `WindowGeometryPlan.slide` ложно `true` → `Show` делает `WinMove(hx)` на соседе + `Slide(hx→sx)` через чужой экран. Пин-тест `26b1133:A8/A9` это доказывает: полный `monitors[2]` → `slide=false`, усечённый `[1]` → `slide=true`.
- `26b1133` чинит braces и присутствует в candidate (`cd6dc00` включает fix, проверено чтением `ComputeGeom` в candidate: `Loop MonitorGetCount() {`). Значит brace-дефект объясняет линейку до fix, но НЕ объясняет текущий провал candidate С fix. Ручной провал записан `2026-09-07T06:54` после сборки candidate `06:36`, включающей fix. Green narrow не предсказали, т.к. pure `WindowGeometryPlan` тесты стабят мониторы и не исполняют живой адаптер на N>1; pin `26b1133` проверяет только форму исходника, не runtime на N>1.
- Остаточный дефект — вне pure геометрии. Кандидаты: неверный `mi` (cursor race между `Show` и `HandlesSync`) вместо неверного `slide`. `Show` использует `ResolveMonitor(cfg)` в момент хоткея, `HandlesSync` — тот же `ResolveMonitor(s.cfg)` в момент редкого таймера (`HANDLE_SYNC=4`) и `SetTimer(HandlesSync,-1)`. Для `monitor=cursor` они расходятся при движении курсора между sync и показом: кромка на одном мониторе, деплой на другом; смена группы `mi|edge` уничтожает/создаёт кромку с задержкой → «исчезновение» на одном такте. Эта интеракция стабнута в narrow (нет курсора/мониторов) и не покрыта.
- Handle-loss однократно + flaky указывает на race/transient (`keep` miss → `HandleDestroy` → пересоздание через 4 такта; `WindowManaged` false при `st.geom=0`; `try mi:=ResolveMonitor` skip), а не детерминированную геометрию. Общая причина с анимацией правдоподобна через общий `mi` (cursor), но не доказана: brace-`slide` объясняет только анимацию, не handle-loss (handles не используют `monitors[]`/`slide`).
- Integration conflict resolutions: в линейке `6bfa010..cd6dc00` merge нет, резолвов нет. Конфликтные по смыслу точки — `42a16ee:F1` (дубли focus-функций под `#Include`, был EXIT 2), `42a16ee:F2/P17` (`WatchForget` watcher-only vs `WindowFocusForget` full; `RestoreFocus(hwnd,st)` → `RestoreFocus(hwnd)`), `HandleLighten` валидация + clamp, `TrackedFore` +2 класса (`XamlExplorerHostIslandWindow`, `MultitaskingViewFrame`). Поведенчески эквивалентны после fix, на monitor-origin не влияют по чтению.

## 3. Commits

- Анализ на `refs/remotes/dev/wip/slots-parity=3ba05ec`, `refs/remotes/dev/integration/manual-candidate-20260907=cd6dc00`, accepted `6bfa010`.
- Собственных production/test коммитов нет (`Code SHA: NONE`). Только claim + report docs по протоколу board.

## 4. Important decisions

- До фиксации этого драфта отчёт Antigravity не читался (требование task).
- Проверены точные refs, а не локальные ветки; `origin` не тронут.
- `Slots.ahk` — no diff, исключён как источник.
- `ComputeGeom` в candidate прочитан напрямую — braces на месте, fix присутствует.
- Ручной провал датирован после fix — brace alone недостаточен, зафиксированы две гипотезы (H1 slide, H2 mi race) с разной предсказательной силой.

## 5. Problems found

- P1 (доказан, first bad): `5ed8b9a:src/drawer.ahk:ComputeGeom` — голый `Loop MonitorGetCount()` + 2 строки. AHK v2: только `MonitorGet` в цикле, `Push` один раз. `monitors=[last]` → `slide=true` на внутреннем крае. Источник неверной анимации с соседа. Починен в `26b1133`, но пин — source-form, не N>1 runtime.
- P2 (остаточный, вероятный): cursor-`mi` race `Show(mi@t_hotkey)` vs `HandlesSync(mi@t_sync)` для `monitor=cursor`. Группы `mi|edge`, `HandleBase(MonitorGetWorkArea(mi))`, `st.geom` от прошлого `Show`, `IsDeployed` допуск 4px — всё сходится только если курсор не двигался. Narrow это не ловит (стабы). Объясняет и «origin≠cursor», и мигание/потерю кромки (group switch → destroy/create).
- P3 (flaky handle): `HandlesSync:keep` miss уничтожает кромку сразу (`HandleDestroy`), пересоздание — не раньше следующего `HandlesSync` (до 4×`HANDLE_SLOW=50ms` + `HandleTick` live). Однократное исчезновение согласуется с transient `!WindowManaged` / `ResolveMonitor` throw-skip / `HandleBase=0`.
- P4 (gates): `window-geometry-seam` (49 checks), `window-geometry-adapter-seam` (A1–A9 source pin), `window-handles-seam`, `window-focus-seam` — все single-host, без `MonitorGetCount>1` runtime. Поэтому зелёные при живом провале.

## 6. Tests / verification

- Статический дифф `6bfa010..cd6dc00 --stat` + построчный разбор `drawer/WindowFocus/WindowGeometry/WindowHandles/Slots` (9 коммитов, `Slots` пуст).
- Прямое чтение `ComputeGeom` в `5ed8b9a` (голый Loop) vs `26b1133`/`cd6dc00` (брасованный Loop) + `WindowGeometryPlan` слайд-логика vs `HitsMonitor` (побайтово эквивалентны при полном `monitors`).
- Проверка всех `Loop MonitorGetCount` в candidate: `ResolveMonitor(Loop n)`, `ComputeGeom`, `HitsMonitor`, `ResolveMonitorForExisting` — все брасованы; `SettingsMonItems` голый Loop с одной строкой — корректен; `Loop 9` с `try`/`if` — single-statement, корректны.
- Проверка `HandleBaseCalc/GrownCalc/TargetCalc/FaceCalc` vs старые `HandleBase/Grown/Target/Face` — эквивалентны при дефолтах `22/34/8`, `alpha=205+...`, `on=(t>=36)`.
- Проверка `Watch/WatchForget/WindowFocusForget/RestoreFocus/Show(prev)/Hide/Release` до/после `42a16ee` — эквивалентны после fix (watcher-only в `Hide`, full только в `Release`).
- AHK runtime на N>1 прогнать нечем (нет AutoHotkey в PATH, одномониторный хост) — поэтому без новых N>1 логов вердикт ниже консервативный. Предложенный regression simulation (п.8) исполним на single-host стабами.

## 7. Known issues / unfinished

- Не читался Antigravity failure-analysis до фиксации (намеренно).
- Нет dual-monitor runtime логов (`DebugLog [SHOW]/[HIDE]/[TOGGLE]`, `MonitorGetCount`, `MouseGetPos`, `SlotCfg.monitor/edge`, `st.geom.{sx,sy,hx,hy,px,py,slide,mi}`, `HandlesSync groups/keep`, topology `MonitorGet/WorkArea/SysGet 76-79`).
- Не определён точный `edge/monitor` слотов пользователя в провале (left/right/top/bottom, cursor vs explicit).
- Не установлено, делят ли анимация и handle-loss один `mi` или это два независимых дефекта (slide vs sync).

## 8. Suggested next step

- Собрать runtime bundle на dual-monitor: topology (`MonitorGet/WorkArea` для 1..N, `SysGet 76-79`, DPI), `SlotCfg` всех слотов, `DebugLog` Hide/Show с `mi/geom/slide`, курсор в момент хоткея vs sync, `HandlesSync groups/keep` до/после.
- Наименьший safe fix-кандидат (без гаданий): удержать `26b1133`, добавить simulation regression test (single-host, стабы `MonitorGetCount=2`, `MonitorGet`, `SysGet`, `MouseGetPos`): (a) `ComputeGeom`-эквивалент на внутреннем `left` monitor-2 → `slide=false`; (b) усечённый `monitors[1]` → `slide=true` (ловит B1); (c) `HandlesSync` grouping стабилен при cursor move 1→2 только после `Show` (фиксирует H2 контракт). Тест должен падать на `5ed8b9a` (a) и на любом `mi`-дрейфе (c), проходить на `6bfa010` и на починенном candidate.
- До N>1 ретеста заморозить `A03S2/A03S3/A05` (как уже решено board), пересобрать один candidate и сделать ранний dual-monitor re-test.

## 9. Comparison with Antigravity failure-analysis (заполнено ПОСЛЕ фиксации п.2–п.8)

Прочитан `docs/agent-reports/2026-09-07-antigravity-manual-multimon-failure-analysis.md` (`RUN-20260907-AUTO-ANTIGRAVITY-MANUAL-MULTIMON-FAILURE-ANALYSIS-01`, verdict `READY_FOR_FIX`) только после фиксации драфта выше. П.2–п.8 не менялись, кроме этого раздела и `Finished at`.

### Совпадения

- First bad `5ed8b9a` brace bug: обе диагностики независимо указывают один и тот же голый `Loop MonitorGetCount()` → `monitors=[last]` → ложный `slide=true` на внутреннем крае. A8/A9 логика идентична.
- `26b1133` присутствует в `cd6dc00`, но провал сохраняется: обе диагностики фиксируют, что source-form pin недостаточен без N>1 runtime.
- Cursor-`mi` race `Show(mi@t_hotkey)` vs `HandlesSync(mi@t_sync)` для `monitor=cursor`: моя H2 (п.2/P2) совпадает с Root Cause A Antigravity (`HandlesSync:338` → `ResolveMonitor(s.cfg)` + `MouseGetPos` каждый `HANDLE_SYNC=4`, `HandleTick 16/50ms`). Оба фиксируют `Slots.ahk` без диффа и `SlotBound`/`WindowManaged`/`mi|edge` группировку как место дрейфа.
- Слепота narrow gates к N>1: обе диагностики указывают pure стабы + отсутствие живого `MonitorGetCount>1`/`MouseGetPos` взаимодействия.
- Линейка без merge: я зафиксировал 9 линейных коммитов без резолвов; Antigravity не противоречит (фокус на lineage `5ed8b9a`/`26b1133`/`fae1850`).

### Расхождения / дополнения

- Разделение симптомов: Antigravity делит жёстко — Symptom 1+3 share Root Cause A (mi-pinning), Symptom 2 distinct Root Cause B (pocket/parking teleport `px=vL±...` → `WinMove(hx)` → `Slide`). Я фиксировал общую `mi`-причину как правдоподобную, но недоказанную, т.к. brace-`slide` не объясняет handle-loss (handles не используют `slide`). Деление Antigravity точнее моего: принимаю split A/B как рабочий.
- Parking teleport: Antigravity добавляет видимый кадр `WinMove(px→hx)` через seam даже при корректном `slide=true` на внешнем крае. Я отмечал parking как invisible и не акцентировал DWM-кадр перехода — это упущение моего драфта, засчитываю как дополнение Antigravity.
- Атрибуция `fae1850`: Antigravity называет его усилителем (таймер/re-group без стабилизации `mi`); я фиксировал `fae1850` как чистый move без логических изменений. Противоречия нет: код идентичен, разница только в том, что move сохранил предсуществовавший `ResolveMonitor`-дрейф из `6bfa010`. Active regression — `5ed8b9a`, дрейф `mi` — предсуществовавший, ставший видимым на N>1.
- `TrackedFore` +2 класса / `HandleLighten` валидация / `F1/F2/P17`: я перечислил как non-causal; Antigravity их не упоминает — согласие по существу (не причины monitor-origin).
- Regression probe: Antigravity предлагает конкретный cursor-probe (`mx=500`→`mi=1` vs `mx=2500`→`mi=2`, handle телепортируется без движения окна). Мой п.8 предлагал тот же класс (c) + (a)/(b) для `slide`. Совместимы; объединить в один simulation test.

### Итоговый вердикт после сравнения

- Исходный вердикт драфта (`BLOCKED_NEEDS_RUNTIME_DATA` для остаточного `mi/slide`) сохраняется как честная фиксация на момент независимости.
- После сравнения присоединяюсь к `READY_FOR_FIX` в узком смысле Antigravity: (1) `HandlesSync` → `ResolveMonitorForExisting(s.cfg,s.hwnd)` для managed окон; (2) стабилизация `mi` в `Show`; (3) строгий `slide=false` при пересечении соседа + simulation test (a)/(b)/(c). Без нового candidate rebuild/fix в этой analysis-only задаче.
- Для architect gate: брать fix-план Antigravity п.8 как базу, мой п.8 как дополнение пина (a)/(b) + требование раннего dual-monitor re-test до разморозки `A03S2/A03S3/A05`.

- Verdict после сравнения: `READY_FOR_FIX` (узкий mi-pinning + slide hardening + simulation test), runtime bundle из моего п.8 — как верификация, не блокер.

---

*Search anchor: `Drawer TASK MANUAL-MULTIMON-INDEPENDENT-ANALYSIS-01 — opencode-muse13/20260907`*
