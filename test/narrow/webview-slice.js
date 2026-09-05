// Драйвер узкого end-to-end smoke для WebView-слайса. Выполняется внутри
// страницы (ExecuteScript) и работает ровно так, как работал бы человек:
// читает то, что показано, правит поле, жмёт «Применить». Никаких
// внутренних функций Vue не зовёт — иначе проверялся бы не тот путь.
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

  const setBlur = (v) => {
    const el = q('blurCheckMs')
    el.value = String(v)
    el.dispatchEvent(new Event('input', { bubbles: true }))
  }

  const text = (id) => (q(id) ? q(id).textContent : '')

  ;(async () => {
    try {
      // 1. getInitialState доехал: форма показывает значение из config.ini,
      //    а не умолчание, зашитое во фронтенд.
      await wait(() => q('blurCheckMs') && q('blurCheckMs').value === '250', 20000)
      await wait(() => /250/.test(text('blurApplied')), 5000)
      post('smoke.loaded-250')

      // 2. Значение вне допустимого диапазона. Проверку делает backend
      //    (SettingsNum), а не форма: её текст и должен доехать сюда.
      setBlur(5)
      await wait(() => !q('apply').disabled, 5000)
      q('apply').click()
      await wait(() => /допустимо от 10 до 60000/.test(text('status')), 15000)
      if (!/250/.test(text('blurApplied'))) throw new Error('applied-changed-on-error')
      post('smoke.rejected-5')

      // 3. Валидное значение: запись прошла, и canonical вернулся от AHK —
      //    «применено сейчас» меняется только из ответа, не локально.
      setBlur(300)
      await wait(() => !q('apply').disabled, 5000)
      q('apply').click()
      await wait(() => /Сохранено/.test(text('status')), 20000)
      await wait(() => /300/.test(text('blurApplied')), 5000)
      post('smoke.saved-300')

      // 4. Закрытие через тот же протокол.
      post('smoke.done')
    } catch (e) {
      post('smoke.failed:' + String((e && e.message) || e).slice(0, 60))
      post('smoke.done')
    }
  })()
})()
