from __future__ import annotations

from pathlib import Path
from html import escape
import math


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "art" / "ui" / "arkham_25d"


PALETTE = {
    "void": "#05080d",
    "ink": "#0a0e14",
    "panel": "#111620",
    "steel": "#1e3a52",
    "steel2": "#2b536e",
    "blue": "#3a82b2",
    "cyan": "#6bc7ff",
    "ice": "#b2e8ff",
    "amber": "#e8a830",
    "gold": "#ffdc82",
    "red": "#d64440",
    "magenta": "#c7479e",
    "text": "#e0e8f0",
    "muted": "#8592a0",
}


def fmt(value: float) -> str:
    return f"{value:.2f}".rstrip("0").rstrip(".")


def pts(points: list[tuple[float, float]]) -> str:
    return " ".join(f"{fmt(x)},{fmt(y)}" for x, y in points)


def hex_points(cx: float, cy: float, rx: float, ry: float | None = None) -> list[tuple[float, float]]:
    ry = rx if ry is None else ry
    return [(cx + math.cos(math.radians(60 * i)) * rx, cy + math.sin(math.radians(60 * i)) * ry) for i in range(6)]


def svg(width: int, height: int, body: str, *, defs: str = "", view_box: str | None = None) -> str:
    vb = view_box or f"0 0 {width} {height}"
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="{vb}" shape-rendering="geometricPrecision">\n'
        f"<defs>{defs}</defs>\n{body}\n</svg>\n"
    )


def panel_path(x: float, y: float, w: float, h: float, cut: float = 18) -> str:
    return (
        f"M {fmt(x + cut)} {fmt(y)} H {fmt(x + w - cut)} L {fmt(x + w)} {fmt(y + cut)} "
        f"V {fmt(y + h - cut)} L {fmt(x + w - cut)} {fmt(y + h)} H {fmt(x + cut)} "
        f"L {fmt(x)} {fmt(y + h - cut)} V {fmt(y + cut)} Z"
    )


def panel_group(x: float, y: float, w: float, h: float, *, accent: str = "cyan", cut: float = 18,
                fill_opacity: float = 0.92, title_slot: bool = False) -> str:
    a = PALETTE[accent]
    out = [
        f'<path d="{panel_path(x + 5, y + 6, w, h, cut)}" fill="#020407" opacity=".72"/>',
        f'<path d="{panel_path(x, y, w, h, cut)}" fill="{PALETTE["panel"]}" fill-opacity="{fill_opacity}" '
        f'stroke="{PALETTE["steel2"]}" stroke-width="3"/>',
        f'<path d="M {fmt(x + cut + 10)} {fmt(y + 6)} H {fmt(x + w - cut - 24)}" stroke="{a}" stroke-width="3" opacity=".92"/>',
        f'<path d="M {fmt(x + 8)} {fmt(y + h - cut - 4)} V {fmt(y + cut + 6)}" stroke="{PALETTE["blue"]}" stroke-width="2" opacity=".65"/>',
        f'<polygon points="{pts([(x + w - 30, y + h - 8), (x + w - 10, y + h - 28), (x + w - 10, y + h - 12), (x + w - 14, y + h - 8)])}" fill="{a}" opacity=".65"/>',
        f'<circle cx="{fmt(x + 19)}" cy="{fmt(y + 19)}" r="4" fill="#05080d" stroke="{PALETTE["muted"]}" stroke-width="2"/>',
    ]
    if title_slot:
        out.append(f'<path d="M {fmt(x + 34)} {fmt(y + 18)} H {fmt(x + w * .45)}" stroke="{PALETTE["muted"]}" stroke-width="4"/>')
    return "\n".join(out)


def tick_row(x: float, y: float, count: int, gap: float, *, color: str = "cyan", active: int = 0,
             w: float = 30, h: float = 12) -> str:
    out: list[str] = []
    for i in range(count):
        px = x + i * gap
        fill = PALETTE[color] if i < active else PALETTE["steel"]
        opacity = ".96" if i < active else ".55"
        out.append(
            f'<path d="M {fmt(px + 5)} {fmt(y)} H {fmt(px + w)} L {fmt(px + w - 5)} {fmt(y + h)} H {fmt(px)} Z" '
            f'fill="{fill}" opacity="{opacity}" stroke="{PALETTE["blue"]}" stroke-width="1"/>'
        )
    return "\n".join(out)


def label(x: float, y: float, text: str, size: int = 18, *, color: str = "text", anchor: str = "start",
          weight: int = 600, tracking: float = 1.2) -> str:
    return (
        f'<text x="{fmt(x)}" y="{fmt(y)}" fill="{PALETTE[color]}" font-size="{size}" font-weight="{weight}" '
        f'letter-spacing="{tracking}" text-anchor="{anchor}" font-family="Microsoft YaHei, Noto Sans SC, sans-serif">'
        f'{escape(text)}</text>'
    )


