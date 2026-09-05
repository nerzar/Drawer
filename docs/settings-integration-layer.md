# ADR: минимальный integration layer для WebView Settings

**Статус:** принято; архитектурный gate Claude — GO

**Дата:** 2026-09-05; синхронизировано с production snapshot `a39f543`

**Область:** Vue ↔ AHK и согласованные seams C1–C5; полная декомпозиция
Drawer core и расширение Slot-модели остаются отдельным структурным этапом.

**Источник:** `claude/webview2-settings-review` @ `047c1b8`, файл
`spikes/webview2-settings/docs/settings-integration-layer.md` (совпадает
с версией в `codex/webview2-settings-spike`). Production-версия ADR теперь
находится в `docs/settings-integration-layer.md`.

## Production snapshot и gate

GO и порядок этапов подтверждены пользователем по результату gate Claude.
Это принятие архитектурного направления, а не отметка о готовом WebView.

`C1 stable Slot ID → C2 service-window registry → C3 structured SlotStatus → C4 Save outcome → C5 headless validation/config → WebView bridge → C6 native picker parity fix`

C1–C5 выполняются до production bridge; C6 native picker parity fix — после.
Критерии этапов находятся в `docs/05-план-работ.md`, решение закреплено в Р20
(`docs/03-решения.md`). Modular monolith + центральная Slot остаются принятым
направлением; новый transport не требует предварительного переноса всего core.

В `a39f543` работают native Settings и общий Save seam из `4844486`.
Production JSON bridge/DrawerSettingsPort ещё не подключены; DTO, error codes,
recovery metadata и lifecycle ниже описывают контракт интеграции, а не API,
уже реализованный в `src/drawer.ahk`. Функции Save перечислены в разделе
«Минимальный production seam» с текущими сигнатурами и оставшимися ограничениями.

Примеры wire DTO унаследованы из spike. Это не полный перечень полей текущей
формы: например, production `accent` уже сохраняется, но в примерах General
ниже ещё не представлен. При реализации port требуется сохранить поля текущего
Settings и их defaults, не принимать пример `steps: 8` за production default
(`LoadConfig` использует 14). Actions `slot.bind`/`slot.release` описывают port;
они не означают, что в native Settings уже есть такие UI-команды. Отдельная
production-команда освобождения одного dynamic-слота пока отсутствует.

## Контекст и решение

Текущий Settings задаёт нужную семантику: одно окно, локальный draft, совместная проверка General и Slots, запись только изменившихся значений, сверка чтением, Apply без закрытия, OK с закрытием и Cancel без сохранения с dirty-confirmation. Выбор EXE возвращает имя файла; выбор окна возвращает `exe`, class и title без сохранения HWND. Live status отражает runtime, а не draft.

Граница состоит из двух частей:

1. `SettingsJsonBridge` декодирует JSON, проверяет envelope, делает `switch action` и отправляет JSON через подтверждённый WebView adapter.
2. `DrawerSettingsPort` переводит semantic DTO в существующие операции Drawer. Только он знает о `config.ini`, `apps`, `managed`, `permSlots` и остальных внутренних структурах.

Vue владеет draft до успешного Apply/OK. AHK владеет применённым состоянием и live status. При ошибке draft остаётся во Vue; успешный Apply возвращает нормализованный snapshot, который становится новым baseline.

На wire существуют ровно три `type`:

- `request`: Vue → AHK, содержит уникальные в рамках окна `id`, `action`, `payload`;
- `response`: AHK → Vue, повторяет `id` и `action`, содержит `ok` и `result` либо `error`;
- `event`: AHK → Vue, не имеет `id`, потому что не отвечает на запрос.

Никакой RPC-зависимости не требуется. Native picker обрабатывает один запрос
за раз. Пока он открыт, разрешены только `settings.getInitialState` и
lifecycle-запрос `settings.cancel`; второй picker, Apply, OK, bind, release и
`slot.watchStatus` получают `busy`. Отмена picker — success с
`selected: false`. Gate снимается в `finally` при success, cancel и exception:
синхронность AHK не считается защитой от реентерабельности.

## Actions и DTO

| Action | Назначение |
|---|---|
| `settings.getInitialState` | General, слоты 1–9 и их live status |
| `settings.apply` | Проверить и сохранить draft, не закрывать окно |
| `settings.ok` | Сохранить draft и закрыть окно |
| `settings.cancel` | Сравнить draft с baseline, ничего не сохранять, при необходимости спросить подтверждение |
| `picker.exe` | Native FileSelect; вернуть только имя EXE |
| `picker.window` | Существующий native window picker |
| `slot.bind` | Привязать active eligible window к dynamic-слоту, runtime-only |
| `slot.release` | Освободить один dynamic-слот, runtime-only |
| `slot.watchStatus` | Включить/выключить существующий 400-мс poll при показе вкладки Slots |

