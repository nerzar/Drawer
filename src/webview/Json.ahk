; ============================ JSON ============================
; AHK v2 своего JSON не имеет, а тащить RPC-фреймворк ради одного канала
; незачем (см. docs/settings-integration-layer.md: codec — внутренняя
; деталь моста). Здесь ровно то, что нужно wire-контракту: объекты,
; массивы, строки, числа, true/false/null.
;
; Объект разбирается в Map, а не в объект AHK: ключ приходит снаружи, и
; запись вида obj.%key% на "__Init" или "base" вела бы себя не как
; данные. Читать разобранное поле следует через JsonGet(): отсутствие
; ключа — обычный случай неполного draft, а не сбой.
;
; null становится пустой строкой. Отличать null от "" контракту негде:
; на wire нет ни одного поля, где оба значения допустимы.

JsonParse(text) {
    pos := 1
    v := JsonValue(text, &pos)
    JsonSkipWs(text, &pos)
    if (pos <= StrLen(text))
        throw Error("JSON: лишние данные с позиции " pos)
    return v
}

JsonSkipWs(t, &p) {
    while (p <= StrLen(t) && InStr(" `t`r`n", SubStr(t, p, 1)))
        p++
}

JsonValue(t, &p) {
    JsonSkipWs(t, &p)
    if (p > StrLen(t))
        throw Error("JSON: значение не найдено")
    c := SubStr(t, p, 1)
    if (c = "{")
        return JsonObject(t, &p)
    if (c = "[")
        return JsonArray(t, &p)
    if (c = '"')
        return JsonString(t, &p)
    if (SubStr(t, p, 4) == "true") {
        p += 4
        return true
    }
    if (SubStr(t, p, 5) == "false") {
        p += 5
        return false
    }
    if (SubStr(t, p, 4) == "null") {
        p += 4
        return ""
    }
    return JsonNumber(t, &p)
}

JsonObject(t, &p) {
    m := Map()
    p++
    JsonSkipWs(t, &p)
    if (SubStr(t, p, 1) = "}") {
        p++
        return m
    }
    loop {
        JsonSkipWs(t, &p)
        if (SubStr(t, p, 1) != '"')
            throw Error("JSON: ожидался ключ на позиции " p)
        k := JsonString(t, &p)
        JsonSkipWs(t, &p)
        if (SubStr(t, p, 1) != ":")
            throw Error("JSON: ожидалось «:» на позиции " p)
        p++
        m[k] := JsonValue(t, &p)
        JsonSkipWs(t, &p)
        c := SubStr(t, p, 1)
        p++
        if (c = "}")
            return m
        if (c != ",")
            throw Error("JSON: ожидалось «,» или «}» на позиции " (p - 1))
    }
}

JsonArray(t, &p) {
    a := []
    p++
    JsonSkipWs(t, &p)
    if (SubStr(t, p, 1) = "]") {
        p++
        return a
    }
    loop {
        a.Push(JsonValue(t, &p))
        JsonSkipWs(t, &p)
        c := SubStr(t, p, 1)
        p++
        if (c = "]")
            return a
        if (c != ",")
            throw Error("JSON: ожидалось «,» или «]» на позиции " (p - 1))
    }
}

JsonString(t, &p) {
    p++                                  ; открывающая кавычка
    out := ""
    loop {
        if (p > StrLen(t))
            throw Error("JSON: строка не закрыта")
        c := SubStr(t, p, 1)
        p++
        if (c = '"')
            return out
        if (c != "\") {
            out .= c
            continue
        }
        e := SubStr(t, p, 1)
        p++
        switch e, true {                 ; регистр escape-буквы значим
        case '"': out .= '"'
        case "\": out .= "\"
        case "/": out .= "/"
        case "b": out .= Chr(8)
        case "f": out .= Chr(12)
        case "n": out .= "`n"
        case "r": out .= "`r"
        case "t": out .= "`t"
        case "u":
            out .= Chr(Integer("0x" SubStr(t, p, 4)))
            p += 4
        default:
            throw Error("JSON: неизвестный escape «\" e "»")
        }
    }
}

JsonNumber(t, &p) {
    start := p
    while (p <= StrLen(t) && InStr("+-0123456789.eE", SubStr(t, p, 1)))
        p++
    s := SubStr(t, start, p - start)
    if (s = "" || !IsNumber(s))
        throw Error("JSON: не число на позиции " start)
    return IsInteger(s) ? Integer(s) : Float(s)
}

; Вложенное поле по пути "draft.general.blurCheckMs". Пропуск возвращает
; def: что делать с неполным draft, решает порт, а не codec.
JsonGet(root, path, def := "") {
    cur := root
    for key in StrSplit(path, ".") {
        if !(cur is Map) || !cur.Has(key)
            return def
        cur := cur[key]
    }
    return cur
}

; --------------------------- сериализация ---------------------------
; В AHK true — это целое 1, поэтому тип значения сам по себе не говорит,
; булево оно или число: без обёртки каждый 1 уезжал бы как true. JsonB()
; помечает те и только те значения, которые на wire булевы.
class JsonBool {
    __New(value) {
        this.value := value ? true : false
    }
}

JsonB(value) {
    return JsonBool(value)
}

JsonDump(v) {
    if (v is JsonBool)
        return v.value ? "true" : "false"
    if (v is Map) {
        out := "", sep := ""
        for k, val in v {
            out .= sep JsonQuote(String(k)) ":" JsonDump(val)
            sep := ","
        }
        return "{" out "}"
    }
    if (v is Array) {
        out := "", sep := ""
        for val in v {
            out .= sep JsonDump(val)
            sep := ","
        }
        return "[" out "]"
    }
    if (v is Integer || v is Float)
        return String(v)
    return JsonQuote(String(v))
}

JsonQuote(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    ; Управляющие символы ниже 0x20 в JSON сырыми запрещены; \r \n \t уже
    ; заменены выше, поэтому цикл цепляет только остальные.
    loop 31 {
        code := A_Index
        c := Chr(code)
        if InStr(s, c, true)
            s := StrReplace(s, c, Format("\u{:04x}", code))
    }
    return '"' s '"'
}