def vital_frame() -> str:
    b = [panel_group(0, 0, 520, 154, accent="cyan", cut=24)]
    b += [
        '<path d="M 32 30 H 122 L 142 50 V 124 H 32 Z" fill="#070b11" stroke="#3a82b2" stroke-width="3"/>',
        '<circle cx="87" cy="77" r="31" fill="#0a1520" stroke="#6bc7ff" stroke-width="3"/>',
        '<path d="M 62 106 L 71 84 L 78 89 L 87 67 L 95 89 L 105 82 L 113 106" fill="none" stroke="#6bc7ff" stroke-width="5"/>',
        '<path d="M 165 48 H 486" stroke="#0a0e14" stroke-width="23"/>',
        '<path d="M 165 48 H 433" stroke="#d64440" stroke-width="13"/>',
        '<path d="M 165 48 H 433" stroke="#ff7b70" stroke-width="3" opacity=".8"/>',
        '<path d="M 166 91 H 350" stroke="#0a0e14" stroke-width="17"/>',
        '<path d="M 166 91 H 286" stroke="#3a82b2" stroke-width="9"/>',
        '<path d="M 377 82 L 403 82 L 413 92 L 403 111 L 377 111 L 367 92 Z" fill="#1e3a52" stroke="#b2e8ff" stroke-width="2"/>',
        '<path d="M 426 82 L 452 82 L 462 92 L 452 111 L 426 111 L 416 92 Z" fill="#e8a830" stroke="#ffdc82" stroke-width="2"/>',
        '<path d="M 475 82 L 496 82 V 111 H 475 L 465 92 Z" fill="#e8a830" stroke="#ffdc82" stroke-width="2"/>',
        '<path d="M 154 127 H 340" stroke="#8592a0" stroke-width="2" stroke-dasharray="5 8" opacity=".7"/>',
    ]
    return svg(520, 154, "\n".join(b))


def companion_frame() -> str:
    b = [panel_group(0, 0, 310, 88, accent="blue", cut=17)]
    b += [
        '<circle cx="50" cy="44" r="27" fill="#08131d" stroke="#3a82b2" stroke-width="3"/>',
        '<path d="M 35 61 C 37 48 42 44 50 44 C 59 44 65 49 66 62" fill="#1e3a52"/>',
        '<circle cx="50" cy="35" r="10" fill="#8592a0"/>',
        '<path d="M 91 34 H 281" stroke="#070a0f" stroke-width="17"/>',
        '<path d="M 91 34 H 248" stroke="#3a82b2" stroke-width="9"/>',
        '<path d="M 92 61 H 226" stroke="#8592a0" stroke-width="3" stroke-dasharray="10 6" opacity=".58"/>',
    ]
    return svg(310, 88, "\n".join(b))


def enemy_health_frame() -> str:
    b = [
        '<path d="M 17 16 H 111 L 126 2 H 164 L 179 16 H 273 L 288 31 L 273 54 H 17 L 2 31 Z" fill="#080c12" fill-opacity=".93" stroke="#2b536e" stroke-width="3"/>',
        '<path d="M 22 29 H 268" stroke="#020407" stroke-width="15"/>',
        '<path d="M 22 29 H 207" stroke="#d64440" stroke-width="8"/>',
        '<path d="M 23 18 H 110" stroke="#6bc7ff" stroke-width="2"/>',
        '<circle cx="145" cy="11" r="8" fill="#e8a830" stroke="#ffdc82" stroke-width="2"/>',
        '<path d="M 145 5 L 150 16 H 140 Z" fill="#0a0e14"/>',
    ]
    return svg(290, 58, "\n".join(b))


def end_turn_button() -> str:
    b = [
        '<polygon points="28,4 192,4 230,40 230,73 195,108 29,108 4,82 4,30" fill="#080b10" stroke="#72511f" stroke-width="4"/>',
        '<polygon points="38,15 184,15 217,46 217,68 188,97 37,97 17,76 17,36" fill="#211a0e" stroke="#e8a830" stroke-width="3"/>',
        '<polygon points="54,27 174,27 203,50 203,63 177,85 52,85 31,68 31,43" fill="#e8a830" opacity=".12"/>',
        '<path d="M 51 39 H 163 L 183 56 L 163 73 H 51" fill="none" stroke="#ffdc82" stroke-width="4"/>',
        '<path d="M 165 47 L 181 56 L 165 65" fill="none" stroke="#ffdc82" stroke-width="5"/>',
        '<circle cx="27" cy="28" r="4" fill="#ffdc82"/>',
        '<circle cx="205" cy="82" r="4" fill="#e8a830"/>',
    ]
    return svg(236, 112, "\n".join(b))


def combo_meter() -> str:
    b = [panel_group(0, 0, 390, 86, accent="cyan", cut=16, fill_opacity=.88)]
    b += [
        '<circle cx="48" cy="43" r="24" fill="#07111a" stroke="#6bc7ff" stroke-width="3"/>',
        '<path d="M 33 48 L 44 34 L 50 43 L 62 29 L 56 48 L 66 48" fill="none" stroke="#b2e8ff" stroke-width="4"/>',
        tick_row(91, 35, 6, 46, color="cyan", active=4, w=34, h=16),
        '<path d="M 92 63 H 356" stroke="#3a82b2" stroke-width="2" stroke-dasharray="5 5" opacity=".65"/>',
    ]
    return svg(390, 86, "\n".join(b))


