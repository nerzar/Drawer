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
  const post = (action) =>
    window.chrome.webview.postMessage({
      type: 'request',
      id: 'smoke-' + ++seq,
      action,
      payload: {},
    })

  const q = (id) => document.querySelector('[data-testid="' + id + '"]')

  const wait = (fn, ms) =>
    new Promise((ok, no) => {
      const t0 = Date.now()
      const tick = () => {
        let v = false
        try {
          v = fn()
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
      post('smoke.done')
      q('cancel').click()
    } catch (e) {
      post('smoke.failed:' + String((e && e.message) || e).slice(0, 60))
      post('smoke.done')
    }
  })()
})()