General использует смысловые имена:

```json
{
  "dynamicDefaults": {
    "monitor": { "kind": "cursor" },
    "edge": "right",
    "widthPercent": 60,
    "activateOnShow": true,
    "hideOnBlur": true
  },
  "handlesEnabled": true,
  "animation": { "durationMs": 160, "steps": 8 },
  "blurCheckMs": 250
}
```

Dynamic-слот содержит read-only `effective` и `permanentDefaults`, которыми текущий Settings заполняет форму при «Сделать постоянным». Permanent-слот содержит редактируемый `value`. Live status отделён от draft.

Допустимые status: `empty`, `applicationNotRunning`, `available`, `parked`, `shown`. Для найденного окна AHK добавляет `windowTitle`.

## Основные JSON-сообщения

Примеры snapshot сокращены до одного слота; нормативный initial/apply state всегда содержит все девять.

### Initial state

```json
{ "type": "request", "id": "req-1", "action": "settings.getInitialState", "payload": {} }
```

```json
{
  "type": "response",
  "id": "req-1",
  "action": "settings.getInitialState",
  "ok": true,
  "result": {
    "protocolVersion": 1,
    "general": {
      "dynamicDefaults": {
        "monitor": { "kind": "cursor" }, "edge": "right", "widthPercent": 60,
        "activateOnShow": true, "hideOnBlur": true
      },
      "handlesEnabled": true,
      "animation": { "durationMs": 160, "steps": 8 },
      "blurCheckMs": 250
    },
    "slots": [{
      "number": 2,
      "kind": "dynamic",
      "label": "Слот 2",
      "effective": {
        "monitor": { "kind": "cursor" }, "edge": "right", "widthPercent": 60,
        "activateOnShow": true, "hideOnBlur": true
      },
      "permanentDefaults": {
        "name": "Слот 2", "executable": "", "windowClass": "",
        "monitor": { "kind": "cursor" }, "edge": "right", "widthPercent": 60,
        "activateOnShow": true, "hideOnBlur": true, "focusHotkey": ""
      },
      "status": { "state": "empty" }
    }]
  }
}
```

### General и permanent/dynamic editing

General передаётся целиком, `slotEdits` содержит только затронутые слоты. `{kind:"dynamic"}` означает conversion permanent → dynamic; permanent `value` создаёт либо изменяет постоянный слот.

```json
{
  "type": "request",
  "id": "req-2",
  "action": "settings.apply",
  "payload": {
    "draft": {
      "general": {
        "dynamicDefaults": {
          "monitor": { "kind": "cursor" }, "edge": "left", "widthPercent": 55,
          "activateOnShow": true, "hideOnBlur": true
        },
        "handlesEnabled": true,
        "animation": { "durationMs": 160, "steps": 8 },
        "blurCheckMs": 250
      },
      "slotEdits": [{
        "number": 3,
        "kind": "permanent",
        "value": {
          "name": "Terminal", "executable": "WindowsTerminal.exe",
          "windowClass": "CASCADIA_HOSTING_WINDOW_CLASS",
          "monitor": { "kind": "number", "number": 1 },
          "edge": "bottom", "widthPercent": 65,
          "activateOnShow": true, "hideOnBlur": false, "focusHotkey": ""
        }
      }]
    }
  }
}
```

```json
{
  "type": "response",
  "id": "req-2",
  "action": "settings.apply",
  "ok": true,
  "result": {
    "saved": true,
    "changedFields": 4,
    "changedSlots": [3],
    "restartRequiredFields": [],
    "state": { "protocolVersion": 1, "general": {}, "slots": [] }
  }
}
```

`state` выше сокращён; реальный success возвращает полный нормализованный snapshot. При отсутствии изменений `saved` равен `false`, счётчики нулевые.

### OK и Cancel

`settings.ok` имеет тот же `{draft}`. После success bridge сначала отправляет response с `closing: true`, затем планирует закрытие WebView на следующем AHK tick.

```json
{
  "type": "response", "id": "req-3", "action": "settings.ok", "ok": true,
  "result": {
    "saved": true, "changedFields": 1, "changedSlots": [],
    "restartRequiredFields": [], "closing": true
  }
}
```

Cancel также получает полный draft: до Apply/OK AHK иначе не может определить dirty-state.

