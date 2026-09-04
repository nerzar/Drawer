// Placeholder for the future WebView2 <-> AHK host bridge.
// Every call is a no-op that only logs — no config.ini, no AHK core.
function stub(name) {
  return (...args) => {
    console.log(`[mock-bridge] ${name}`, ...args)
  }
}

export const bridge = {
  minimize: stub('minimize'),
  close: stub('close'),
  pickExe: stub('pickExe'),
  pickWindow: stub('pickWindow'),
  copyConfigPath: stub('copyConfigPath'),
  cancel: stub('cancel'),
  apply: stub('apply'),
  ok: stub('ok'),
}
