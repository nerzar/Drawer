#Requires AutoHotkey v2.0

; Перевод пользовательских строк — тостов, трея, стартовых MsgBox и
; сообщений Slots.ahk. Не трогает: DebugLog (в файл, не для пользователя),
; нативное окно Settings (SettingsShow — редкий fallback, каждая надпись
; там переводится отдельной задачей) и диагностику config.ini (тоже
; редкий путь, для тех, кто правит файл руками).
;
; T(key, args*) возвращает строку текущей locale; {1}, {2}… — позиционные
; подстановки. Ключ без перевода возвращает сам себя — заметно и легко
; найти, а не падает.
I18nStrings := Map(
    "app.title", Map("ru", "Ящик", "en", "Drawer"),

    "tray.bug", Map("ru", "Нашёл баг…", "en", "Report a bug…"),

    "notify.activation.unavailable",
        Map("ru", "Активация припаркованных окон работать не будет",
            "en", "Activating parked windows won't work"),
    "notify.startup",
        Map("ru", "Запущен. Хоткеев: {1}", "en", "Started. Hotkeys: {1}"),
    "notify.failure", Map("ru", "Сбой: {1}", "en", "Failure: {1}"),
    "notify.reset.done",
        Map("ru", "Привязки и настройки сброшены", "en", "Bindings and settings reset"),
    "notify.reset.failed",
        Map("ru", "Полный сброс не выполнен: {1}", "en", "Full reset failed: {1}"),
    "notify.bugreport.added",
        Map("ru", "Запись о баге добавлена в лог", "en", "Bug report added to the log"),
    "notify.settings.failed",
        Map("ru", "Настройки не открылись: {1}", "en", "Settings didn't open: {1}"),

    "msgbox.config.missing",
        Map("ru", "Не найден config.ini рядом с программой:`n{1}"
                  "`n`nВерните config.ini из архива программы или создайте его заново.",
            "en", "config.ini not found next to the program:`n{1}"
                  "`n`nRestore config.ini from the program archive or create it again."),
    "msgbox.hotkey.slot.failed",
        Map("ru", "Хоткей слота {1} не назначен:`n{2}",
            "en", "Slot {1} hotkey wasn't registered:`n{2}"),
    "msgbox.hotkey.bind.failed",
        Map("ru", "Хоткей назначения слота {1} не назначен:`n{2}",
            "en", "Slot {1} bind hotkey wasn't registered:`n{2}"),
    "msgbox.hotkey.clear.failed",
        Map("ru", "Хоткей очистки слотов не назначен:`n{1}",
            "en", "Clear-slots hotkey wasn't registered:`n{1}"),
    "msgbox.hotkey.fullreset.failed",
        Map("ru", "Хоткей полного сброса не назначен:`n{1}",
            "en", "Full-reset hotkey wasn't registered:`n{1}"),

    "slot.bind.number_range",
        Map("ru", "Номер слота должен быть 1…9", "en", "Slot number must be 1…9"),
    "slot.bind.busy",
        Map("ru", "Открыт picker", "en", "Picker is open"),
    "slot.bind.owned_by_permanent",
        Map("ru", "Слот {1} занят постоянной привязкой: {2}",
            "en", "Slot {1} is taken by a permanent binding: {2}"),
    "slot.bind.no_eligible_window",
        Map("ru", "Активное окно не годится для ящика", "en", "The active window isn't eligible for Drawer"),
    "slot.bind.window_bound_to_permanent",
        Map("ru", "Окно уже закреплено за постоянным слотом {1} ({2})",
            "en", "The window is already bound to permanent slot {1} ({2})"),
    "slot.bind.done",
        Map("ru", "Слот {1} → {2}", "en", "Slot {1} → {2}"),
    "slot.release.is_permanent",
        Map("ru", "Слот {1} — постоянный, его нельзя освободить",
            "en", "Slot {1} is permanent and can't be released"),
    "slot.release.not_bound",
        Map("ru", "Слот {1} не привязан к окну", "en", "Slot {1} isn't bound to a window"),
    "slot.release.done",
        Map("ru", "Слот {1} освобождён", "en", "Slot {1} released"),
)

T(key, args*) {
    global I18nStrings, locale
    if !I18nStrings.Has(key)
        return key
    entry := I18nStrings[key]
    s := entry.Has(locale) ? entry[locale] : entry["ru"]
    for i, a in args
        s := StrReplace(s, "{" i "}", String(a))
    return s
}