```json
{
  "type": "request", "id": "req-4", "action": "settings.cancel",
  "payload": { "draft": { "general": {}, "slotEdits": [] } }
}
```

`general` в сокращённом примере означает полный General DTO. Response `{closed:false}` означает отказ пользователя от закрытия; `{closed:true}` отправляется перед закрытием без записи.

### Pickers

```json
{ "type": "request", "id": "req-5", "action": "picker.exe", "payload": {} }
```

```json
{
  "type": "response", "id": "req-5", "action": "picker.exe", "ok": true,
  "result": { "selected": true, "executable": "notepad.exe" }
}
```

```json
{
  "type": "response", "id": "req-6", "action": "picker.window", "ok": true,
  "result": {
    "selected": true,
    "window": { "title": "Документ — Блокнот", "executable": "Notepad.exe", "windowClass": "Notepad" }
  }
}
```

Picker не возвращает config path, HWND или индекс AHK-массива.

### Bind, release, events и errors

```json
{ "type": "request", "id": "req-7", "action": "slot.bind", "payload": { "slot": 4 } }
```

```json
{
  "type": "response", "id": "req-7", "action": "slot.bind", "ok": true,
  "result": { "slot": 4, "status": { "state": "available", "windowTitle": "Документ — Блокнот" } }
}
```

Release использует тот же result:

```json
{ "type": "request", "id": "req-8", "action": "slot.release", "payload": { "slot": 4 } }
```

AHK кеширует последний status и отправляет event только при изменении:

```json
{
  "type": "event", "event": "slot.statusChanged",
  "data": { "slot": 4, "status": { "state": "parked", "windowTitle": "Документ — Блокнот" } }
}
```

Системный крестик не уничтожает WebView сразу. AHK просит Vue прислать текущий draft обычным `settings.cancel`:

```json
{ "type": "event", "event": "settings.closeRequested", "data": { "reason": "window" } }
```

`settings.closed` означает, что решение о закрытии уже принято, `Dispose`
выполнен, а уничтожение WebView запланировано на следующий AHK tick. Это
последнее best-effort сообщение, а не подтверждение получения сообщения Vue.
`origin` называет источник lifecycle, `forced` отличает timeout/host shutdown
от решения пользователя:

```json
{
  "type": "event", "event": "settings.closed",
  "data": { "reason": "cancel", "origin": "nativeWindow", "forced": false }
}
```

```json
{
  "type": "response", "id": "req-9", "action": "settings.apply", "ok": false,
  "error": {
    "code": "validation_error",
    "message": "Слот 3: exe обязателен для постоянного слота",
    "field": "slots.3.executable",
    "retryable": true
  }
}
```

Стабильные codes: `invalid_request`, `unsupported_action`, `validation_error`,
`write_failed`, `verify_failed`, `busy`, `slot_is_permanent`,
`no_eligible_active_window`, `not_bound`, `internal_error`. UI ветвится по
`code`; `message` показывает человеку существующий текст AHK.

После `write_failed`/`verify_failed` запись могла частично изменить файл.
Такой error не обещает rollback и содержит recovery metadata и актуальный
state, если reload удался:

```json
{
  "type": "response", "id": "req-10", "action": "settings.apply", "ok": false,
  "error": {
    "code": "write_failed", "message": "Часть настроек могла сохраниться",
    "retryable": true,
    "partial": { "mayHavePersisted": true, "runtimeReloaded": true },
    "state": { "protocolVersion": 1, "general": {}, "slots": [] }
  }
}
```

## Минимальные TypeScript-типы