def isolation_meter() -> str:
    b = [panel_group(0, 0, 380, 54, accent="red", cut=13, fill_opacity=.9)]
    for i in range(10):
        x = 24 + i * 33
        if i < 5:
            color = PALETTE["cyan"]
        elif i < 8:
            color = PALETTE["amber"]
        else:
            color = PALETTE["red"]
        b.append(f'<path d="M {x+5} 17 H {x+27} L {x+22} 37 H {x} Z" fill="{color}" opacity="{.92 if i < 7 else .3}"/>')
    b += [
        '<path d="M 284 8 V 46" stroke="#d64440" stroke-width="3"/>',
        '<path d="M 284 8 L 293 13 L 284 18 Z" fill="#d64440"/>',
    ]
    return svg(380, 54, "\n".join(b))


def card_tray() -> str:
    b = [
        '<path d="M 42 34 L 80 4 H 1020 L 1058 34 L 1094 214 L 1068 246 H 32 L 6 214 Z" fill="#070b11" fill-opacity=".91" stroke="#1e3a52" stroke-width="4"/>',
        '<path d="M 77 22 H 1023" stroke="#3a82b2" stroke-width="3"/>',
        '<path d="M 31 201 Q 550 253 1069 201" fill="none" stroke="#6bc7ff" stroke-width="3" opacity=".5"/>',
        '<path d="M 52 216 Q 550 259 1048 216" fill="none" stroke="#0a0e14" stroke-width="18"/>',
        '<path d="M 50 44 L 27 66 V 175" fill="none" stroke="#3a82b2" stroke-width="2"/>',
        '<path d="M 1050 44 L 1073 66 V 175" fill="none" stroke="#3a82b2" stroke-width="2"/>',
    ]
    for i in range(5):
        cx = 280 + i * 135
        b.append(f'<path d="M {cx-43} 214 Q {cx} 224 {cx+43} 214" fill="none" stroke="#8592a0" stroke-width="3" opacity=".5"/>')
    return svg(1100, 250, "\n".join(b))


def tooltip_frame() -> str:
    b = [panel_group(0, 0, 430, 280, accent="amber", cut=24, title_slot=True)]
    b += [
        '<path d="M 30 65 H 400" stroke="#2b536e" stroke-width="2"/>',
        '<path d="M 33 92 H 366 M 33 118 H 385 M 33 144 H 332 M 33 188 H 375 M 33 214 H 352" stroke="#8592a0" stroke-width="7" opacity=".32"/>',
        '<path d="M 292 238 H 391 L 405 252 L 391 266 H 292 L 279 252 Z" fill="#211a0e" stroke="#e8a830" stroke-width="2"/>',
    ]
    return svg(430, 280, "\n".join(b))


def intent_icon(kind: str) -> str:
    color = {"attack": "red", "shield": "cyan", "debuff": "magenta", "unknown": "amber"}[kind]
    a = PALETTE[color]
    b = [
        f'<polygon points="48,3 82,20 93,51 75,82 44,94 14,76 3,45 21,14" fill="#091019" stroke="{a}" stroke-width="4"/>',
        f'<polygon points="48,10 77,25 85,51 70,76 44,86 20,71 11,45 26,20" fill="{a}" opacity=".12"/>',
    ]
    if kind == "attack":
        b += ['<path d="M 27 70 L 61 28 L 70 24 L 67 34 L 34 75 Z" fill="#d64440" stroke="#ffb0a8" stroke-width="2"/>', '<path d="M 27 55 L 42 70" stroke="#ffb0a8" stroke-width="5"/>']
    elif kind == "shield":
        b += ['<path d="M 48 20 L 71 29 V 48 C 71 63 60 73 48 78 C 36 73 25 63 25 48 V 29 Z" fill="#1e3a52" stroke="#b2e8ff" stroke-width="4"/>', '<path d="M 48 27 V 69" stroke="#6bc7ff" stroke-width="3"/>']
    elif kind == "debuff":
        b += ['<path d="M 66 31 C 48 19 26 35 31 53 C 36 70 60 74 69 57 C 75 45 66 37 55 40 C 44 43 44 56 53 59" fill="none" stroke="#ff9edc" stroke-width="6"/>', '<circle cx="51" cy="51" r="5" fill="#c7479e"/>']
    else:
        b += ['<path d="M 19 49 Q 48 22 77 49 Q 48 76 19 49 Z" fill="#211a0e" stroke="#ffdc82" stroke-width="4"/>', '<circle cx="48" cy="49" r="12" fill="#e8a830"/>', '<circle cx="48" cy="49" r="5" fill="#0a0e14"/>']
    return svg(96, 96, "\n".join(b))


def condition_pips() -> str:
    b: list[str] = []
    colors = ["red", "amber", "cyan", "magenta", "ice"]
    for i, color in enumerate(colors):
        cx = 48 + i * 96
        a = PALETTE[color]
        b.append(f'<polygon points="{pts(hex_points(cx, 40, 33, 33))}" fill="#091019" stroke="{a}" stroke-width="3"/>')
        if i == 0:
            b.append(f'<path d="M {cx} 18 C {cx-16} 38 {cx-15} 58 {cx} 62 C {cx+15} 58 {cx+16} 38 {cx} 18 Z" fill="{a}"/>')
        elif i == 1:
            b.append(f'<path d="M {cx-9} 15 L {cx+4} 34 L {cx-5} 40 L {cx+10} 64" fill="none" stroke="{a}" stroke-width="6"/>')
        elif i == 2:
            b.append(f'<path d="M {cx-18} 27 L {cx} 18 L {cx+18} 27 V 52 L {cx} 63 L {cx-18} 52 Z" fill="{a}" opacity=".7"/>')
        elif i == 3:
            b.append(f'<path d="M {cx-8} 18 H {cx+8} M {cx-5} 21 V 34 L {cx-16} 55 Q {cx} 68 {cx+16} 55 L {cx+5} 34 V 21" fill="none" stroke="{a}" stroke-width="5"/>')
        else:
            b.append(f'<path d="M {cx-18} 48 Q {cx-29} 31 {cx-13} 23 Q {cx+1} 17 {cx+7} 31 M {cx+18} 33 Q {cx+29} 50 {cx+13} 58 Q {cx-1} 64 {cx-7} 50" fill="none" stroke="{a}" stroke-width="7"/>')
    return svg(480, 80, "\n".join(b))


