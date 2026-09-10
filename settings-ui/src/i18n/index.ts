// Перевод пользовательских строк Settings UI. Единственное описание
// всех отображаемых фраз на этой стороне; тот же приём — на стороне AHK
// (см. src/I18n.ahk). Модуль не читает settings сам — это бы завело
// цикл импортов (settings.ts тянет general.ts, тот тянет i18n): вместо
// этого locale — собственный reactive-ref, и App.vue синхронизирует
// его с settings.draft/canonical через setLocale().
//
// t(key, params?) возвращает строку текущей locale; {name} в строке —
// именованные подстановки. Ключ без перевода возвращает сам себя —
// заметно и легко найти, а не падает.

import { ref } from 'vue'
import type { Locale } from '../bridge/protocol'

type Entry = { ru: string; en: string }

const STRINGS: Record<string, Entry> = {
  'sidebar.aria': { ru: 'Разделы настроек', en: 'Settings sections' },
  'sidebar.tab.general': { ru: 'Общие', en: 'General' },
  'sidebar.tab.slots': { ru: 'Слоты', en: 'Slots' },
  'sidebar.tab.about': { ru: 'О программе', en: 'About' },

  'footer.confirmMessage': { ru: 'Изменения не сохранены. Закрыть и отменить их?', en: "Changes aren't saved. Close and discard them?" },
  'footer.keepEditing': { ru: 'Продолжить правку', en: 'Keep editing' },
  'footer.discard': { ru: 'Отменить изменения', en: 'Discard changes' },
  'footer.cancel': { ru: 'Отмена', en: 'Cancel' },
  'footer.apply': { ru: 'Применить', en: 'Apply' },
  'footer.ok': { ru: 'ОК', en: 'OK' },

  'status.noBridge': { ru: 'Страница открыта не из Ящика: WebView2-мост недоступен', en: "This page wasn't opened from Drawer: the WebView2 bridge is unavailable" },
  'status.loading': { ru: 'Читаем настройки…', en: 'Reading settings…' },
  'status.saving': { ru: 'Сохраняем…', en: 'Saving…' },
  'status.saved': { ru: 'Сохранено. Изменённых строк: {n}', en: 'Saved. Changed lines: {n}' },
  'status.noop': { ru: 'Менять нечего: всё уже так', en: 'Nothing to change: already like this' },

  'hint.restart.slot_one': { ru: 'Хоткей фокуса (слот {list}) заработает после перезапуска Ящика.', en: 'Focus hotkey (slot {list}) will take effect after restarting Drawer.' },
  'hint.restart.slot_many': { ru: 'Хоткей фокуса (слоты {list}) заработает после перезапуска Ящика.', en: 'Focus hotkeys (slots {list}) will take effect after restarting Drawer.' },
  'hint.restart.generic': { ru: 'Часть изменений заработает после перезапуска Ящика.', en: 'Some changes will take effect after restarting Drawer.' },

  'slot.bind.done': { ru: 'Слот {n} привязан к активному окну', en: 'Slot {n} bound to the active window' },
  'slot.release.done': { ru: 'Слот {n} освобождён', en: 'Slot {n} released' },

  'general.title': { ru: 'Общие настройки', en: 'General settings' },
  'general.subtitle': { ru: 'Поведение, внешний вид и умолчания для динамических слотов.', en: 'Behavior, appearance, and defaults for dynamic slots.' },
  'general.notLoaded': { ru: 'Настройки ещё не прочитаны.', en: "Settings haven't been read yet." },
  'general.card.behavior.title': { ru: 'Поведение по умолчанию', en: 'Default behavior' },
  'general.card.behavior.hint': { ru: 'Действует на динамические слоты — у постоянных свои значения в config.ini, отсюда их не поменять.', en: "Applies to dynamic slots — permanent ones keep their own values in config.ini and aren't changed from here." },
  'general.field.width': { ru: 'Размер окна', en: 'Window size' },
  'general.unit.percentScreen': { ru: '% экрана', en: '% of screen' },
  'general.field.edge': { ru: 'Сторона выезда', en: 'Slide-out edge' },
  'general.field.monitor': { ru: 'Монитор', en: 'Monitor' },
  'general.check.handles': { ru: 'Кромки у края экрана', en: 'Screen-edge handles' },
  'general.check.hideOnBlur': { ru: 'Убирать окно, когда фокус ушёл в другое', en: 'Hide the window when focus moves elsewhere' },
  'general.card.appearance.title': { ru: 'Внешний вид', en: 'Appearance' },
  'general.field.handleSize': { ru: 'Размер кромки (px)', en: 'Handle size (px)' },
  'general.field.handleGap': { ru: 'Отступ между кромками (px)', en: 'Gap between handles (px)' },
  'general.field.accent': { ru: 'Цвет акцента', en: 'Accent color' },
  'general.customColor.title': { ru: 'Свой цвет', en: 'Custom color' },
  'general.customColor.pick': { ru: 'Выбрать свой цвет', en: 'Pick a custom color' },
  'general.swatch.aria': { ru: 'Цвет #{hex}', en: 'Color #{hex}' },
  'general.card.animation.title': { ru: 'Анимация', en: 'Animation' },
  'general.card.animation.hint': { ru: 'Вид задаёт эффект, плавность — его существующий темп.', en: 'Style sets the effect, smoothness sets its pace.' },
  'general.field.animationStyle': { ru: 'Вид', en: 'Style' },
  'general.field.animPreset': { ru: 'Плавность', en: 'Smoothness' },
  'general.animPreset.none': { ru: 'Без анимации', en: 'No animation' },
  'general.animPreset.custom': { ru: 'Текущая нестандартная', en: 'Current custom' },
  'general.card.locale.title': { ru: 'Локализация', en: 'Localization' },
  'general.field.locale': { ru: 'Язык', en: 'Language' },
  'general.monitorRaw': { ru: 'в файле: {raw}', en: 'in file: {raw}' },

  'locale.ru': { ru: 'Русский', en: 'Russian' },
  'locale.en': { ru: 'English', en: 'English' },

  'edge.left': { ru: 'Слева', en: 'Left' },
  'edge.right': { ru: 'Справа', en: 'Right' },
  'edge.top': { ru: 'Сверху', en: 'Top' },
  'edge.bottom': { ru: 'Снизу', en: 'Bottom' },

  'anim.fast': { ru: 'Быстрая', en: 'Fast' },
  'anim.normal': { ru: 'Обычная', en: 'Normal' },
  'anim.smooth': { ru: 'Плавная', en: 'Smooth' },

  'animStyle.reveal': { ru: 'Раскрытие', en: 'Reveal' },
  'animStyle.fade': { ru: 'Растворение', en: 'Fade' },
  'animStyle.dwmSlideFade': { ru: 'Плавное появление', en: 'Smooth appearance' },
  'animStyle.dwmShrink': { ru: 'Всплытие', en: 'Pop up' },

  'slots.title': { ru: 'Слоты Drawer', en: 'Drawer slots' },
  'slots.subtitle': { ru: 'Настройте слоты для приложений и горячие клавиши.', en: 'Configure slots for applications and hotkeys.' },
  'slots.watchError': { ru: 'Обновление состояний недоступно: {err}', en: 'Status updates unavailable: {err}' },
  'slots.list.aria': { ru: 'Слоты', en: 'Slots' },
  'slots.pill.permanent': { ru: 'Постоянный', en: 'Permanent' },
  'slots.pill.dynamic': { ru: 'Временный', en: 'Temporary' },
  'slots.action.reset.title': { ru: 'Отвязать окно и вернуть слот к настройкам по умолчанию', en: 'Unbind the window and reset the slot to its defaults' },
  'slots.action.reset': { ru: 'Сбросить слот', en: 'Reset slot' },
  'slots.action.makeDynamic.title': { ru: 'После «Применить» Drawer перестанет автоматически искать это приложение', en: 'After Apply, Drawer will stop automatically looking for this application' },
  'slots.action.makeDynamic': { ru: 'Сделать временным', en: 'Make temporary' },
  'slots.action.makePermanent.title': { ru: 'После привязки слот сохраняется за приложением навсегда', en: 'Once bound, the slot stays with this application permanently' },
  'slots.action.makePermanent': { ru: 'Сделать постоянным', en: 'Make permanent' },
  'slots.detail.title': { ru: 'Слот {n}', en: 'Slot {n}' },
  'slots.detail.state': { ru: 'Состояние', en: 'State' },
  'slots.detail.window': { ru: 'Окно', en: 'Window' },
  'slots.field.name': { ru: 'Имя', en: 'Name' },
  'slots.field.executable': { ru: 'Приложение (.exe)', en: 'Application (.exe)' },
  'slots.pickExe.title': { ru: 'Выбрать приложение…', en: 'Choose an application…' },
  'slots.pickExe.aria': { ru: 'Выбрать приложение для слота', en: 'Choose an application for the slot' },
  'slots.pickWindow.title': { ru: 'Взять данные из открытого окна…', en: 'Take data from an open window…' },
  'slots.pickWindow.aria': { ru: 'Взять данные из открытого окна для слота', en: 'Take data from an open window for the slot' },
  'slots.classTip.aria': { ru: 'Справка о признаке окна', en: 'Help about the window identifier' },
  'slots.classTip.text1': { ru: 'Дополнительный признак окна:', en: 'Additional window identifier:' },
  'slots.classTip.text2': { ru: 'Помогает выбрать нужный тип окна, если у приложения их несколько.', en: 'Helps pick the right window type when an application has more than one.' },
  'slots.classTip.text3': { ru: 'Заполняется кнопкой «Взять данные из открытого окна…».', en: 'Filled in by the “Take data from an open window…” button.' },
  'slots.field.edge': { ru: 'Край', en: 'Edge' },
  'slots.field.width': { ru: 'Ширина (%)', en: 'Width (%)' },
  'slots.check.hideOnBlur': { ru: 'Убирать окно, когда фокус ушёл', en: 'Hide the window when focus is lost' },
  'slots.field.hotkey': { ru: 'Горячая клавиша', en: 'Hotkey' },
  'slots.freeNote': { ru: 'Чтобы Drawer снова находил приложение после перезапуска, закрепите слот за приложением.', en: 'For Drawer to find the application again after a restart, pin the slot to it.' },

  'monitor.cursor': { ru: 'Под курсором', en: 'Under the cursor' },
  'monitor.number': { ru: 'Монитор {n}', en: 'Monitor {n}' },
  'monitor.invalid': { ru: 'Некорректное значение: {raw}', en: 'Invalid value: {raw}' },
  'monitor.label': { ru: 'Монитор {n} — {w}×{h}', en: 'Monitor {n} — {w}×{h}' },
  'monitor.cursorDefault': { ru: 'Следовать за курсором', en: 'Follow the cursor' },
  'monitor.unavailable': { ru: 'Монитор {n} (недоступен)', en: 'Monitor {n} (unavailable)' },
  'monitor.invalidChoose': { ru: 'Некорректное значение: {raw} — выберите монитор', en: 'Invalid value: {raw} — choose a monitor' },
  'monitor.invalidChooseGeneric': { ru: 'Некорректное значение — выберите монитор', en: 'Invalid value — choose a monitor' },

  'status.slot.empty': { ru: 'пусто', en: 'empty' },
  'status.slot.notRunning': { ru: 'не запущено', en: 'not running' },
  'status.slot.available': { ru: 'запущено', en: 'running' },
  'status.slot.parked': { ru: 'убрано', en: 'parked' },
  'status.slot.shown': { ru: 'на экране', en: 'shown' },

  'about.section.config': { ru: 'Файл конфигурации', en: 'Configuration file' },
  'about.p.config1': { ru: 'Настройки сохраняются в файле', en: 'Settings are saved to the file' },
  'about.p.config2': {
    ru: 'в папке с программой. Программа меняет этот файл по «Применить» или «ОК». Полный сброс Ctrl + Alt + Shift + 0 возвращает настройки к значениям по умолчанию. Ни закрытие окна, ни выход из программы ничего не сохраняют.',
    en: "in the program's folder. The program changes this file on Apply or OK. A full reset (Ctrl + Alt + Shift + 0) restores settings to their defaults. Neither closing the window nor exiting the program saves anything.",
  },
  'about.copyPath': { ru: 'Копировать путь', en: 'Copy path' },
  'about.copied': { ru: 'Скопировано', en: 'Copied' },
  'about.copyError': { ru: 'Не удалось скопировать', en: "Couldn't copy" },
  'about.pathUnavailable': { ru: 'Путь к config.ini недоступен: откройте настройки из Ящика.', en: 'The config.ini path is unavailable: open Settings from Drawer.' },
  'about.license': { ru: '· лицензия MIT', en: '· MIT license' },
  'about.section.hotkeys': { ru: 'Горячие клавиши', en: 'Hotkeys' },
  'about.hotkey.toggle': { ru: 'Показать / убрать окно — клавиша настраивается для каждого слота; по умолчанию Ctrl + Alt + N', en: 'Show / hide window — the key is configurable per slot; default is Ctrl + Alt + N' },
  'about.hotkey.bind': { ru: 'Назначить активное окно слоту', en: 'Assign the active window to a slot' },
  'about.hotkey.clear': { ru: 'Очистить динамические слоты', en: 'Clear dynamic slots' },
  'about.hotkey.fullReset': { ru: 'Полный сброс настроек и привязок', en: 'Full reset of settings and bindings' },
}

export const locale = ref<Locale>('ru')

export function setLocale(next: Locale): void {
  locale.value = next
}

export function t(key: string, params?: Record<string, string | number>): string {
  const entry = STRINGS[key]
  let s = entry ? entry[locale.value] ?? entry.ru : key
  if (params) {
    for (const [k, v] of Object.entries(params)) s = s.split(`{${k}}`).join(String(v))
  }
  return s
}

export const LOCALE_OPTIONS: { value: Locale; label: string }[] = [
  { value: 'ru', label: 'Русский' },
  { value: 'en', label: 'English' },
]