```ts
type RequestId = string
type SlotNumber = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
type Edge = 'left' | 'right' | 'top' | 'bottom'
type MonitorRef = { kind: 'cursor' } | { kind: 'number'; number: number }

type SlotBehavior = {
  monitor: MonitorRef
  edge: Edge
  widthPercent: number
  activateOnShow: boolean
  hideOnBlur: boolean
}

type GeneralSettings = {
  dynamicDefaults: SlotBehavior
  handlesEnabled: boolean
  animation: { durationMs: number; steps: number }
  blurCheckMs: number
}

type PermanentSlotValue = SlotBehavior & {
  name: string
  executable: string
  windowClass: string
  focusHotkey: string
}

type SlotStatus =
  | { state: 'empty' | 'applicationNotRunning' }
  | { state: 'available' | 'parked' | 'shown'; windowTitle: string }

type SlotState =
  | {
      number: SlotNumber; kind: 'dynamic'; label: string
      effective: SlotBehavior; permanentDefaults: PermanentSlotValue
      status: SlotStatus
    }
  | {
      number: SlotNumber; kind: 'permanent'
      value: PermanentSlotValue; status: SlotStatus
    }

type SettingsState = {
  protocolVersion: 1
  general: GeneralSettings
  slots: SlotState[]
}

type SlotEdit =
  | { number: SlotNumber; kind: 'dynamic' }
  | { number: SlotNumber; kind: 'permanent'; value: PermanentSlotValue }

type SettingsDraft = { general: GeneralSettings; slotEdits: SlotEdit[] }

type ErrorCode =
  | 'invalid_request' | 'unsupported_action' | 'validation_error'
  | 'write_failed' | 'verify_failed' | 'busy'
  | 'slot_is_permanent' | 'no_eligible_active_window'
  | 'not_bound' | 'internal_error'

type Req<A extends string, P> = {
  type: 'request'; id: RequestId; action: A; payload: P
}

type Request =
  | Req<'settings.getInitialState', Record<string, never>>
  | Req<'settings.apply' | 'settings.ok' | 'settings.cancel', { draft: SettingsDraft }>
  | Req<'picker.exe' | 'picker.window', Record<string, never>>
  | Req<'slot.bind' | 'slot.release', { slot: SlotNumber }>
  | Req<'slot.watchStatus', { enabled: boolean }>

type SaveSummary = {
  saved: boolean
  changedFields: number
  changedSlots: SlotNumber[]
  restartRequiredFields: `slots.${SlotNumber}.focusHotkey`[]
}

type Ok<A extends Request['action'], R> = {
  type: 'response'; id: RequestId; action: A; ok: true; result: R
}

type SuccessResponse =
  | Ok<'settings.getInitialState', SettingsState>
  | Ok<'settings.apply', SaveSummary & { state: SettingsState }>
  | Ok<'settings.ok', SaveSummary & { closing: true }>
  | Ok<'settings.cancel', { closed: boolean }>
  | Ok<'picker.exe', { selected: false } | { selected: true; executable: string }>
  | Ok<'picker.window',
      { selected: false } |
      { selected: true; window: { title: string; executable: string; windowClass: string } }>
  | Ok<'slot.bind' | 'slot.release', { slot: SlotNumber; status: SlotStatus }>
  | Ok<'slot.watchStatus', { enabled: boolean }>

type ErrorResponse = {
  type: 'response'
  id: RequestId
  action: Request['action']
  ok: false
  error: {
    code: ErrorCode
    message: string
    field?: string
    retryable: boolean
    details?: { reason?: 'invalid_hotkey' | 'hotkey_conflict' }
    partial?: { mayHavePersisted: true; runtimeReloaded: boolean }
    state?: SettingsState
  }
}

type Event =
  | { type: 'event'; event: 'slot.statusChanged'; data: { slot: SlotNumber; status: SlotStatus } }
  | { type: 'event'; event: 'settings.closeRequested'; data: { reason: 'window' } }
  | {
      type: 'event'; event: 'settings.closed'
      data: {
        reason: 'ok' | 'cancel' | 'drawerExit' | 'nativeCloseTimeout'
        origin: 'frontend' | 'nativeWindow' | 'host'
        forced: boolean
      }
    }

type Response = SuccessResponse | ErrorResponse
type ProtocolMessage = Request | Response | Event
```

## Публичный AHK port и переиспользование

Bridge вызывает только semantic API и не получает live AHK-объекты:

```ahk
class DrawerSettingsPort {
    GetInitialState()
    Save(draft, closeAfter := false)
    Cancel(draft)
    PickExe()
    PickWindow(ownerHwnd)
    BindActive(slotNumber)
    ReleaseDynamic(slotNumber)
    GetSlotStatuses()
    Dispose()
}
```

| Port | Переиспользовать | Тонкая обёртка позже |
|---|---|---|
| `GetInitialState` | `SettingsRows`, `SlotCfg`, `SettingsEditSeed` | Semantic DTO без sections и внутренних коллекций |
| `Save` General | `SettingsGeneralPlan`, `SettingsApplyPlan` | Semantic DTO → существующий internal input; structured outcome в C4 |
| `Save` Slots | `SettingsSlotsPlan`, `SettingsSlotValidate`, `SettingsSlotWrites`, `SettingsApplyPlan` | Строить тот же plan из `slotEdits`, а не `setUI.edits`; не копировать persistence |
| `PickExe` | `SettingsPickExe` | Упаковать `""` как `{selected:false}` |
| `PickWindow` | `SettingsWindowCandidates`, `SettingsPickWindow` | Передать WebView owner, переименовать `exe/cls/title`, не отдавать HWND |
| `BindActive` | `BindSlot`, `PickActive` | `BindSlot` возвращает outcome только через `Notify`; преобразовать те же guards в structured result/error |
| `ReleaseDynamic` | `Release`, существующие операции с `dynSlots` | Отдельной команды пока нет; dynamic-only: release HWND, удалить binding, запланировать `HandlesSync`; permanent → `slot_is_permanent` |
| `GetSlotStatuses` | `SettingsAppPeek`, `HandleManaged`, `HandleParked` | Вернуть enum + title напрямую, не разбирать локализованный `SettingsSlotStatus` |
| `Cancel` | Правило `SettingsClose` | Сравнить draft с baseline и использовать WebView как owner dirty-confirmation |
| `Dispose` | `SettingsSlotsTimer(false)`, закрытие `setPickerGui` | Идемпотентно остановить watcher/picker независимо от причины закрытия |

