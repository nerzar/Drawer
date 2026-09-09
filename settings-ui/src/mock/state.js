import { reactive } from 'vue'

// Mock config.ini-shaped state. Осталось только под вкладку Slots: она
// пока не подключена к мосту. General живёт на canonical state AHK и
// сюда не заглядывает — см. src/bridge/general.ts.
//
// Блок general здесь всё ещё нужен: панель динамического слота
// показывает им «унаследовано от [dynamic]». Уедет вместе со Slots.
export const state = reactive({
  accent: '#2A2E35',
  accentPalette: ['#2A2E35', '#332A35', '#2A352E', '#2A3335', '#332F2A'],

  general: {
    sizePercent: 70,
    edge: 'right',
    monitor: 'cursor',
    activateOnShow: true,
    hideOnBlur: true,
    handles: true,
    handleWidth: 22,
    handleHeight: 34,
    handleGap: 8,
    animEasing: 'normal',
    blurMs: 250,
  },

  selectedSlot: 2,

  slots: [
    {
      n: 1,
      kind: 'perm',
      name: 'Steam',
      exe: 'steam.exe',
      cls: '',
      icon: 'steam',
      running: false,
      monitor: 'cursor',
      edge: 'right',
      width: 70,
      activateOnShow: true,
      hideOnBlur: true,
      hotkey: 'Ctrl + Alt + 1',
    },
    {
      n: 2,
      kind: 'perm',
      name: 'OneDrive - Files',
      exe: 'Files.exe',
      cls: 'WinUIDesktopWin32WindowClass',
      icon: 'cloud',
      running: false,
      monitor: 'cursor',
      edge: 'right',
      width: 70,
      activateOnShow: true,
      hideOnBlur: true,
      hotkey: 'Ctrl + Alt + 2',
    },
    {
      n: 3,
      kind: 'perm',
      name: 'Исследователь задач',
      exe: 'Taskmgr.exe',
      cls: '',
      icon: 'assistant',
      running: true,
      monitor: 'cursor',
      edge: 'right',
      width: 70,
      activateOnShow: true,
      hideOnBlur: true,
      hotkey: 'Ctrl + Alt + 3',
    },
    ...Array.from({ length: 6 }, (_, i) => ({
      n: i + 4,
      kind: 'dyn',
      name: '',
      exe: '',
      cls: '',
      icon: '',
      running: false,
      monitor: 'cursor',
      edge: 'right',
      width: 70,
      activateOnShow: true,
      hideOnBlur: false,
    })),
  ],
})

export const EDGE_OPTIONS = [
  { value: 'left', label: 'Слева' },
  { value: 'right', label: 'Справа' },
  { value: 'top', label: 'Сверху' },
  { value: 'bottom', label: 'Снизу' },
]

export const MONITOR_OPTIONS = [
  { value: 'cursor', label: 'Следовать за курсором' },
  { value: '1', label: 'Монитор 1' },
  { value: '2', label: 'Монитор 2' },
]

export const ANIM_OPTIONS = [
  { value: 'fast', label: 'Быстрая', ms: 90, steps: 8 },
  { value: 'normal', label: 'Обычная', ms: 160, steps: 14 },
  { value: 'smooth', label: 'Плавная', ms: 260, steps: 22 },
]
