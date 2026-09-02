# -*- coding: utf-8 -*-
"""Статичное превью Drawer для README: одно состояние над другим."""
import os
from PIL import Image, ImageDraw, ImageFont

W, H = 900, 708
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
title_f = ImageFont.truetype(F + "segoeuib.ttf", 30)
sub_f   = ImageFont.truetype(F + "segoeui.ttf", 16)
state_f = ImageFont.truetype(F + "seguisb.ttf", 16)
lab_f   = ImageFont.truetype(F + "segoeui.ttf", 12)
labb_f  = ImageFont.truetype(F + "seguisb.ttf", 12)
key_f   = ImageFont.truetype(F + "seguisb.ttf", 14)
cap_f   = ImageFont.truetype(F + "segoeui.ttf", 14)
badge_f = ImageFont.truetype(F + "seguisb.ttf", 13)

SCR_L, SCR_R = 32, 566
OFF_L, OFF_R = 574, 868
ROW_H   = 176
ROW1_T  = 98
ROW2_T  = 362
PANEL_W = 178

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)


def rr(box, r, fill=None, outline=None, width=1):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def centered(text, font, x0, x1, y, fill):
    bb = d.textbbox((0, 0), text, font=font)
    d.text((x0 + (x1 - x0 - bb[2]) // 2, y), text, font=font, fill=fill)


def editor(top):
    """Мок редактора внутри экрана."""
    x0, y0, x1, y1 = SCR_L + 9, top + 9, SCR_R - 9, top + ROW_H - 9
    rr((x0, y0, x1, y1), 5, fill=(15, 19, 26))
    d.rectangle((x0, y0, x1, y0 + 20), fill=(20, 25, 32))
    rr((x0 + 5, y0 + 3, x0 + 84, y0 + 19), 3, fill=(15, 19, 26))
    d.text((x0 + 12, y0 + 4), "main.py", font=lab_f, fill=MUTED)
    d.text((x0 + 94, y0 + 4), "utils.py", font=lab_f, fill=DIM)
    rows = [(24, ORANGE, 32), (24, ACCENT, 66), (0, None, 0),
            (24, PURPLE, 50), (40, MUTED, 92), (40, GREEN, 70),
            (40, MUTED, 116), (24, PURPLE, 58), (40, MUTED, 84)]
    y = y0 + 34
    for indent, col, w in rows:
        if col:
            d.rectangle((x0 + 12 + indent, y, x0 + 12 + indent + w, y + 5), fill=col)
            d.rectangle((x0 + 21 + indent + w, y, x0 + 21 + indent + w + w // 2, y + 5),
                        fill=(46, 54, 64))
        y += 16


def badge(x, y, n, on):
    rr((x, y, x + 20, y + 20), 10,
       fill=ACCENT if on else (30, 36, 45),
       outline=ACCENT if on else (58, 66, 76), width=1)
    bb = d.textbbox((0, 0), str(n), font=badge_f)
    d.text((x + (20 - bb[2]) // 2, y + 2), str(n),
           font=badge_f, fill=(10, 14, 20) if on else MUTED)


def window(x, top, n, dimmed, ghost=False):
    """Окно слота: живое, приглушённое или пунктирный след от него."""
    y0, y1 = top + 3, top + ROW_H - 3
    if ghost:
        step = 8
        for yy in range(y0, y1, step * 2):
            d.rectangle((x, yy, x + 1, min(yy + step, y1)), fill=(52, 60, 70))
            d.rectangle((x + PANEL_W - 1, yy, x + PANEL_W, min(yy + step, y1)),
                        fill=(52, 60, 70))
        for xx in range(x, x + PANEL_W, step * 2):
            d.rectangle((xx, y0, min(xx + step, x + PANEL_W), y0 + 1), fill=(52, 60, 70))
            d.rectangle((xx, y1 - 1, min(xx + step, x + PANEL_W), y1), fill=(52, 60, 70))
        centered("empty", lab_f, x, x + PANEL_W, (y0 + y1) // 2 - 8, DIM)
        return
    body = (17, 21, 27) if dimmed else (22, 27, 34)
    edge = (44, 62, 84) if dimmed else ACCENT
    rr((x, y0, x + PANEL_W, y1), 7, fill=body, outline=edge, width=2)
    d.rectangle((x + 2, y0 + 8, x + PANEL_W - 2, y0 + 28), fill=(28, 34, 43))
    rr((x + 2, y0 + 2, x + PANEL_W - 2, y0 + 16), 7, fill=(28, 34, 43))
    d.ellipse((x + 10, y0 + 8, x + 22, y0 + 20), fill=edge)
    d.text((x + 29, y0 + 7), "Messenger", font=labb_f,
           fill=TEXT if not dimmed else DIM)
    bub = [(0, 104, 2), (1, 88, 2), (0, 118, 2)]
    y = y0 + 38
    for side, w, lines in bub:
        h = 9 + lines * 10
        bx = x + 12 if side == 0 else x + PANEL_W - 12 - w
        fill = ((36, 43, 53) if not dimmed else (26, 32, 40)) if side == 0 \
               else (ACCENT_D if not dimmed else (24, 38, 54))
        rr((bx, y, bx + w, y + h), 6, fill=fill)
        ly = y + 5
        for i in range(lines):
            lw = w - 14 - (16 if i == lines - 1 else 0)
            d.rectangle((bx + 7, ly, bx + 7 + lw, ly + 4),
                        fill=(96, 106, 118) if not dimmed else (54, 62, 72))
            ly += 10
        y += h + 7
    rr((x + 10, y1 - 28, x + PANEL_W - 10, y1 - 10), 9,
       fill=(30, 36, 45), outline=(50, 58, 68))
    badge(x + PANEL_W - 30, y0 + 8, n, not dimmed)


def screen_edge(top):
    """Пунктир — граница монитора, поверх всего."""
    yy = top - 6
    while yy < top + ROW_H + 6:
        d.rectangle((SCR_R + 3, yy, SCR_R + 4, min(yy + 6, top + ROW_H + 6)),
                    fill=(96, 106, 118))
        yy += 12


def keys(x, y, items, lit=True, scale=1.0):
    """Ряд клавиш; возвращает правую границу."""
    kh = int(28 * scale)
    for i, k in enumerate(items):
        bb = d.textbbox((0, 0), k, font=key_f)
        w = max(bb[2] + 20, 32)
        if lit:
            fill, outline, tc = (30, 58, 95), ACCENT, (198, 224, 255)
        else:
            fill, outline, tc = (26, 31, 39), BORDER, MUTED
        rr((x, y, x + w, y + kh), 5, fill=fill, outline=outline, width=1)
        d.text((x + (w - bb[2]) // 2, y + (kh - bb[3]) // 2 - 1), k, font=key_f, fill=tc)
        x += w
        if i < len(items) - 1:
            d.text((x + 5, y + (kh - bb[3]) // 2 - 1), "+", font=key_f, fill=DIM)
            x += 18
    return x


# --- заголовок -----------------------------------------------------------
d.text((32, 24), "Drawer", font=title_f, fill=TEXT)
d.text((146, 34), "Park any window off-screen. Bring it back with one hotkey.",
       font=sub_f, fill=MUTED)

# --- ряд 1: припарковано -------------------------------------------------
d.text((SCR_L + 2, ROW1_T - 22), "YOUR SCREEN", font=labb_f, fill=MUTED)
d.text((OFF_L + 8, ROW1_T - 22), "OFF-SCREEN", font=labb_f, fill=DIM)
d.rectangle((OFF_L, ROW1_T, OFF_R, ROW1_T + ROW_H), fill=OFF_BG)
rr((SCR_L, ROW1_T, SCR_R, ROW1_T + ROW_H), 9, fill=SCR_BG, outline=BORDER_HI, width=2)
editor(ROW1_T)
window(624, ROW1_T, 3, dimmed=True)
screen_edge(ROW1_T)
d.text((SCR_L + 2, ROW1_T + ROW_H + 10),
       "Slot 3 sits outside the monitor. Not minimised, not closed — parked.",
       font=state_f, fill=TEXT)

# --- переход -------------------------------------------------------------
ty = ROW1_T + ROW_H + 46
d.text((SCR_L + 2, ty + 6), "press", font=cap_f, fill=MUTED)
kx = keys(SCR_L + 52, ty, ["Ctrl", "Alt", "3"])
cx = kx + 22                                   # шеврон вниз — куда ведёт нажатие
d.polygon([(cx, ty + 6), (cx + 22, ty + 6), (cx + 11, ty + 22)], fill=ACCENT)

# --- ряд 2: выдвинуто ----------------------------------------------------
d.rectangle((OFF_L, ROW2_T, OFF_R, ROW2_T + ROW_H), fill=OFF_BG)
rr((SCR_L, ROW2_T, SCR_R, ROW2_T + ROW_H), 9, fill=SCR_BG, outline=BORDER_HI, width=2)
editor(ROW2_T)
window(624, ROW2_T, 3, dimmed=False, ghost=True)
window(SCR_R - PANEL_W - 6, ROW2_T, 3, dimmed=False)
screen_edge(ROW2_T)
d.text((SCR_L + 2, ROW2_T + ROW_H + 10),
       "It slides in over your work. Press again and it goes straight back.",
       font=state_f, fill=TEXT)

# --- легенда -------------------------------------------------------------
LG_T = 596
d.rectangle((32, LG_T - 18, 868, LG_T - 17), fill=BORDER)
cells = [
    (["Ctrl", "Alt", "1…9"],          "Show / hide slot"),
    (["Ctrl", "Alt", "Shift", "1…9"], "Bind active window to slot"),
    (["Ctrl", "Alt", "0"],            "Clear dynamic slots"),
    (["Ctrl", "Alt", "Shift", "0"],   "Exit, restore windows"),
]
for i, (ks, cap) in enumerate(cells):
    cx = 32 + (i % 2) * 430
    cy = LG_T + (i // 2) * 38
    ex = keys(cx, cy, ks, lit=False)
    d.text((ex + 14, cy + 7), cap, font=cap_f, fill=MUTED)
d.text((32, LG_T + 82),
       "Nine slots. Each can hold a fixed app or any window you bind on the fly.",
       font=cap_f, fill=DIM)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "drawer-preview.png")
img.save(out)
print("готово:", out, img.size)