`SettingsSave` нельзя вызывать из bridge напрямую: он читает native GUI,
пишет в native status label и сам закрывает окно. Операции plan и
persist/reconcile уже выделены; native Settings — первый клиент, WebView port
станет вторым клиентом тех же функций. C4/C5 завершают их outcome и headless
контракт без второй реализации persistence.

AHK v2 не имеет встроенного JSON parser. Реализации понадобится один локальный codec `Decode`/`Encode`, но не RPC framework; codec остаётся внутренней деталью `SettingsJsonBridge`.

## События AHK → Vue

- `slot.statusChanged`: AHK polling замечает запуск/закрытие, bind/release, parked/shown. Poll включён только через `slot.watchStatus` и прекращается при уходе со вкладки или закрытии Settings.
- `settings.closeRequested`: системный крестик просит Vue прислать актуальный draft через `settings.cancel`.
- `settings.closed`: AHK сообщает причину непосредственно перед уничтожением WebView.

Apply/OK, picker, bind и release не дублируются success-events: authoritative результат уже связан с request через response `id`. Status event после bind/release возможен только при включённом watcher и фактическом изменении.

## История adversarial review до production seam

Ниже зафиксированы исходные замечания к раннему spike и legacy Settings,
а не открытые дефекты snapshot `a39f543`. Lifecycle/picker решения приведены
в следующем разделе и реализованы в spike; production получает их на этапе
bridge. Порядок Save исправлен в `4844486`/`a39f543`; structured error/recovery
контракт ещё требует C4.

- **Системный крестик.** `WebViewAdapter.Close()`
  (`host/WebViewAdapter.ahk:49`) привязан прямо к событию `Close` окна и
  рушит WebView синхронно и безусловно. Сценарий с `closeRequested` выше
  требует отложенного закрытия до ответа Vue — сейчас адаптер такой отсрочки
  не даёт и не имеет тайм-аута на случай, если Vue не ответит (зависшая
  вкладка, необработанное исключение в JS до подписки на сообщение). Нужно
  решить, как `SettingsJsonBridge` перехватывает `Close` и через какой
  тайм-аут рушит WebView принудительно, если ответа нет.

- **Apply/OK при частичной записи.** `SettingsSave` → `SettingsSlotsApply`
  (`src/drawer.ahk:2488`, `:2361`) пишут `[dynamic]`/`[general]` и `[slotN]`
  раздельными проходами; `LoadConfig()`, обновляющий живые `apps`/`dynamic`,
  вызывается только при полном успехе слотов. Если General уже записан и
  сверен, а запись слота падает, runtime остаётся на старых значениях, а
  `config.ini` — в смешанном состоянии; `ErrorResponse` при этом не несёт
  `state`, которым можно было бы восстановить канон. Нужно решить: либо
  `LoadConfig()` безусловно после любой попытки записи, либо `state` в
  error-ответе.

- **Native picker и реентерабельность.** `SettingsPickWindow`/`SettingsPickExe`
  не отключают окно Settings на время модального диалога (нет
  `WinSetEnabled`), а `WinWaitClose`/`FileSelect` качают очередь сообщений —
  то есть `WebMessageReceived` может прийти реентерабельно, пока пикер ещё на
  стеке. Текст выше описывает `busy` только для «несовместимого» запроса к
  пикеру; нужно явно перечислить, что ещё блокируется на время пикера
  (Apply/OK/bind/watchStatus) и как bridge это отслеживает.

Помельче:

- `focusHotkey` в DTO — сырая AHK-строка хоткея (используется как
  `Hotkey(Hooked(...))`, `src/drawer.ahk:166`); формат и код ошибки
  «занято/некорректно» не описаны, а смена вступает в силу только после
  перезапуска Drawer (в нативной форме это прямо подписано — «после
  перезапуска», `src/drawer.ahk:2090`). В протоколе этого предупреждения нет.
