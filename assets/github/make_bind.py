# -*- coding: utf-8 -*-
"""
how-it-works.gif — как работают динамические слоты.

Порядок как в жизни: сначала обычное окно на экране, потом привязка
Ctrl+Alt+Shift+3, и только после этого вызов Ctrl+Alt+3. Первый вызов
после привязки действительно переносит окно к краю: Show() ставит его на
hx (за границей монитора) и оттуда выдвигает — поэтому окно и «уходит»
из середины экрана, а не морфится на месте.
"""
import os
from PIL import Image, ImageDraw, ImageFont

W, H = 900, 520
FPS = 20
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bind")
os.makedirs(OUT, exist_ok=True)

BG        = (13, 17, 23)
SCR_BG    = (22, 27, 34)
OFF_BG    = (9, 12, 17)
BORDER    = (48, 54, 61)
BORDER_HI = (68, 76, 86)
TEXT      = (201, 209, 217)
MUTED     = (125, 133, 144)
DIM       = (88, 96, 105)
ACCENT    = (88, 166, 255)
ACCENT_D  = (31, 61, 99)
GREEN     = (63, 185, 80)
ORANGE    = (219, 109, 40)
PURPLE    = (188, 140, 255)

F = "C:/Windows/Fonts/"
title_f = ImageFont.truetype(F + "segoeuib.ttf", 27)
sub_f   = ImageFont.truetype(F + "segoeui.ttf", 15)
cap_f   = ImageFont.truetype(F + "seguisb.ttf", 18)
lab_f   = ImageFont.truetype(F + "segoeui.ttf", 13)
labb_f  = ImageFont.truetype(F + "seguisb.ttf", 13)
key_f   = ImageFont.truetype(F + "seguisb.ttf", 15)
badge_f = ImageFont.truetype(F + "seguisb.ttf", 13)

SCR_L, SCR_T, SCR_R, SCR_B = 28, 92, 566, 396
OFF_L, OFF_R = 574, 872
PANEL_W = 196
PANEL_PARKED   = 620
PANEL_DEPLOYED = SCR_R - PANEL_W

FLOAT_BOX = (96, 148, 396, 352)          # окно, пока оно обычное


def ease(t):
    return 1 - (1 - t) ** 3


def lerp_box(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(4))


