// Черновик вкладки General и его перевод в wire DTO.
//
// Числовые поля живут в черновике строками, а не числами: input отдаёт
// строку, и приведение к числу до отправки чинило бы ввод за
// пользователя («300abc» стало бы 300, пустое поле — нулём). Проверяет
// значения backend, его сообщение и должно доехать до формы.
//
// Никаких умолчаний Ящика здесь нет по построению: черновик заводится
// только из canonical state, пришедшего от AHK.

import { t } from '../i18n'
import type { AnimationStyle, Edge, GeneralSettings, Locale, MonitorRef } from './protocol'

export type MonitorKind = 'cursor' | 'number' | 'invalid'

export type GeneralDraft = {
  widthPercent: string
  edge: Edge
  monitorKind: MonitorKind
  monitorNumber: string
  // Значение из config.ini, которого не бывает у контролов. Живёт в
  // черновике, пока его не заменили: молча подставить cursor нельзя —
  // это меняло бы настройку, которую человек не трогал.
  monitorRaw: string
  activateOnShow: boolean
  hideOnBlur: boolean
  handlesEnabled: boolean
  animationStyle: AnimationStyle
  animMs: string
  animSteps: string
  animCustom?: boolean
  blurCheckMs: string
  accent: string
  handleWidth: string
  handleHeight: string
  handleGap: string
  locale: Locale
}

// Функции, а не константы: подписи читают текущую locale через t() при
// каждом вызове, а Vue следит за реактивной зависимостью внутри —
// вызывать их нужно прямо в шаблоне (edgeOptions()), не один раз в module scope.
export function edgeOptions(): { value: Edge; label: string }[] {
  return [
    { value: 'left', label: t('edge.left') },
    { value: 'right', label: t('edge.right') },
    { value: 'top', label: t('edge.top') },
    { value: 'bottom', label: t('edge.bottom') },
  ]
}

// Те же три пары, что у native (SettingsAnimPresets). Пресет — способ
// показа двух ключей, а не новая настройка: на wire уезжают ровно
// durationMs и steps. Значения — Windows/Fluent baseline: faster ≈ 83 мс,
// fast ≈ 167 мс, normal ≈ 250 мс. Числа не зависят от locale, поэтому
// живут отдельно от подписей — их читают isCustomAnim/animPreset и
// применяют без t().
const PRESET_VALUES: { id: 'fast' | 'normal' | 'smooth'; ms: number; steps: number }[] = [
  { id: 'fast', ms: 83, steps: 8 },
  { id: 'normal', ms: 167, steps: 14 },
  { id: 'smooth', ms: 250, steps: 20 },
]

export function animPresets(): { id: 'fast' | 'normal' | 'smooth'; label: string; ms: number; steps: number }[] {
  const labels: Record<'fast' | 'normal' | 'smooth', string> = {
    fast: t('anim.fast'),
    normal: t('anim.normal'),
    smooth: t('anim.smooth'),
  }
  return PRESET_VALUES.map((p) => ({ ...p, label: labels[p.id] }))
}

// Те же четыре пункта, что у native (AnimationStyleMenu). classic снят
// целиком (владелец решил не оставлять чистый slide реального окна),
// dwmSlide не показываем отдельно — он не отличим от снятого classic
// вне заблокированного соседним монитором края. Названия описывают
// эффект, не технологию — без слова "DWM".
export function animationStyleOptions(): { value: AnimationStyle; label: string }[] {
  return [
    { value: 'reveal', label: t('animStyle.reveal') },
    { value: 'fade', label: t('animStyle.fade') },
    { value: 'dwmSlideFade', label: t('animStyle.dwmSlideFade') },
    { value: 'dwmShrink', label: t('animStyle.dwmShrink') },
  ]
}

const ANIMATION_STYLE_VALUES: AnimationStyle[] = ['reveal', 'fade', 'dwmSlideFade', 'dwmShrink']

// Принятый владельцем default. Используется и как начальное состояние
// черновика, и как откат для легаси/неизвестного значения (снятый
// classic из старого config.ini, будущий незнакомый ключ) — молчаливый
// пустой <select> хуже явного отката на то, что реально сейчас работает.
export const DEFAULT_ANIMATION_STYLE: AnimationStyle = 'dwmSlideFade'