- `DrawerSettingsPort` из 8 методов не имеет явного `Dispose`/`StopWatch`:
  таймер `slot.watchStatus` и `setPickerGui` сейчас останавливаются только
  через штатный `SettingsClose()`; при закрытии в обход него (см. пункт про
  крестик выше) их некому остановить.

## Решения по результатам adversarial review

### Close lifecycle

`SettingsWebViewAdapter` больше не уничтожает controller из native `Close`.
Он передаёт событие bridge и возвращает `true`, отменяя системное закрытие.
Bridge держит состояния `open → awaitingDecision → closing → closed`:

1. Первый native Close отправляет один `settings.closeRequested` и запускает
   timeout 5 секунд. Повторные Close в `awaitingDecision` игнорируются.
2. Vue отвечает обычным `settings.cancel` либо `settings.ok`. Отказ от Cancel
   возвращает bridge в `open`; успешное решение сначала получает response.
3. При принятом решении без активной операции bridge один раз вызывает
   `Dispose`, отправляет один `settings.closed` и уничтожает WebView на
   следующем AHK tick.
4. Если Vue не ответил, timeout выполняет тот же путь с
   `reason=nativeCloseTimeout`, `origin=nativeWindow`, `forced=true`.
5. Если cancel, timeout или host shutdown приходят, пока native picker ещё на
   стеке, bridge переводит lifecycle в `closing`, сохраняет pending close и не
   вызывает ни `Dispose`, ни `Destroy`. Picker-response и последующие решения
   закрытия в состоянии `closing` игнорируются. `finally` сначала снимает
   `operation=picker`, затем выполняет pending cleanup/`settings.closed` и
   только после этого допускает единственный `Destroy`.
6. Host shutdown без активного picker вызывает синхронный идемпотентный вариант
   с `reason=drawerExit`. Во время picker синхронность ограничена безопасной
   границей: teardown завершается сразу после возврата native picker.

`Dispose` обязан остановить status watcher, отменить его timers, закрыть
`setPickerGui`/активный native dialog и больше ничего не делать при повторном
вызове. Bridge не вызывает `Dispose` реентерабельно из стека picker.
`settings.closed` отправляется после выхода picker и успешного первого вызова
`Dispose`; оно фиксирует начало уничтожения transport, но не утверждает, что Vue
успел получить сообщение или что процесс WebView2 уже умер.

### Picker operation gate

Bridge выставляет `operation=picker` до вызова port и снимает его только в
`finally`. Во время picker:

- `picker.exe`, `picker.window`, `settings.apply`, `settings.ok`, `slot.bind`,
  `slot.release`, `slot.watchStatus` отвечают `busy`;
- `settings.getInitialState` разрешён как read-only и не меняет watcher;
- `settings.cancel` разрешён как аварийный lifecycle path, чтобы закрытие и
  cleanup не могли зависнуть за picker;
- неизвестный action остаётся `unsupported_action`, а не маскируется как busy.

### Save pipeline и canonical state после partial failure

Общий seam обязан выполнять три отдельные стадии:

1. `validate/plan` проверяет и нормализует весь draft, строит disk mutations и
   runtime reconciliation plan без `IniWrite`, `IniDelete`, `LoadConfig`,
   `Release` и иных side effects;
2. `persistence+verify` выполняет все planned writes/deletes и их read-back
   verification, но не меняет runtime;
3. `runtime reconciliation` запускается только после полного выхода из
   persistence loop. При полном успехе она применяет сохранённую конфигурацию;
   после начатой partial mutation — best-effort применяет фактическое устойчивое
   содержимое файла.

`Release()` находится только в третьей стадии. Reconciliation получает snapshot
старых slot identities/bindings из plan, выполняет `LoadConfig`, переиндексирует
`permSlots`/`managed` и лишь затем освобождает окна, чьи slot identity исчезли
или изменились. Поэтому planned conversion или edit больше не освобождает
dynamic binding до первой дисковой операции.

До первой дисковой мутации canonical applied state — текущий runtime. После
успешного `IniWrite` или `IniDelete` canonical persistence state — фактическое
содержимое `config.ini`, даже если весь Apply завершился ошибкой. Rollback не
обещается. Reload нельзя запускать внутри активного `IniWrite`/`IniDelete` catch
до завершения unwind.

`write_failed` и `verify_failed` возвращают `partial.mayHavePersisted=true`.
При успешном reload они также возвращают `runtimeReloaded=true` и полный
актуальный `state`; Vue заменяет applied baseline этим state, но сохраняет draft
и явно показывает, что Apply завершился частично. При неудачном reload state
не возвращается, `runtimeReloaded=false`, `retryable=false`: окно не должно
притворяться, что знает применённое состояние.

