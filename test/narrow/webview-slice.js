// Драйвер узкого end-to-end smoke вкладки General. Выполняется внутри
// страницы (ExecuteScript) и работает ровно так, как работал бы человек:
// читает то, что показано, правит поля, жмёт кнопки. Никаких внутренних
// функций Vue не зовёт — иначе проверялся бы не тот путь.
//
// Отчёт идёт по самому протоколу: неизвестный action получает
// unsupported_action и попадает в трассировку моста. Отдельного канала
// для теста в production нет и не должно быть.
;(() => {
  if (window.__drawerSmoke) return
  window.__drawerSmoke = true

  let seq = 0
  let initialResponses = 0
  let statusEvents = 0
  let watching = false
  const pending = new Map()
  window.chrome.webview.addEventListener('message', ({ data }) => {
    if (typeof data === 'string') data = JSON.parse(data)
    if (data.type === 'response' && data.action === 'settings.getInitialState' && data.ok) {
      initialResponses++
      canonical = data.result
    }
    if (data.type === 'event' && data.event === 'slot.statusChanged') statusEvents++
    if (data.type === 'response' && data.action === 'slot.watchStatus' && data.ok) watching = data.result.enabled
    if (pending.has(data.id)) {
      pending.get(data.id)(data)
      pending.delete(data.id)
    }
  })
  const post = (action) =>
    window.chrome.webview.postMessage({
      type: 'request',
      id: 'smoke-' + ++seq,
      action,
      payload: {},
    })
  const rpc = (action, payload = {}) =>
    new Promise((resolve) => {
      const id = 'smoke-rpc-' + ++seq
      pending.set(id, resolve)
      window.chrome.webview.postMessage({
        type: 'request',
        id,
        action,
        payload,
      })
    })

  const q = (id) => document.querySelector('[data-testid="' + id + '"]')

  const wait = (fn, ms) =>
    new Promise((ok, no) => {
      const t0 = Date.now()
      const tick = async () => {
        let v = false
        try {
          v = await fn()
        } catch (e) {
          v = false
        }
        if (v) return ok(v)
        if (Date.now() - t0 > ms) return no(new Error('timeout'))
        setTimeout(tick, 60)
      }
      tick()
    })

  // v-model слушает input у текстовых полей и change у select/checkbox.
  const setText = (id, v) => {
    const el = q(id)
    el.value = String(v)
    el.dispatchEvent(new Event('input', { bubbles: true }))
  }
  const setPick = (id, v) => {
    const el = q(id)
    el.value = String(v)
    el.dispatchEvent(new Event('change', { bubbles: true }))
  }
  const setCheck = (id, v) => {
    const el = q(id)
    el.checked = v
    el.dispatchEvent(new Event('change', { bubbles: true }))
  }

  const val = (id) => (q(id) ? q(id).value : null)
  const text = (id) => (q(id) ? q(id).textContent : '')
  const eq = (id, want) => {
    if (val(id) !== want) throw new Error(id + '=' + val(id) + ' want ' + want)
  }

  const apply = async (done) => {
    await wait(() => q('apply') && !q('apply').disabled, 5000)
    q('apply').click()
    await wait(done, 20000)
  }

  ;(async () => {
    try {
      // 1. getInitialState доехал: форма показывает ВСЮ General из
      //    config.ini, а не умолчания, зашитые во фронтенд.
      await wait(() => val('blurCheckMs') === '250', 20000)
      eq('widthPercent', '70')
      eq('edge', 'right')
      eq('monitorKind', 'cursor')
      eq('animPreset', 'normal')
      eq('animMs', '160')
      eq('animSteps', '14')
      eq('accent', '2A2E35')
      if (!q('handlesEnabled').checked) throw new Error('handles-off')
      await wait(() => /250/.test(text('blurApplied')), 5000)
      post('smoke.loaded-full')

      // Explicit baseline request also lets the driver compare all nine DTO rows.
      post('settings.getInitialState')
      await wait(() => canonical, 5000)
      const initialCount = initialResponses
      const tab = (name) => [...document.querySelectorAll('.navitem')].find((el) => el.textContent.trim() === name).click()
      setText('blurCheckMs', '251')
      tab('Slots')
      await wait(() => q('slot-9') && watching, 5000)
      if (document.querySelectorAll('.slotrow').length !== 9) throw new Error('slots-count')
      for (const slot of canonical.slots) {
        const row = q('slot-' + slot.number)
        const value = slot.kind === 'permanent' ? slot.value : slot.effective
        if (!row.textContent.includes(value.widthPercent + '%')) throw new Error('slot-value-' + slot.number)
        if (row.dataset.status !== slot.status.state) throw new Error('slot-state-' + slot.number)
      }
      // Утверждённая строка списка: номер с именем, род и живое
      // состояние точкой. Ни одного из них дизайн не отдаёт под номер в
      // аватарке, поэтому номер проверяется именно в имени.
      if (!text('slot-1').includes('1. Smoke permanent')) throw new Error('row-name')
      if (!text('slot-1').includes('Постоянный')) throw new Error('row-pill-perm')
      if (!text('slot-9').includes('Динамический')) throw new Error('row-pill-dyn')
      if (!q('slot-1').querySelector('.dot')) throw new Error('row-status-dot')
      eq('edit-name', 'Smoke permanent')
      eq('edit-focusHotkey', '^!#1')
      eq('edit-widthPercent', '61')
      // Смена рода стоит на утверждённом месте, но выключена: порт её
      // не принимает, и кнопка не должна обещать больше, чем есть.
      if (!q('make-dynamic') || !q('make-dynamic').disabled) throw new Error('conversion-perm')
      q('slot-5').click()
      await wait(() => text('slot-width') === '43', 5000)
      if (q('slots').querySelector('input,select')) throw new Error('dynamic-editable')
      if (!text('slot-detail').includes('Монитор 2')) throw new Error('dynamic-override')
      if (!q('make-permanent') || !q('make-permanent').disabled) throw new Error('conversion-dyn')
      // Таблица динамического слота называет источник каждого значения.
      // Сравнение точное: «из [dynamic]» — подстрока «из [dynamicSlot5]».
      const sources = [...q('slot-detail').querySelectorAll('.detail-row .s')].map((el) => el.textContent.trim())
      if (!sources.includes('из [dynamicSlot5]')) throw new Error('dyn-source-own')
      if (!sources.includes('из [dynamic]')) throw new Error('dyn-source-shared')
      if (!text('slot-detail').includes('Ctrl + Alt + 5')) throw new Error('dyn-hotkey')
      q('slot-1').click()
      await wait(() => q('edit-name'), 5000)
      setText('edit-name', 'Unsaved slot')
      const steadyEvents = statusEvents
      await new Promise((resolve) => setTimeout(resolve, 500))
      if (statusEvents !== steadyEvents) throw new Error('unchanged-status-event')
      post('smoke.slots-ready')
      await wait(() => q('slot-1').dataset.status === 'available', 5000)
      await wait(() => text('slot-title') === 'Slots smoke title', 5000)
      post('smoke.slots-available')
      await wait(() => text('slot-title') === 'slots smoke title', 5000)
      eq('edit-name', 'Unsaved slot')
      post('smoke.slots-title')
      await wait(() => q('slot-1').dataset.status === 'applicationNotRunning', 5000)
      if (text('slot-title') !== '—') throw new Error('stale-title')
      tab('General')
      await wait(() => !watching && q('blurCheckMs'), 5000)
      eq('blurCheckMs', '251')
      const eventsBefore = statusEvents
      post('smoke.slots-away')
      await new Promise((resolve) => setTimeout(resolve, 1000))
      if (statusEvents !== eventsBefore) throw new Error('watch-while-away')
      tab('Slots')
      await wait(() => watching && text('slot-title') === 'Slots reentry', 5000)
      eq('edit-name', 'Unsaved slot')
      if (initialResponses !== initialCount) throw new Error('slots-reloaded-settings')
      tab('General')
      await wait(() => !watching && q('blurCheckMs'), 5000)
      setText('blurCheckMs', '250')
      post('smoke.slots-done')

      // Bind and release guards and live operations.
      //
      // Утверждённого UI у этих операций нет, поэтому драйвер зовёт их
      // самим протоколом. Проверяется то же, что и раньше: коды отказов
      // порта и живое состояние слота, доехавшее до списка событием
      // slot.statusChanged. Замена canonical state из ответа bind/release
      // остаётся за unit-тестами settings-ui/test/canonical.test.ts.
      tab('Slots')
      await wait(() => watching && q('slot-4'), 5000)
      q('slot-4').click()
      await wait(() => q('slot-detail'), 5000)
      if (q('bind-slot') || q('release-slot')) throw new Error('invented-bind-ui')

      const badBind = await rpc('slot.bind', { slot: 0 })
      if (badBind.ok || badBind.error?.code !== 'invalid_request') throw new Error('bind-invalid-slot')

      const permBind = await rpc('slot.bind', { slot: 1 })
      if (permBind.ok || permBind.error?.code !== 'slot_is_permanent') throw new Error('bind-permanent-slot')

      const badRelease = await rpc('slot.release', { slot: 10 })
      if (badRelease.ok || badRelease.error?.code !== 'invalid_request') throw new Error('release-invalid-slot')

      const permRelease = await rpc('slot.release', { slot: 1 })
      if (permRelease.ok || permRelease.error?.code !== 'slot_is_permanent') throw new Error('release-permanent-slot')

      const emptyRelease = await rpc('slot.release', { slot: 4 })
      if (emptyRelease.ok || emptyRelease.error?.code !== 'not_bound') throw new Error('release-empty-slot')

      // With no eligible active window, dynamic slot returns no_eligible_active_window
      const noWindow = await rpc('slot.bind', { slot: 4 })
      if (noWindow.ok || noWindow.error?.code !== 'no_eligible_active_window')
        throw new Error('bind-without-window')

      // Activate external fixture window
      post('smoke.bind-target')
      await wait(async () => {
        const r = await rpc('slot.bind', { slot: 4 })
        return r.ok && r.result.status.state === 'available'
      }, 5000)

      // Живое состояние доехало до списка и до карточки слота.
      await wait(() => q('slot-4').dataset.status === 'available', 5000)
      await wait(() => text('slot-title') === 'Bind fixture window', 5000)

      const released = await rpc('slot.release', { slot: 4 })
      if (!released.ok || released.result.status.state !== 'empty') throw new Error('release-failed')
      await wait(() => q('slot-4').dataset.status === 'empty', 5000)
      await wait(() => text('slot-title') === '—', 5000)

      // Release again returns not_bound
      const relAgain = await rpc('slot.release', { slot: 4 })
      if (relAgain.ok || relAgain.error?.code !== 'not_bound') throw new Error('release-again-not-bound')

      post('smoke.bind-release-done')
      post('smoke.bind-release-verified')

      // Slot-only dirty-close survives tab changes and invalid drafts.
      q('slot-1').click()
      await wait(() => q('edit-name'), 5000)
      q('cancel').click()
      await wait(() => q('confirm'), 5000)
      q('keep').click()
      await wait(() => !q('confirm'), 5000)
      eq('edit-name', 'Unsaved slot')
      const originalExe = val('edit-executable')
      setText('edit-widthPercent', '')
      await apply(() => /slots\.1\.widthPercent/.test(text('status')))
      if (!q('edit-widthPercent').className.includes('field-bad')) throw new Error('slot-field-error')
      setText('edit-widthPercent', '3')
      await apply(() => /допустимо от 5 до 100/.test(text('status')))
      setText('edit-widthPercent', '62')
      setText('edit-executable', '')
      await apply(() => /exe обязателен/.test(text('status')))
      if (!text('slot-1').includes('Smoke permanent')) throw new Error('slot-baseline-on-error')
      setText('edit-name', '') // Backend normalizes to Слот 1.
      setText('edit-executable', ' ' + originalExe + ' ')
      // Класс окна форма не правит: его заполняет picker. Здесь он
      // только показан, и уехать он обязан нетронутым.
      if (text('slot-class') !== 'AutoHotkeyGUI') throw new Error('slot-class-shown')
      setText('edit-focusHotkey', '^!#2')
      setPick('edit-monitorKind', 'cursor')
      setPick('edit-edge', 'top')
      setCheck('edit-activateOnShow', true)
      setCheck('edit-hideOnBlur', true)
      tab('General')
      await wait(() => q('blurCheckMs'), 5000)
      post('smoke.slot-validation')

      // 2. Ошибка формы: пустое число уезжает как null и возвращается
      //    структурированной ошибкой с именем поля — его и подсвечивает
      //    форма, не разбирая русский текст.
      setText('blurCheckMs', '')
      await apply(() => /general\.blurCheckMs/.test(text('status')))
      if (!q('blurCheckMs').className.includes('field-bad')) throw new Error('no-field-mark')
      if (!/250/.test(text('blurApplied'))) throw new Error('applied-changed-on-error')
      post('smoke.field-error')

      // 3. Граница значения: проверку делает backend (SettingsNum), а не
      //    форма, и его текст должен доехать сюда.
      setText('blurCheckMs', '250')
      setText('widthPercent', '3')
      await apply(() => /допустимо от 5 до 100/.test(text('status')))
      post('smoke.range-error')

      // 4. Правка четырёх полей разом: число, цвет, пресет анимации и
      //    чекбокс. Все они уезжают одним settings.apply.
      setText('widthPercent', '80')
      setText('blurCheckMs', '300')
      setPick('animPreset', 'fast')
      setCheck('handlesEnabled', false)
      q('swatch-332A35').click()
      await apply(() => /Сохранено/.test(text('status')))
      // Канонический state вернулся от AHK и заменил baseline: «применено
      // сейчас» меняется только из ответа, не локально.
      await wait(() => /300/.test(text('blurApplied')), 5000)
      eq('animMs', '100')
      eq('animSteps', '10')
      post('smoke.saved')
      tab('Slots')
      await wait(() => q('slot-9') && watching, 5000)
      eq('edit-name', 'Слот 1')
      eq('edit-executable', originalExe)
      if (text('slot-class') !== 'AutoHotkeyGUI') throw new Error('slot-class-after-save')
      eq('edit-widthPercent', '62')
      eq('edit-edge', 'top')
      if (!text('restart').includes('1')) throw new Error('slot-restart-hint')
      await apply(() => /Менять нечего/.test(text('status')))
      post('smoke.slot-saved')
      q('slot-9').click()
      await wait(() => text('slot-width') === '80', 5000)
      q('slot-5').click()
      await wait(() => text('slot-width') === '43', 5000)
      tab('General')
      await wait(() => !watching && q('blurCheckMs'), 5000)

      // 5. Несохранённое не выбрасывается молча: Отмена с грязным
      //    черновиком получает closed:false и спрашивает.
      setCheck('hideOnBlur', false)
      q('cancel').click()
      await wait(() => q('confirm'), 15000)
      q('keep').click()
      await wait(() => !q('confirm'), 5000)
      post('smoke.dirty-guarded')

      // 6. То же самое, но закрытие пришло системным крестиком: его
      //    инициирует AHK, увидев предыдущую отметку. Окно обязано
      //    остаться, а мост — вернуться в open.
      await wait(() => q('confirm'), 20000)
      q('keep').click()
      await wait(() => !q('confirm'), 5000)
      post('smoke.native-guarded')

      // 7. Тот же черновик вернули к применённому — терять нечего, и
      //    Отмена закрывает окно без вопроса.
      setCheck('hideOnBlur', true)
      tab('Slots')
      await wait(() => watching && q('slot-9'), 5000)
      setText('edit-name', 'Saved by OK')
      post('smoke.done')
      // Единственный клик, который раньше шёл без ожидания: у кнопки в
      // этот момент могло быть ещё disabled, и тогда click() молча не
      // делает ничего — окно остаётся открытым, а драйвер уже отчитался.
      await wait(() => q('ok') && !q('ok').disabled, 5000)
      q('ok').click()
    } catch (e) {
      post('smoke.failed:' + String((e && e.message) || e).slice(0, 60))
      post('smoke.done')
    }
  })()
})()
