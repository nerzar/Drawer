# -*- coding: utf-8 -*-
"""
Ролик для README из записи «игра + Telegram».

Переписка в кадре настоящая, поэтому содержимое панели заменяется
необратимо размытой копией: панель вырезается ОДИН раз, размывается и
дальше просто накладывается на кадры. Отслеживать её покадрово не нужно —
окно едет как жёсткий прямоугольник.

Выезд в оригинале занимает 5 кадров (170 мс) и на 20 fps не читается,
поэтому он пересобирается заново по той же кривой, что в Slide():
1-(1-t)^3, но за большее число кадров.
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC  = os.path.join(HERE, "src")
OUT  = os.path.join(HERE, "out")
os.makedirs(OUT, exist_ok=True)

# --- геометрия исходника -------------------------------------------------
VW, VH   = 1918, 1078
PAN_L    = 775              # левый край выдвинутой панели
PAN_T, PAN_B = 0, 1025
PAN_W    = VW - PAN_L
BLUR_T, BLUR_B = 28, 982    # что закрываем: всё между заголовком и полем ввода
LIST_W = 320                # ширина колонки со списком чатов — она идёт до низа

FRAME_DEPLOYED = 61         # эталон панели
FRAME_BG_IN    = 32         # фон для въезда
FRAME_BG_OUT   = 121        # фон для выезда

# --- вывод ---------------------------------------------------------------
W       = 900
VID_H   = round(VH * W / VW)          # 506
CAP_H   = 66
H       = VID_H + CAP_H

BG     = (13, 17, 23)
TEXT   = (214, 222, 230)
MUTED  = (125, 133, 144)
DIM    = (96, 104, 114)
BORDER = (48, 54, 61)
ACCENT = (88, 166, 255)

F = "C:/Windows/Fonts/"
cap_f  = ImageFont.truetype(F + "seguisb.ttf", 19)
note_f = ImageFont.truetype(F + "segoeui.ttf", 13)
key_f  = ImageFont.truetype(F + "seguisb.ttf", 14)


def load(n):
    return Image.open(os.path.join(SRC, "f%03d.png" % n)).convert("RGB")


def scrub(pan, box):
    """Необратимо: ужать в 12 раз, вернуть обратно, размыть."""
    x0, y0, x1, y1 = box
    region = pan.crop(box)
    small = region.resize((max(1, (x1 - x0) // 12), max(1, (y1 - y0) // 12)),
                          Image.BILINEAR)
    region = small.resize(region.size, Image.BILINEAR)
    pan.paste(region.filter(ImageFilter.GaussianBlur(7)), (x0, y0))


def make_blurred_panel():
    """Панель, вырезанная один раз и необратимо размытая."""
    pan = load(FRAME_DEPLOYED).crop((PAN_L, PAN_T, VW, PAN_B)).copy()
    scrub(pan, (0, BLUR_T, PAN_W, BLUR_B))        # поиск, список, переписка
    scrub(pan, (0, BLUR_B, LIST_W, PAN_B))        # хвост списка чатов внизу
    return pan


PANEL = make_blurred_panel()


def compose(bg_frame, panel_x):
    """Кадр: фон игры + панель на позиции panel_x (или без неё)."""
    img = bg_frame.copy()
    if panel_x is not None and panel_x < VW:
        vis = VW - panel_x
        img.paste(PANEL.crop((0, 0, vis, PAN_B)), (panel_x, PAN_T))
    return img


def keys(d, x, y, items):
    for i, k in enumerate(items):
        bb = d.textbbox((0, 0), k, font=key_f)
        w = max(bb[2] + 18, 30)
        d.rounded_rectangle((x, y, x + w, y + 26), 5,
                            fill=(30, 58, 95), outline=ACCENT, width=1)
        d.text((x + (w - bb[2]) // 2, y + 4), k, font=key_f, fill=(198, 224, 255))
        x += w
        if i < len(items) - 1:
            d.text((x + 5, y + 4), "+", font=key_f, fill=DIM)
            x += 17
    return x


def render(bg_frame, panel_x, caption, lit):
    canvas = Image.new("RGB", (W, H), BG)
    vid = compose(bg_frame, panel_x).resize((W, VID_H), Image.LANCZOS)
    canvas.paste(vid, (0, 0))
    d = ImageDraw.Draw(canvas)
    d.rectangle((0, VID_H, W, VID_H), fill=BORDER)
    y = VID_H + 20
    x = 22
    if lit:
        x = keys(d, x, y - 3, ["Ctrl", "Alt", "3"]) + 18
    d.text((x, y), caption, font=cap_f, fill=TEXT)
    d.text((22, VID_H + 46), "chat content blurred — real recording, real window",
           font=note_f, fill=DIM)
    return canvas


def ease(t):
    return 1 - (1 - t) ** 3


# --- раскадровка ---------------------------------------------------------
seq = []

CAP_BEFORE = "You're in a fullscreen game."
CAP_IN     = "Telegram slides in from off-screen"
CAP_HOLD   = "Answer without leaving the game. Nothing was minimised."
CAP_OUT    = "Press again"
CAP_AFTER  = "Parked outside the screen. The game never lost focus."

SLIDE = 10

# «Живые» кадры игры — единственное, что реально весит в GIF: фон
# анимирован непрерывно и межкадровое сжатие на нём не работает. Поэтому
# живых кусков ровно два, коротких, а пока панель выдвинута — фон замер:
# одинаковые кадры почти ничего не стоят, а смотреть там всё равно на неё.
for n in range(29, 33):                                   # до
    seq.append((load(n), None, CAP_BEFORE, False))
for _ in range(4):
    seq.append((load(32), None, CAP_BEFORE, False))

bg_in = load(FRAME_BG_IN)                                 # въезд пересобран:
for i in range(1, SLIDE + 1):                             # в оригинале он 5
    x = round(VW + (PAN_L - VW) * ease(i / SLIDE))        # кадров и на 20 fps
    seq.append((bg_in, x, CAP_IN, True))                  # попросту не виден

bg_hold = load(FRAME_DEPLOYED)
for _ in range(18):                                       # держим
    seq.append((bg_hold, PAN_L, CAP_HOLD, False))

bg_out = load(FRAME_BG_OUT)
for i in range(1, SLIDE + 1):                             # выезд
    x = round(PAN_L + (VW - PAN_L) * ease(i / SLIDE))
    seq.append((bg_out, x, CAP_OUT, True))

for n in range(125, 130):                                 # после
    seq.append((load(n), None, CAP_AFTER, False))
for _ in range(11):                                       # додержать подпись
    seq.append((load(129), None, CAP_AFTER, False))

for i, (bg, px, cap, lit) in enumerate(seq):
    render(bg, px, cap, lit).save(os.path.join(OUT, "r%04d.png" % i))

print("кадров:", len(seq), " холст:", W, "x", H)