def card_brackets() -> str:
    b = [
        '<path d="M 5 55 V 20 L 20 5 H 62 M 178 5 H 220 L 235 20 V 55 M 235 285 V 320 L 220 335 H 178 M 62 335 H 20 L 5 320 V 285" fill="none" stroke="#6bc7ff" stroke-width="9"/>',
        '<path d="M 21 68 V 34 L 34 21 H 69 M 171 21 H 206 L 219 34 V 68 M 219 272 V 306 L 206 319 H 171 M 69 319 H 34 L 21 306 V 272" fill="none" stroke="#b2e8ff" stroke-width="3" opacity=".75"/>',
        '<path d="M 92 13 H 148 M 92 327 H 148" stroke="#e8a830" stroke-width="4"/>',
    ]
    return svg(240, 340, "\n".join(b))


def settings_hex() -> str:
    b = [
        f'<polygon points="{pts(hex_points(40, 40, 35, 35))}" fill="#091019" stroke="#3a82b2" stroke-width="3"/>',
        '<circle cx="40" cy="40" r="13" fill="none" stroke="#b2e8ff" stroke-width="5" stroke-dasharray="8 4"/>',
        '<circle cx="40" cy="40" r="5" fill="#6bc7ff"/>',
    ]
    return svg(80, 80, "\n".join(b))


def draw_human(x: float, ground_y: float, scale: float, *, female: bool = False) -> str:
    skin = "#b7c3c9"
    suit = "#20394a" if not female else "#253347"
    accent = PALETTE["cyan"] if not female else PALETTE["amber"]
    h = 172 * scale
    y = ground_y - h
    out = [
        f'<ellipse cx="{x}" cy="{ground_y + 6}" rx="{35*scale}" ry="{9*scale}" fill="#020305" opacity=".7"/>',
        f'<circle cx="{x}" cy="{y + 22*scale}" r="{16*scale}" fill="{skin}"/>',
        f'<path d="M {x-18*scale} {y+17*scale} Q {x} {y-5*scale} {x+19*scale} {y+17*scale} V {y+25*scale} H {x-18*scale} Z" fill="#11161e"/>',
        f'<path d="M {x-24*scale} {y+46*scale} L {x-34*scale} {y+109*scale} L {x-15*scale} {y+121*scale} L {x-8*scale} {y+72*scale} L {x+10*scale} {y+72*scale} L {x+18*scale} {y+121*scale} L {x+35*scale} {y+108*scale} L {x+24*scale} {y+47*scale} Z" fill="{suit}" stroke="#456177" stroke-width="{2*scale}"/>',
        f'<path d="M {x-21*scale} {y+50*scale} H {x+21*scale}" stroke="{accent}" stroke-width="{4*scale}"/>',
        f'<path d="M {x-16*scale} {y+119*scale} L {x-18*scale} {ground_y} M {x+16*scale} {y+119*scale} L {x+18*scale} {ground_y}" stroke="#111822" stroke-width="{15*scale}"/>',
        f'<path d="M {x-26*scale} {ground_y} H {x-8*scale} M {x+9*scale} {ground_y} H {x+28*scale}" stroke="#2b3e4d" stroke-width="{8*scale}"/>',
    ]
    if female:
        out.append(f'<path d="M {x-18*scale} {y+16*scale} Q {x-28*scale} {y+49*scale} {x-10*scale} {y+54*scale} M {x+18*scale} {y+16*scale} Q {x+28*scale} {y+48*scale} {x+10*scale} {y+54*scale}" fill="none" stroke="#251d24" stroke-width="{8*scale}"/>')
    return "\n".join(out)


def draw_monster(x: float, ground_y: float, scale: float, variant: int) -> str:
    core = "#49203f" if variant == 0 else "#243f44"
    glow = PALETTE["magenta"] if variant == 0 else PALETTE["cyan"]
    out = [f'<ellipse cx="{x}" cy="{ground_y+8}" rx="{54*scale}" ry="{13*scale}" fill="#020305" opacity=".72"/>']
    for i in range(5):
        dx = (-42 + i * 21) * scale
        bend = (-1 if i % 2 else 1) * (18 + i * 2) * scale
        out.append(f'<path d="M {x+dx} {ground_y-70*scale} Q {x+dx+bend} {ground_y-28*scale} {x+dx-8*scale} {ground_y}" fill="none" stroke="{core}" stroke-width="{12*scale}" stroke-linecap="round"/>')
    out += [
        f'<path d="M {x-43*scale} {ground_y-62*scale} Q {x-52*scale} {ground_y-130*scale} {x} {ground_y-158*scale} Q {x+55*scale} {ground_y-130*scale} {x+41*scale} {ground_y-59*scale} Q {x} {ground_y-33*scale} {x-43*scale} {ground_y-62*scale} Z" fill="{core}" stroke="#7b3a68" stroke-width="{4*scale}"/>',
        f'<ellipse cx="{x}" cy="{ground_y-113*scale}" rx="{27*scale}" ry="{20*scale}" fill="#09080d" stroke="{glow}" stroke-width="{4*scale}"/>',
        f'<circle cx="{x}" cy="{ground_y-113*scale}" r="{8*scale}" fill="{glow}"/>',
        f'<path d="M {x-37*scale} {ground_y-85*scale} Q {x-78*scale} {ground_y-69*scale} {x-90*scale} {ground_y-38*scale} M {x+37*scale} {ground_y-85*scale} Q {x+76*scale} {ground_y-68*scale} {x+92*scale} {ground_y-36*scale}" fill="none" stroke="{core}" stroke-width="{13*scale}" stroke-linecap="round"/>',
    ]
    return "\n".join(out)