def rr(d, box, r, fill=None, outline=None, width=1):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def draw_editor(d):
    x0, y0, x1, y1 = SCR_L + 10, SCR_T + 10, SCR_R - 10, SCR_B - 10
    rr(d, (x0, y0, x1, y1), 6, fill=(15, 19, 26))
    d.rectangle((x0, y0, x1, y0 + 22), fill=(20, 25, 32))
    rr(d, (x0 + 6, y0 + 4, x0 + 92, y0 + 21), 3, fill=(15, 19, 26))
    d.text((x0 + 14, y0 + 6), "main.py", font=lab_f, fill=MUTED)
    d.text((x0 + 104, y0 + 6), "utils.py", font=lab_f, fill=DIM)
    rows = [(26, ORANGE, 34), (26, ACCENT, 70), (0, None, 0),
            (26, PURPLE, 52), (44, MUTED, 96), (44, GREEN, 74),
            (44, MUTED, 120), (26, PURPLE, 60), (44, MUTED, 88),
            (44, ACCENT, 110), (0, None, 0), (26, ORANGE, 46),
            (44, MUTED, 132), (44, GREEN, 68)]
    y = y0 + 40
    for indent, col, w in rows:
        if col:
            d.rectangle((x0 + 14 + indent, y, x0 + 14 + indent + w, y + 6), fill=col)
            d.rectangle((x0 + 24 + indent + w, y, x0 + 24 + indent + w + w // 2, y + 6),
                        fill=(46, 54, 64))
        y += 17


def badge(d, x, y, n):
    rr(d, (x, y, x + 22, y + 22), 11, fill=ACCENT, outline=ACCENT)
    s = str(n)
    bb = d.textbbox((0, 0), s, font=badge_f)
    d.text((x + (22 - bb[2]) // 2, y + 3), s, font=badge_f, fill=(10, 14, 20))


def draw_win(d, box, dimmed, slot=None):
    """Окно-мессенджер произвольного размера."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    body = (17, 21, 27) if dimmed else (22, 27, 34)
    edge = (44, 62, 84) if dimmed else ACCENT
    rr(d, box, 8, fill=body, outline=edge, width=2)
    hh = 30
    d.rectangle((x0 + 2, y0 + 10, x1 - 2, y0 + hh), fill=(28, 34, 43))
    rr(d, (x0 + 2, y0 + 2, x1 - 2, y0 + 18), 8, fill=(28, 34, 43))
    d.ellipse((x0 + 12, y0 + 9, x0 + 26, y0 + 23), fill=edge)
    d.text((x0 + 34, y0 + 8), "Messenger", font=labb_f,
           fill=TEXT if not dimmed else DIM)

    inner = h - hh - 40
    plan = [(0, 0.60, 3), (0, 0.47, 2), (1, 0.53, 2),
            (0, 0.67, 3), (1, 0.40, 2), (0, 0.49, 2)]
    y = y0 + hh + 14
    for side, frac, lines in plan:
        bw = round((w - 28) * frac)
        bh = 10 + lines * 11
        if y + bh > y0 + hh + 14 + inner:
            break
        bx = x0 + 14 if side == 0 else x1 - 14 - bw
        fill = ((36, 43, 53) if not dimmed else (26, 32, 40)) if side == 0 \
               else (ACCENT_D if not dimmed else (24, 38, 54))
        rr(d, (bx, y, bx + bw, y + bh), 7, fill=fill)
        ly = y + 6
        for i in range(lines):
            lw = bw - 16 - (18 if i == lines - 1 else 0)
            if lw > 4:
                d.rectangle((bx + 8, ly, bx + 8 + lw, ly + 5),
                            fill=(96, 106, 118) if not dimmed else (54, 62, 72))
            ly += 11
        y += bh + 9
    rr(d, (x0 + 12, y1 - 34, x1 - 12, y1 - 12), 11,
       fill=(30, 36, 45), outline=(50, 58, 68))
    if slot is not None:
        badge(d, x1 - 34, y0 + 8, slot)


def draw_keys(d, items, lit):
    widths, total = [], 0
    for k in items:
        bb = d.textbbox((0, 0), k, font=key_f)
        wk = max(bb[2] + 22, 36)
        widths.append(wk)
        total += wk
    total += (len(items) - 1) * 26
    x = (W - total) // 2
    y = 424
    for i, (k, wk) in enumerate(zip(items, widths)):
        if lit:
            fill, outline, tc = (30, 58, 95), ACCENT, (198, 224, 255)
        else:
            fill, outline, tc = (26, 31, 39), BORDER, MUTED
        rr(d, (x, y, x + wk, y + 30), 6, fill=fill, outline=outline, width=1)
        if lit:
            rr(d, (x + 1, y + 1, x + wk - 1, y + 8), 4, fill=(38, 70, 110))
        bb = d.textbbox((0, 0), k, font=key_f)
        d.text((x + (wk - bb[2]) // 2, y + 6), k, font=key_f, fill=tc)
        x += wk
        if i < len(items) - 1:
            d.text((x + 8, y + 6), "+", font=key_f, fill=DIM)
        x += 26


def draw_slots(d, active):
    cw, gap = 20, 7
    total = 9 * cw + 8 * gap
    x = OFF_L + (OFF_R - OFF_L - total) // 2
    y = SCR_B + 14
    for i in range(1, 10):
        on = (i == active)
        rr(d, (x, y, x + cw, y + 20), 4,
           fill=(30, 58, 95) if on else (18, 22, 29),
           outline=ACCENT if on else (44, 51, 60), width=1)
        s = str(i)
        bb = d.textbbox((0, 0), s, font=lab_f)
        d.text((x + (cw - bb[2]) // 2, y + 3), s, font=lab_f,
               fill=(198, 224, 255) if on else DIM)
        x += cw + gap


def frame(win_box, dimmed, slot, keys, lit, caption, active_slot, alpha=1.0):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    d.text((28, 22), "Drawer", font=title_f, fill=TEXT)
    d.text((129, 31), "bind any window to a slot, then call it with one hotkey",
           font=sub_f, fill=MUTED)

    d.rectangle((OFF_L, SCR_T, OFF_R, SCR_B), fill=OFF_BG)
    d.text((OFF_L + 10, SCR_T - 22), "OFF-SCREEN", font=labb_f, fill=DIM)
    rr(d, (SCR_L, SCR_T, SCR_R, SCR_B), 10, fill=SCR_BG, outline=BORDER_HI, width=2)
    d.text((SCR_L + 2, SCR_T - 22), "YOUR SCREEN", font=labb_f, fill=MUTED)
    draw_editor(d)

    if win_box is not None:
        if alpha >= 1.0:
            draw_win(d, win_box, dimmed, slot)
        else:                                  # плавный уход из середины экрана
            layer = img.copy()
            dl = ImageDraw.Draw(layer)
            draw_win(dl, win_box, dimmed, slot)
            img = Image.blend(img, layer, alpha)
            d = ImageDraw.Draw(img)

    yy = SCR_T - 6
    while yy < SCR_B + 6:
        d.rectangle((SCR_R + 3, yy, SCR_R + 4, min(yy + 7, SCR_B + 6)), fill=(90, 100, 112))
        yy += 13

    draw_slots(d, active_slot)
    draw_keys(d, keys, lit)
    bb = d.textbbox((0, 0), caption, font=cap_f)
    d.text(((W - bb[2]) // 2, 476), caption, font=cap_f, fill=TEXT)
    return img


# --- раскадровка ---------------------------------------------------------
BIND = ["Ctrl", "Alt", "Shift", "3"]
CALL = ["Ctrl", "Alt", "3"]

CAP_ANY   = "A window you're already using — anywhere on screen."
CAP_BIND  = "Ctrl + Alt + Shift + 3 binds this exact window to slot 3."
CAP_TAKE  = "Ctrl + Alt + 3 — it takes its place at the edge."
CAP_GONE  = "Press again — and it's gone."
CAP_PARK  = "Parked outside the screen. Nothing was closed."

seq = []
def add(n, **kw):
    for _ in range(n):
        seq.append(dict(kw))

def parked_box(x):
    return (x, SCR_T, x + PANEL_W, SCR_B)

# 1. обычное окно, слот ещё не занят
add(20, win_box=FLOAT_BOX, dimmed=False, slot=None,
    keys=BIND, lit=False, caption=CAP_ANY, active_slot=0)
# 2. привязка
add(6,  win_box=FLOAT_BOX, dimmed=False, slot=None,
    keys=BIND, lit=True,  caption=CAP_BIND, active_slot=0)
add(22, win_box=FLOAT_BOX, dimmed=False, slot=3,
    keys=BIND, lit=True,  caption=CAP_BIND, active_slot=3)
# 3. первый вызов: окно уходит к краю и выезжает оттуда
add(6,  win_box=FLOAT_BOX, dimmed=False, slot=3,
    keys=CALL, lit=True,  caption=CAP_TAKE, active_slot=3)
for i in range(6):
    seq.append(dict(win_box=FLOAT_BOX, dimmed=False, slot=3, keys=CALL, lit=True,
                    caption=CAP_TAKE, active_slot=3, alpha=1 - (i + 1) / 6))
for i in range(1, 10):
    x = round(PANEL_PARKED + (PANEL_DEPLOYED - PANEL_PARKED) * ease(i / 9))
    seq.append(dict(win_box=parked_box(x), dimmed=False, slot=3, keys=CALL,
                    lit=True, caption=CAP_TAKE, active_slot=3))
add(24, win_box=parked_box(PANEL_DEPLOYED), dimmed=False, slot=3,
    keys=CALL, lit=False, caption=CAP_TAKE, active_slot=3)
# 4. убрать
add(6,  win_box=parked_box(PANEL_DEPLOYED), dimmed=False, slot=3,
    keys=CALL, lit=True, caption=CAP_GONE, active_slot=3)
for i in range(1, 10):
    x = round(PANEL_DEPLOYED + (PANEL_PARKED - PANEL_DEPLOYED) * ease(i / 9))
    seq.append(dict(win_box=parked_box(x), dimmed=x > SCR_R - 40, slot=3,
                    keys=CALL, lit=True, caption=CAP_GONE, active_slot=3))
add(22, win_box=parked_box(PANEL_PARKED), dimmed=True, slot=3,
    keys=CALL, lit=False, caption=CAP_PARK, active_slot=3)

for i, kw in enumerate(seq):
    kw.setdefault("alpha", 1.0)
    frame(**kw).save(os.path.join(OUT, "b%04d.png" % i))

print("кадров:", len(seq), "=", round(len(seq) / FPS, 2), "c")