export function normalizeAnimationStyle(style: unknown): AnimationStyle {
  return ANIMATION_STYLE_VALUES.includes(style as AnimationStyle)
    ? (style as AnimationStyle)
    : DEFAULT_ANIMATION_STYLE
}

export const ACCENT_PALETTE = [
  '2A2E35',
  '332A35',
  '2A352E',
  '2A3335',
  '332F2A',
]

export function isCustomAnim(animMs: string, animSteps: string): boolean {
  if (animSteps.trim() === '0') return false
  for (const p of PRESET_VALUES)
    if (num(animMs) === p.ms && num(animSteps) === p.steps) return false
  return true
}

export function draftFromState(g: GeneralSettings): GeneralDraft {
  const m = g.dynamicDefaults.monitor
  const handle = g.handle ?? { width: 26, height: 34, gap: 8 }
  const animMs = String(g.animation.durationMs)
  const animSteps = String(g.animation.steps)
  return {
    widthPercent: String(g.dynamicDefaults.widthPercent),
    edge: g.dynamicDefaults.edge,
    monitorKind: m.kind,
    monitorNumber: m.kind === 'number' ? String(m.number) : '1',
    monitorRaw: m.kind === 'invalid' ? m.raw : '',
    activateOnShow: g.dynamicDefaults.activateOnShow,
    hideOnBlur: g.dynamicDefaults.hideOnBlur,
    handlesEnabled: g.handlesEnabled,
    animationStyle: normalizeAnimationStyle(g.animation.style),
    animMs,
    animSteps,
    animCustom: isCustomAnim(animMs, animSteps),
    blurCheckMs: String(g.blurCheckMs),
    accent: g.accent,
    handleWidth: String(handle.width),
    handleHeight: String(handle.height),
    handleGap: String(handle.gap),
    locale: g.locale,
  }
}

export function draftToWire(d: GeneralDraft): GeneralSettings {
  return {
    dynamicDefaults: {
      monitor: monitorToWire(d),
      edge: d.edge,
      widthPercent: num(d.widthPercent),
      activateOnShow: d.activateOnShow,
      hideOnBlur: d.hideOnBlur,
    },
    handlesEnabled: d.handlesEnabled,
    animation: { style: d.animationStyle, durationMs: num(d.animMs), steps: num(d.animSteps) },
    blurCheckMs: num(d.blurCheckMs),
    accent: d.accent,
    handle: { width: num(d.handleWidth), height: num(d.handleHeight), gap: num(d.handleGap) },
    locale: d.locale,
  }
}

export function monitorToWire(d: Pick<GeneralDraft, 'monitorKind' | 'monitorRaw' | 'monitorNumber'>): MonitorRef {
  if (d.monitorKind === 'cursor') return { kind: 'cursor' }
  if (d.monitorKind === 'invalid') return { kind: 'invalid', raw: d.monitorRaw }
  return { kind: 'number', number: num(d.monitorNumber) }
}

// Пустая строка — не ноль. Number('') даёт 0, и без этой проверки
// очищенное поле уехало бы валидным нулём вместо «поле не заполнено».
// NaN сериализуется в null, и порт отвечает ошибкой с именем поля.
export function num(s: string): number {
  const trimmed = s.trim()
  return trimmed === '' ? Number.NaN : Number(trimmed)
}

// Какой пункт списка «Плавность» соответствует паре чисел. Пара, не
// совпавшая ни с одним пресетом, показывается как «Своя» вместе с
// настоящими числами: молча округлять чужие значения нельзя.
// Во время сеанса редактирования явный выбор «Своя» фиксируется в черновике,
// чтобы поля открывались для ввода даже при исходно совпадающей паре чисел.
export function animPreset(d: GeneralDraft): string {
  if (d.animCustom) return 'custom'
  if (d.animSteps.trim() === '0') return 'none'
  for (const p of PRESET_VALUES)
    if (num(d.animMs) === p.ms && num(d.animSteps) === p.steps) return p.id
  return 'custom'
}

export function applyAnimPreset(d: GeneralDraft, id: string): void {
  if (id === 'custom') {
    d.animCustom = true
    return
  }
  d.animCustom = false
  if (id === 'none') {
    d.animSteps = '0'
    return
  }
  const p = PRESET_VALUES.find((o) => o.id === id)
  if (!p) return
  d.animMs = String(p.ms)
  d.animSteps = String(p.steps)
}