Если runtime уже изменился в recovery reconciliation после неудачной
persistence или из-за legacy side effect, ответ всё равно остаётся
`write_failed`/`verify_failed`, а не превращается в success. При успешном
reconciliation `state` описывает уже фактический runtime, включая live slot
status; frontend сравнивает его с прежним baseline и не показывает rollback.
При неудачном reconciliation bridge возвращает `runtimeReloaded=false` без
`state`; уже совершённые runtime side effects не откатываются и не скрываются.

Удаление секции тоже проверяется до success: после `IniDelete(path, section)`
повторный `IniRead(path, section, , "")` должен подтвердить отсутствие данных.
Несовпадение — `verify_failed` с тем же partial/reload path.

### Минимальный production seam

Реализован в `4844486`, скорректирован в `a39f543`:

| Функция | Текущий контракт |
|---|---|
| `SettingsGeneralPlan(input, &err)` | Semantic input без controls → точечные General writes; сравнение с runtime через `SettingsLive`. |
| `SettingsSlotsPlan(edits, &err)` | Edits → writes/deletes/touched и snapshot `oldBySlot`/`oldIdent`; без записи и Release. |
| `SettingsPersistVerified(generalWrites, slotPlan, &outcome)` | INI writes/deletes/readback; outcome `{ok, code, err, mayHavePersisted}` с кодами `write_failed`/`verify_failed`; не вызывает `Release`/`LoadConfig`. |
| `SettingsReconcileRuntime(slotPlan)` | Перечитывает INI, обновляет настройки/кромки, переиндексирует Permanent по номеру, сохраняет HWND при неизменных exe/cls и освобождает исчезнувшие/изменённые bindings. |
| `SettingsApplyPlan(generalWrites, slotPlan, &outcome)` | Persist, затем reconcile при `persist.mayHavePersisted`; обе стадии под `try`; outcome `{saved, code, err, retryable, changedWrites, changedDeletes, changedSlots, restartRequired, mayHavePersisted, runtimeReloaded, state}`. |
| `SettingsStateSnapshot()` | Канонический снимок применённого состояния: General плюс девять слотов с конфигом и живым `SlotStatus`. Имена полей внутренние; перевод в wire-имена — работа порта. |
| `SettingsEdgeIn` / `SettingsMonitorIn` / `SettingsAccentIn` / `SettingsBoolIn` / `SettingsTextIn` | Backend-валидация семантического входа: enum края, `cursor`/номер монитора, 6 hex акцента, строгий bool, запрет CR/LF. Первая ошибка отменяет разбор. |
| `LoadConfig(..., &diags)` / `ConfigDiagShow(diags)` | Загрузка без GUI: замечания к файлу возвращаются списком, показ — забота вызывающего. |
| `SettingsCollect` / `SettingsSlotsCollect` | Native UI-adapters для двух plan-функций. |
| `SettingsSave` | Вызывает общий seam, затем обновляет native status/rebase/close. |

В `a39f543` `SettingsVerifyDeleted` использует
`IniRead(path, sec, , "")`; исключение чтения возвращает false, а не успех.
Reconciliation освобождает dynamic binding тронутого номера только при
`dynSlots.Has(n) && permSlots.Has(n)` после `LoadConfig` и пересборки
`permSlots`. Не записавшаяся conversion не освобождает оставшийся Dynamic.

C4 закрыл outcome-часть. `retryable` считается как «диск не тронут, либо
рантайм успешно перечитан»: запрет повтора нужен там, где применённое
состояние неизвестно, а не там, где файла вообще не касались. Успешная
persistence с упавшим reload — `internal_error`, а не success. Снимок
`state` отдаётся только вместе с `runtimeReloaded=true`.

C5 закрыл headless-часть. `LoadConfig`/`IniBool` не показывают MsgBox:
замечания возвращаются списком `diags`, а показывает их вызывающий —
`ConfigDiagShow` при старте, native после Save, порт полем ответа.
Семантический вход проверяется до записи: `SettingsEdgeIn`,
`SettingsMonitorIn`, `SettingsAccentIn`, `SettingsBoolIn`, `SettingsTextIn`
и проверка номера/типа слота в `SettingsSlotsPlan`. Проверяется форма
значения, а не окружение: `monitor=7` на двух мониторах остаётся
допустимым, потому что `config.ini` переносится между машинами.

Оставшееся:

- `focusHotkey` проверяется только на CR/LF. Пробный
  `Hotkey(Hooked(value), noop, "Off")` из этого ADR не реализован: он
  создаёт настоящий hotkey, то есть side effect в стадии validate/plan, и
  на комбинации, совпадающей со слотовой, отключил бы живой хоткей. Порту
  нужен отдельный безопасный способ проверки синтаксиса и конфликтов.
- Plan читает runtime globals (`SettingsLive`/`SettingsLiveSlot`): точечная
  запись сравнивает с тем, чем программа пользуется сейчас. Отдельного
  config-объекта у backend нет, и для bridge он не нужен.
- `oldBySlot` изменяется reconciliation: plan не является повторно используемым
  immutable snapshot. На каждый Save план строится заново.

WebView port должен строить internal input и вызывать эти же plan/apply
функции. `setUI`/controls не передаются backend; HWND snapshots, INI sections,
`configPath` и runtime globals остаются внутри AHK и не выходят на wire.

### focusHotkey и structured errors

`focusHotkey` на wire — строка синтаксиса AutoHotkey v2 (`^!t`, `#n` и т.п.);
пустая строка отключает дополнительный focus binding. Port обрезает только
краевые пробелы и запрещает CR/LF. Syntax проверяется созданием отключённого
hotkey через `Hotkey(Hooked(value), noop, "Off")`, то есть тем же AHK parser,
но без включения binding до restart. Конфликт проверяется внутри draft с
фиксированными slot hotkeys и другими `focusHotkey`; внешний процесс для
hooked-hotkey не является проверяемым конфликтом. Некорректность и внутренний
конфликт возвращаются единым `validation_error` с `field` и
`details.reason=invalid_hotkey|hotkey_conflict`; новый top-level error code не
нужен. Success с изменённым `focusHotkey` содержит
`restartRequiredFields`, потому что, как и в native Settings, изменение начинает
действовать только после перезапуска Drawer.

## Что реализовано в первом vertical slice

Production-код: `src/webview/Json.ahk` (codec), `SettingsWebView.ahk`
(транспорт), `SettingsJsonBridge.ahk` (конверт, диспетчер, lifecycle
закрытия), `SettingsPort.ahk` (`DrawerSettingsPort`), `SettingsWebHost.ahk`
(пункт трея, служебное окно, завершение). Фронтенд: `settings-ui/src/bridge/`
— `protocol.ts` и типизированный `client.ts` с корреляцией по `id`.

Работают `settings.getInitialState`, `settings.apply`, `settings.ok` и
`settings.cancel`. Apply строит внутренний вход и зовёт
`SettingsGeneralPlan` → `SettingsApplyPlan`; своей записи у порта нет.

Отклонения от текста ADR, принятые сознательно:

- `SaveResult` содержит `diagnostics: string[]` — замечания перечитанного
  `config.ini`, которые с C5 возвращает `LoadConfig`. В мосте показать их
  MsgBox'ом нельзя: он заблокировал бы очередь сообщений WebView.
- `MonitorRef` получил вариант `{kind:"invalid", raw}`. Значение вроде
  `monitor=abc` из правленого руками файла не эквивалентно `cursor`:
  `ResolveMonitor` на нём бросает, и форма должна показать, что там лежит.
- `accent` на wire нет: цвет в slice не входит, порт подставляет
  действующее значение, и точечная запись его не трогает.
- `error.field` заполняется только для ошибок формы DTO, которые ловит сам
  порт. Границы значений проверяет backend, и его сообщение приходит без
  `field`: вычислять путь поля разбором русского текста — ровно то, от
  чего уводил C3.
- Picker operation gate не реализован: в slice нет ни одной операции,
  которую он охраняет. `picker.*`, `slot.bind`, `slot.release` и
  `slot.watchStatus` отвечают `unsupported_action`.
- `settings.cancel` закрывает окно без сравнения draft с baseline:
  dirty-confirmation остаётся у native Settings.
- `settings.closed` отправляется, `slot.statusChanged` — нет: watcher не
  подключён.

Страница отдаётся не через `file://`, а через
`SetVirtualHostNameToFolderMapping`: модульные скрипты Vite с `file://`
браузер блокирует как cross-origin.

## Последствия

- Vue можно разрабатывать на fixture `SettingsState` без знания способа хранения.
- AHK остаётся единственным местом валидации, записи и runtime side effects.
- Передача внутренних коллекций и chatty RPC по одному полю не нужны.
- Следующий production шаг — C1, затем C2–C5, WebView bridge и C6 по принятому gate. JSON codec/transport из spike подключаются к общему backend; этот ADR не означает перенос spike-кода в production.
