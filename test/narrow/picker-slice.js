;(() => {
  if (window.__drawerSmoke) return
  window.__drawerSmoke = true
  const q = (id) => document.querySelector(`[data-testid="${id}"]`)
  let seq = 0
  let pickerResponses = 0
  const pending = new Map()
  const rpc = (action, payload = {}) => new Promise((resolve) => {
    const id = 'picker-smoke-' + ++seq
    pending.set(id, resolve)
    chrome.webview.postMessage({ type: 'request', id, action, payload })
  })
  chrome.webview.addEventListener('message', ({ data }) => {
    if (typeof data === 'string') data = JSON.parse(data)
    if (data.type === 'response' && data.action?.startsWith('picker.')) pickerResponses++
    if (pending.has(data.id)) { pending.get(data.id)(data); pending.delete(data.id) }
  })
  const mark = (name) => void rpc('smoke.' + name)
  const wait = async (fn) => {
    for (let i = 0; i < 200; i++) {
      if (fn()) return
      await new Promise((r) => setTimeout(r, 50))
    }
    throw new Error('wait-timeout')
  }
  ;(async () => {
    try {
      await wait(() => q('blurCheckMs'))
      document.querySelectorAll('.navitem')[1].click()
      await wait(() => q('pick-window'))
      const name = q('edit-name')
      name.value = ''
      name.dispatchEvent(new Event('input', { bubbles: true }))
      mark('window-success')
      q('pick-window').click()
      await wait(() => q('edit-name').value === 'Picker fixture')
      if (q('edit-windowClass').value !== 'AutoHotkeyGUI') throw new Error('window-class')
      const before = [...document.querySelectorAll('.slot-editor input')].map((el) => el.value).join('|')
      let responses = pickerResponses
      mark('window-cancel')
      q('pick-window').click()
      await wait(() => pickerResponses > responses)
      await wait(() => !q('apply').disabled)
      if ([...document.querySelectorAll('.slot-editor input')].map((el) => el.value).join('|') !== before) throw new Error('cancel-writeback')
      mark('exe-success')
      responses = pickerResponses
      q('pick-exe').click()
      await wait(() => pickerResponses > responses)
      await wait(() => !q('apply').disabled)
      if (q('edit-executable').value !== 'notepad.exe') throw new Error('exe-result')
      mark('exe-cancel')
      responses = pickerResponses
      q('pick-exe').click()
      await wait(() => pickerResponses > responses)
      await wait(() => !q('apply').disabled)
      if (q('edit-executable').value !== 'notepad.exe') throw new Error('exe-cancel-writeback')
      mark('picker-success-cancel')
      mark('gate-hold')
      q('pick-exe').click()
      await wait(() => q('apply').disabled)
      for (const action of ['settings.apply', 'settings.ok', 'picker.exe', 'picker.window', 'slot.bind', 'slot.release', 'slot.watchStatus']) {
        const result = await rpc(action)
        if (result.error?.code !== 'busy') throw new Error('gate-' + action)
      }
      mark('picker-gate')
      // Owner native Close while picker remains on the stack; dirty-close
      // confirms discard through the production frontend.
      mark('close-picker')
      await wait(() => q('confirm'))
      mark('done')
      q('discard').click()
    } catch (e) {
      mark('failed:' + e.message)
      mark('done')
      void rpc('settings.cancel', { discardChanges: true })
    }
  })()
})()