def concept_svg() -> str:
    defs = '''
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#07131c"/><stop offset=".55" stop-color="#071019"/><stop offset="1" stop-color="#020407"/></linearGradient>
    <linearGradient id="floor" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#142330"/><stop offset="1" stop-color="#070a0f"/></linearGradient>
    <linearGradient id="light" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#b2e8ff" stop-opacity=".22"/><stop offset="1" stop-color="#6bc7ff" stop-opacity="0"/></linearGradient>
    <radialGradient id="amberGlow"><stop stop-color="#ffdc82" stop-opacity=".32"/><stop offset="1" stop-color="#e8a830" stop-opacity="0"/></radialGradient>
    <radialGradient id="magentaGlow"><stop stop-color="#c7479e" stop-opacity=".28"/><stop offset="1" stop-color="#c7479e" stop-opacity="0"/></radialGradient>
    <pattern id="grid" width="48" height="48" patternUnits="userSpaceOnUse"><path d="M48 0H0V48" fill="none" stroke="#2b536e" stroke-width="1" opacity=".18"/></pattern>
    '''
    b: list[str] = [
        '<rect width="1920" height="1080" fill="url(#bg)"/>',
        '<rect y="0" width="1920" height="610" fill="url(#grid)" opacity=".5"/>',
        '<path d="M 0 0 H 1920 V 590 L 1700 520 H 220 L 0 590 Z" fill="#081019"/>',
        '<path d="M 225 92 H 1695 L 1765 167 V 510 L 1668 585 H 252 L 155 510 V 167 Z" fill="#0c151f" stroke="#25465d" stroke-width="8"/>',
        '<path d="M 314 145 H 1606 L 1665 208 V 474 L 1590 530 H 330 L 255 474 V 208 Z" fill="#071019" stroke="#1e3a52" stroke-width="5"/>',
        '<path d="M 355 177 H 1570 V 496 H 355 Z" fill="#03090f"/>',
        '<path d="M 375 196 H 1550 V 470 H 375 Z" fill="#071521" stroke="#3a82b2" stroke-width="3"/>',
        '<path d="M 405 216 H 1518 V 452 H 405 Z" fill="#02080e"/>',
    ]
    # Starfield / distant machinery beyond the window.
    for i, (sx, sy, r) in enumerate([(468,248,2),(527,321,1),(703,265,2),(839,387,1),(1014,239,1),(1177,330,2),(1334,257,1),(1451,402,2),(930,299,1)]):
        b.append(f'<circle cx="{sx}" cy="{sy}" r="{r}" fill="#b2e8ff" opacity="{.35 + (i%3)*.18}"/>')
    b += [
        '<path d="M 1315 246 C 1378 232 1434 281 1422 340 C 1413 389 1357 406 1328 367 C 1298 328 1339 303 1364 325" fill="none" stroke="#7f2a69" stroke-width="16" opacity=".34"/>',
        '<ellipse cx="1380" cy="330" rx="178" ry="138" fill="url(#magentaGlow)"/>',
        '<path d="M 0 527 L 282 507 L 391 590 H 1529 L 1642 507 L 1920 532 V 1080 H 0 Z" fill="url(#floor)"/>',
        '<path d="M 365 570 L 1555 570 L 1846 1080 H 74 Z" fill="#0b121a"/>',
        '<path d="M 365 570 L 1555 570 L 1846 1080 H 74 Z" fill="url(#grid)" opacity=".65"/>',
        '<path d="M 960 570 V 1080 M 690 570 L 520 1080 M 1230 570 L 1400 1080" stroke="#30566c" stroke-width="3" opacity=".45"/>',
        '<path d="M 126 706 H 1794 M 76 844 H 1844" stroke="#31566d" stroke-width="4" opacity=".35"/>',
        '<path d="M 0 658 L 265 572 L 383 636 L 189 781 L 0 823 Z" fill="#0b131c" stroke="#1e3a52" stroke-width="4"/>',
        '<path d="M 1920 658 L 1655 572 L 1537 636 L 1731 781 L 1920 823 Z" fill="#0b131c" stroke="#1e3a52" stroke-width="4"/>',
        '<path d="M 0 39 L 401 580 L 574 580 L 227 0 Z" fill="url(#light)"/>',
        '<ellipse cx="237" cy="596" rx="198" ry="160" fill="url(#amberGlow)" opacity=".65"/>',
    ]
    # Door/machinery and rails.
    for x in [60, 1780]:
        b += [
            f'<rect x="{x}" y="163" width="80" height="400" fill="#0b121a" stroke="#2b536e" stroke-width="5"/>',
            f'<path d="M {x+18} 190 H {x+62} V 525 H {x+18} Z" fill="#121e28"/>',
            f'<path d="M {x+26} 218 H {x+54} M {x+26} 258 H {x+54} M {x+26} 480 H {x+54}" stroke="#e8a830" stroke-width="6" opacity=".55"/>',
        ]
    b += [
        '<path d="M 118 617 H 351 M 1569 617 H 1802" stroke="#31546b" stroke-width="13"/>',
        '<path d="M 150 615 V 730 M 307 615 V 682 M 1613 615 V 685 M 1766 615 V 731" stroke="#31546b" stroke-width="10"/>',
        '<path d="M 149 622 H 353 M 1567 622 H 1768" stroke="#6bc7ff" stroke-width="2" opacity=".38"/>',
    ]
    # Characters in the physical stage.
    b.append(draw_human(474, 718, .82, female=False))
    b.append(draw_human(328, 666, .65, female=True))
    b.append(draw_monster(1320, 724, .86, 0))
    b.append(draw_monster(1558, 678, .64, 1))
    # World anchored health + intent.
    for x, y, hpw, accent in [(1177, 508, 205, "red"), (1460, 498, 172, "amber")]:
        b += [
            f'<path d="M {x} {y} H {x+hpw} L {x+hpw+12} {y+10} L {x+hpw} {y+28} H {x} L {x-12} {y+10} Z" fill="#080c12" fill-opacity=".92" stroke="#2b536e" stroke-width="2"/>',
            f'<path d="M {x+10} {y+14} H {x+hpw-24}" stroke="#d64440" stroke-width="7"/>',
            f'<circle cx="{x+hpw/2}" cy="{y-6}" r="16" fill="#0a0e14" stroke="{PALETTE[accent]}" stroke-width="3"/>',
            f'<path d="M {x+hpw/2-5} {y-14} L {x+hpw/2+7} {y-2} M {x+hpw/2+2} {y-17} L {x+hpw/2-8} {y+1}" stroke="{PALETTE[accent]}" stroke-width="3"/>',
        ]
    # Thin top status rail.
    b += [
        '<path d="M 40 30 H 504 L 527 53 H 1393 L 1416 30 H 1880" fill="none" stroke="#1e3a52" stroke-width="24" opacity=".92"/>',
        '<path d="M 42 24 H 510 L 532 46 H 1388 L 1410 24 H 1878" fill="none" stroke="#3a82b2" stroke-width="3"/>',
        '<circle cx="82" cy="30" r="7" fill="#6bc7ff"/><circle cx="108" cy="30" r="7" fill="#e8a830"/><circle cx="134" cy="30" r="7" fill="#d64440" opacity=".55"/>',
        label(170, 37, "ARKHAM // 战斗甲板 07", 17, color="muted", tracking=2.4),
        label(1750, 37, "回合 03", 17, color="text", anchor="middle", tracking=2.0),
    ]
    # Top-center meters.
    b += [panel_group(674, 68, 572, 83, accent="cyan", cut=18, fill_opacity=.8)]
    b += [label(705, 101, "回响链", 17, color="muted", tracking=2.5), tick_row(805, 87, 6, 57, color="cyan", active=4, w=42, h=18)]
    b += [label(706, 133, "隔离", 15, color="muted", tracking=2.5)]
    for i in range(10):
        color = "cyan" if i < 5 else ("amber" if i < 8 else "red")
        b.append(f'<rect x="{805+i*40}" y="119" width="31" height="9" fill="{PALETTE[color]}" opacity="{.85 if i<7 else .25}"/>')
    b += ['<path d="M 1124 112 V 137" stroke="#d64440" stroke-width="3"/>']
    # Player HUD, companion HUD.
    b += [panel_group(35, 830, 430, 135, accent="cyan", cut=22, fill_opacity=.87)]
    b += [
        '<circle cx="99" cy="895" r="42" fill="#091622" stroke="#6bc7ff" stroke-width="3"/>',
        '<path d="M 75 924 L 84 891 L 99 904 L 114 879 L 124 924" fill="none" stroke="#6bc7ff" stroke-width="6"/>',
        label(158, 868, "航员状态", 16, color="muted", tracking=2.5),
        '<path d="M 158 892 H 425" stroke="#05080d" stroke-width="20"/><path d="M 158 892 H 363" stroke="#d64440" stroke-width="11"/>',
        '<path d="M 158 928 H 300" stroke="#05080d" stroke-width="15"/><path d="M 158 928 H 260" stroke="#3a82b2" stroke-width="8"/>',
    ]
    for i in range(3):
        col = PALETTE["amber"] if i < 2 else PALETTE["steel"]
        b.append(f'<polygon points="{pts(hex_points(337+i*34, 934, 14, 14))}" fill="{col}" stroke="#ffdc82" stroke-width="2"/>')
    b += [panel_group(47, 739, 298, 72, accent="blue", cut=14, fill_opacity=.84)]
    b += [
        '<circle cx="91" cy="775" r="23" fill="#0b1721" stroke="#3a82b2" stroke-width="2"/>',
        label(126, 765, "宋梅", 18, color="text", tracking=2),
        '<path d="M 127 784 H 309" stroke="#05080d" stroke-width="13"/><path d="M 127 784 H 278" stroke="#3a82b2" stroke-width="7"/>',
    ]
    # Card tray and cards.
    b += [
        '<path d="M 455 863 L 508 813 H 1412 L 1465 863 L 1502 1080 H 418 Z" fill="#070b11" fill-opacity=".82" stroke="#1e3a52" stroke-width="4"/>',
        '<path d="M 510 831 H 1410" stroke="#6bc7ff" stroke-width="3" opacity=".75"/>',
    ]
    card_colors = ["cyan", "cyan", "amber", "cyan", "red"]
    for i in range(5):
        x = 606 + i * 160
        lift = 28 if i == 2 else 0
        y = 857 - lift + abs(i - 2) * 9
        a = PALETTE[card_colors[i]]
        b += [
            f'<path d="M {x+12} {y} H {x+130} L {x+145} {y+15} V {y+213} L {x+130} {y+228} H {x+12} L {x-3} {y+213} V {y+15} Z" fill="#101720" stroke="{a}" stroke-width="{4 if i==2 else 2}"/>',
            f'<path d="M {x+12} {y+42} H {x+130} V {y+123} H {x+12} Z" fill="#1b2d3a"/>',
            f'<circle cx="{x+25}" cy="{y+24}" r="13" fill="{a}"/><circle cx="{x+72}" cy="{y+82}" r="25" fill="none" stroke="{a}" stroke-width="4" opacity=".75"/>',
            f'<path d="M {x+20} {y+150} H {x+122} M {x+20} {y+170} H {x+109} M {x+20} {y+190} H {x+116}" stroke="#8592a0" stroke-width="5" opacity=".45"/>',
        ]
    # Turn button and counters.
    b += [
        '<path d="M 1560 869 H 1810 L 1872 925 V 967 L 1818 1021 H 1560 L 1512 979 V 920 Z" fill="#100d08" stroke="#72511f" stroke-width="5"/>',
        '<path d="M 1580 889 H 1798 L 1847 934 V 958 L 1808 998 H 1578 L 1538 965 V 930 Z" fill="#e8a830" opacity=".16" stroke="#e8a830" stroke-width="3"/>',
        label(1694, 955, "结束回合", 27, color="gold", anchor="middle", tracking=4),
        '<path d="M 1747 970 H 1798 L 1811 957" fill="none" stroke="#ffdc82" stroke-width="4"/>',
        '<path d="M 1537 824 H 1640 L 1655 839 L 1640 854 H 1537 L 1522 839 Z" fill="#0a0e14" stroke="#3a82b2" stroke-width="2"/>',
        '<path d="M 1695 824 H 1798 L 1813 839 L 1798 854 H 1695 L 1680 839 Z" fill="#0a0e14" stroke="#3a82b2" stroke-width="2"/>',
        label(1589, 845, "牌库 12", 15, color="muted", anchor="middle", tracking=1.5),
        label(1747, 845, "弃牌 04", 15, color="muted", anchor="middle", tracking=1.5),
    ]
    # Final grading / corner trim.
    b += [
        '<rect x="8" y="8" width="1904" height="1064" fill="none" stroke="#1e3a52" stroke-width="4"/>',
        '<path d="M 8 112 V 8 H 112 M 1808 8 H 1912 V 112 M 1912 968 V 1072 H 1808 M 112 1072 H 8 V 968" fill="none" stroke="#6bc7ff" stroke-width="5" opacity=".7"/>',
    ]
    return svg(1920, 1080, "\n".join(b), defs=defs)


def atlas_svg(files: dict[str, str]) -> str:
    # A presentation board built from the same vector language. The game uses the individual transparent SVGs.
    defs = '''<linearGradient id="board" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#101923"/><stop offset="1" stop-color="#05080d"/></linearGradient>
    <pattern id="micro" width="32" height="32" patternUnits="userSpaceOnUse"><path d="M32 0H0V32" fill="none" stroke="#2b536e" stroke-width="1" opacity=".14"/></pattern>'''
    b = [
        '<rect width="2048" height="1536" fill="url(#board)"/><rect width="2048" height="1536" fill="url(#micro)"/>',
        '<path d="M 44 42 H 2004 V 1494 H 44 Z" fill="none" stroke="#1e3a52" stroke-width="4"/>',
        '<path d="M 44 145 V 42 H 155 M 1893 42 H 2004 V 145" fill="none" stroke="#6bc7ff" stroke-width="6"/>',
        label(92, 103, "ARKHAM // 2.5D 战斗 HUD 组件", 34, color="text", tracking=4),
        label(92, 137, "INDUSTRIAL SHIP SYSTEMS / UI ASSET KIT 01", 14, color="muted", tracking=3),
        label(1952, 104, "1920 × 1080", 16, color="cyan", anchor="end", tracking=2),
    ]
    # We re-draw key assets at atlas coordinates to keep the output standalone and easy to preview.
    # Row 1.
    b += [f'<g transform="translate(90 210)">{vital_frame().split("<defs></defs>")[1].split("</svg>")[0]}</g>']
    b += [f'<g transform="translate(670 210)">{combo_meter().split("<defs></defs>")[1].split("</svg>")[0]}</g>']
    b += [f'<g transform="translate(1120 210)">{isolation_meter().split("<defs></defs>")[1].split("</svg>")[0]}</g>']
    b += [f'<g transform="translate(1585 218)">{end_turn_button().split("<defs></defs>")[1].split("</svg>")[0]}</g>']
    b += [label(90, 394, "PLAYER VITALS / COMPACT", 14, color="muted", tracking=2), label(670, 394, "ECHO CHAIN", 14, color="muted", tracking=2), label(1120, 394, "ISOLATION", 14, color="muted", tracking=2), label(1585, 394, "END TURN", 14, color="muted", tracking=2)]
    # Row 2.
    b += [f'<g transform="translate(90 470)">{companion_frame().split("<defs></defs>")[1].split("</svg>")[0]}</g>']
    b += [f'<g transform="translate(465 485)">{enemy_health_frame().split("<defs></defs>")[1].split("</svg>")[0]}</g>']
    kinds = ["attack", "shield", "debuff", "unknown"]
    for i, kind in enumerate(kinds):
        raw = intent_icon(kind).split("<defs></defs>")[1].split("</svg>")[0]
        b.append(f'<g transform="translate({870+i*132} 455)">{raw}</g>')
    b += [f'<g transform="translate(1450 468)">{settings_hex().split("<defs></defs>")[1].split("</svg>")[0]}</g>']
    b += [f'<g transform="translate(1580 462)">{condition_pips().split("<defs></defs>")[1].split("</svg>")[0]}</g>']
    b += [label(90, 593, "COMPANION", 14, color="muted", tracking=2), label(465, 593, "WORLD-ANCHORED ENEMY", 14, color="muted", tracking=2), label(870, 593, "INTENTS", 14, color="muted", tracking=2), label(1450, 593, "SYSTEM", 14, color="muted", tracking=2), label(1580, 593, "CONDITION PIPS", 14, color="muted", tracking=2)]
    # Row 3: tray and card brackets.
    raw_tray = card_tray().split("<defs></defs>")[1].split("</svg>")[0]
    raw_br = card_brackets().split("<defs></defs>")[1].split("</svg>")[0]
    b += [f'<g transform="translate(88 690) scale(1.36)">{raw_tray}</g>', f'<g transform="translate(1632 644) scale(.82)">{raw_br}</g>']
    b += [label(90, 1064, "RECESSED CARD TRAY / FIVE REGISTRATION SLOTS", 14, color="muted", tracking=2), label(1632, 951, "CARD FOCUS", 14, color="muted", tracking=2)]
    # Row 4 tooltip and production rules.
    raw_tt = tooltip_frame().split("<defs></defs>")[1].split("</svg>")[0]
    b += [f'<g transform="translate(90 1150)">{raw_tt}</g>']
    b += [
        label(584, 1194, "视觉原则", 24, color="text", tracking=3),
        label(584, 1234, "• 中央 3D 战场保持无遮挡", 18, color="muted", tracking=1),
        label(584, 1268, "• 角色高度控制在画面 14–18%", 18, color="muted", tracking=1),
        label(584, 1302, "• HUD 只使用工程蓝 / 琥珀 / 危险红", 18, color="muted", tracking=1),
        label(584, 1336, "• 怪物有机形态只进入世界，不侵入 UI 框架", 18, color="muted", tracking=1),
        label(584, 1370, "• 敌方意图与血条通过世界坐标投影贴近目标", 18, color="muted", tracking=1),
        '<path d="M 584 1408 H 1912" stroke="#2b536e" stroke-width="2"/>',
        label(584, 1448, "PALETTE", 14, color="muted", tracking=2),
    ]
    swatches = ["ink", "panel", "steel", "blue", "cyan", "ice", "amber", "gold", "red", "magenta"]
    for i, name in enumerate(swatches):
        x = 714 + i * 112
        b.append(f'<path d="M {x} 1424 H {x+82} L {x+94} 1436 L {x+82} 1460 H {x} L {x-10} 1448 V 1436 Z" fill="{PALETTE[name]}" stroke="#314c5f" stroke-width="2"/>')
    return svg(2048, 1536, "\n".join(b), defs=defs)


def write_all() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    assets = {
        "player_vitals_frame.svg": vital_frame(),
        "companion_status_frame.svg": companion_frame(),
        "enemy_health_frame.svg": enemy_health_frame(),
        "end_turn_button.svg": end_turn_button(),
        "combo_echo_meter.svg": combo_meter(),
        "isolation_meter.svg": isolation_meter(),
        "card_tray.svg": card_tray(),
        "tooltip_frame.svg": tooltip_frame(),
        "intent_attack.svg": intent_icon("attack"),
        "intent_shield.svg": intent_icon("shield"),
        "intent_debuff.svg": intent_icon("debuff"),
        "intent_unknown.svg": intent_icon("unknown"),
        "condition_pips.svg": condition_pips(),
        "selected_card_brackets.svg": card_brackets(),
        "settings_hex.svg": settings_hex(),
    }
    for name, content in assets.items():
        (OUT / name).write_text(content, encoding="utf-8")
    (OUT / "battle_ui_concept.svg").write_text(concept_svg(), encoding="utf-8")
    (OUT / "ui_component_atlas.svg").write_text(atlas_svg(assets), encoding="utf-8")


if __name__ == "__main__":
    write_all()
