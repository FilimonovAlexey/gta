"""Фоны из art_source/backgrounds → assets/backgrounds (этап 6.0).

Запуск: python3 tools/process_backgrounds.py [уровень ...]   (без аргументов — все уровни и общие картинки)
Нужны Pillow и numpy. Оригиналы в art_source не меняются, результат перезаписывается.

Что делает с каждым файлом art_source/backgrounds/<уровень>/:
- sky, far, mid, main_a/b/c — слои: масштаб по высоте до 720 px; если настоящей альфы нет, а фон
  однотонный ключевой (пурпурный #FF00FF или зелёный #00FF00, определяется по краям) — ключ → прозрачность
  (imgutil.chroma_key: HSV с допуском, мягкий край 1–2 px, despill); почти непрозрачная альфа (генератор любит 252–253) дотягивается до 255;
  если левый и правый края заметно различаются — шов сглаживается переходом на SEAM_WIDTH px
  (ширина уменьшается на SEAM_WIDTH, картинка повторяется без стыка).
- main_b/c выравниваются по высоте пола main_a (линия пола ищется снизу вверх по резкой смене цвета),
  чтобы при чередовании вариантов пол не прыгал. Найденную линию пола скрипт печатает — от неё
  считается walk_top уровня.
- arena — непрозрачный кадр: масштаб «с обрезкой» до 1280x720.
- props.png — лист из 6 предметов декора: ключ → альфа, поиск фигур по альфе (imgutil.find_figures), каждый — props_01..06.png,
  обрезан по фигуре (точка опоры — низ по центру картинки). Порядок — по строкам слева направо.
Общие: art_source/backgrounds/title.png → assets/backgrounds/title.png (1280x720),
art_source/backgrounds/breakables.png → assets/backgrounds/breakables/<имя>.png (порядок BREAKABLE_NAMES).
"""
import json
import os
import sys

import numpy as np

from imgutil import (chroma_key, detect_key, extract, find_figures, has_real_alpha, load, normalize_alpha,
                     resize, save)

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.join(ROOT, "art_source", "backgrounds")
DST = os.path.join(ROOT, "assets", "backgrounds")

SCREEN_W, SCREEN_H = 1280, 720
LAYER_NAMES = ["sky", "far", "mid", "main_a", "main_b", "main_c"]
MAIN_VARIANTS = ["main_a", "main_b", "main_c"]
SEAM_WIDTH = 64
## Средняя разница цвета краёв (0..255), выше которой шов сглаживается.
SEAM_THRESHOLD = 10.0
BREAKABLE_NAMES = ["trash_can", "trash_can_broken", "crate", "crate_broken", "hotdog", "cash"]
## Самый высокий из разрушаемых предметов после масштаба, px (в игре спрайт ещё подгоняется под body_size).
BREAKABLE_MAX_HEIGHT = 160
## Предметы декора: масштаб относительно высоты листа (лист 3x2 высотой H → H px = 720).
PROPS_SHEET_TO_SCREEN = 1.0


# --- Общие операции (остальное — в imgutil) -------------------------------------

def prepare(a: np.ndarray, name: str) -> np.ndarray:
    """Альфа: настоящая — нормализовать, иначе ключ (если найден)."""
    if has_real_alpha(a):
        return normalize_alpha(a)
    key = detect_key(a)
    if key is not None:
        print(f"    {name}: ключ {key} → прозрачность")
        return chroma_key(a, key)
    a = a.copy()
    a[..., 3] = 255
    return a


def scale_to_height(a: np.ndarray, h: int = SCREEN_H) -> np.ndarray:
    k = h / a.shape[0]
    return resize(a, max(1, round(a.shape[1] * k)), h)


def cover(a: np.ndarray, w: int = SCREEN_W, h: int = SCREEN_H) -> np.ndarray:
    k = max(w / a.shape[1], h / a.shape[0])
    a = resize(a, round(a.shape[1] * k), round(a.shape[0] * k))
    x0 = (a.shape[1] - w) // 2
    y0 = (a.shape[0] - h) // 2
    return a[y0:y0 + h, x0:x0 + w]


def edge_difference(a: np.ndarray) -> float:
    left = a[:, :4].mean(1)
    right = a[:, -4:].mean(1)
    return float(np.abs(left - right).mean())


def smooth_seam(a: np.ndarray, width: int = SEAM_WIDTH) -> np.ndarray:
    """Правые width px плавно переходят в левые width px; левые отрезаются — повтор без шва."""
    w = a.shape[1]
    t = np.linspace(0.0, 1.0, width + 2, dtype=np.float32)[1:-1][None, :, None]
    blend = a[:, w - width:] * (1.0 - t) + a[:, :width] * t
    return np.concatenate([a[:, width:w - width], blend], axis=1)


def floor_line(a: np.ndarray) -> int | None:
    """Верхняя строка пола: снизу вверх, пока средний цвет строки близок к цвету нижней четверти."""
    h = a.shape[0]
    rows = a[..., :3].mean(1)
    ref = np.median(rows[int(h * 0.8):], axis=0)
    for y in range(int(h * 0.8), int(h * 0.3), -1):
        if np.abs(rows[y] - ref).mean() > 20.0:
            return y + 1
    return None


def shift_vertical(a: np.ndarray, dy: int) -> np.ndarray:
    """Сдвиг по y: dy < 0 — вверх (низ дополняется повтором нижней строки), dy > 0 — вниз (верх — прозрачный)."""
    if dy == 0:
        return a
    out = np.empty_like(a)
    if dy < 0:
        out[:dy] = a[-dy:]
        out[dy:] = a[-1:]
    else:
        out[dy:] = a[:-dy]
        out[:dy] = 0
    return out


# --- Нарезка листа ------------------------------------------------------------------

def cut_figures(a: np.ndarray, names: list[str], out_dir: str, scale: float, pad: int = 2) -> None:
    figures = find_figures(a[..., 3], len(names), rows=2, name=out_dir, strict=False)
    for fig, name in zip(figures, names):
        crop = extract(a, fig)
        crop = resize(crop, max(1, round(crop.shape[1] * scale)), max(1, round(crop.shape[0] * scale)))
        # Прозрачные поля по бокам и сверху; низ картинки = низ фигуры (точка опоры — низ по центру).
        out = np.zeros((crop.shape[0] + pad, crop.shape[1] + pad * 2, 4), np.float32)
        out[pad:, pad:pad + crop.shape[1]] = crop
        save(out, os.path.join(out_dir, name + ".png"))
        print(f"    {name}.png  {out.shape[1]}x{out.shape[0]}")


# --- Уровень и общие картинки ----------------------------------------------------

def process_level(level: str) -> dict:
    src_dir = os.path.join(SRC, level)
    dst_dir = os.path.join(DST, level)
    info: dict = {"level": level}
    print(f"[{level}]")
    floor_ref = None
    for name in LAYER_NAMES:
        path = os.path.join(src_dir, name + ".png")
        if not os.path.exists(path):
            continue
        a = scale_to_height(prepare(load(path), name))
        if name in MAIN_VARIANTS:
            line = floor_line(a)
            if floor_ref is None:
                floor_ref = line
                info["floor_line"] = line
            elif line is not None and floor_ref is not None and line != floor_ref:
                a = shift_vertical(a, floor_ref - line)
                print(f"    {name}: пол {line} → {floor_ref} (сдвиг {floor_ref - line:+d})")
        diff = edge_difference(a)
        if diff > SEAM_THRESHOLD:
            a = smooth_seam(a)
            print(f"    {name}: края различаются ({diff:.1f}) — шов сглажен")
        save(a, os.path.join(dst_dir, name + ".png"))
        print(f"    {name}.png  {a.shape[1]}x{a.shape[0]}  края {diff:.1f}")
    arena = os.path.join(src_dir, "arena.png")
    if os.path.exists(arena):
        a = cover(prepare(load(arena), "arena"))
        a[..., 3] = 255
        save(a, os.path.join(dst_dir, "arena.png"))
        print("    arena.png  1280x720")
    props = os.path.join(src_dir, "props.png")
    if os.path.exists(props):
        a = prepare(load(props), "props")
        scale = SCREEN_H / a.shape[0] * PROPS_SHEET_TO_SCREEN
        cut_figures(a, [f"props_{i:02d}" for i in range(1, 7)], dst_dir, scale)
    if "floor_line" in info:
        print(f"    линия пола (по main_a): y = {info['floor_line']}")
    return info


def process_common() -> None:
    title = os.path.join(SRC, "title.png")
    if os.path.exists(title):
        a = cover(prepare(load(title), "title"))
        a[..., 3] = 255
        save(a, os.path.join(DST, "title.png"))
        print("[title] title.png  1280x720")
    sheet = os.path.join(SRC, "breakables.png")
    if os.path.exists(sheet):
        print("[breakables]")
        a = prepare(load(sheet), "breakables")
        figures = find_figures(a[..., 3], len(BREAKABLE_NAMES), rows=2, name="breakables.png", strict=False)
        tallest = max(f.height for f in figures[:4])
        cut_figures(a, BREAKABLE_NAMES, os.path.join(DST, "breakables"), BREAKABLE_MAX_HEIGHT / tallest)


def main() -> None:
    wanted = sys.argv[1:]
    levels = sorted(d for d in os.listdir(SRC) if os.path.isdir(os.path.join(SRC, d)) and not d.startswith((".", "_")))
    if wanted:
        levels = [lv for lv in levels if lv in wanted]
    report = [process_level(lv) for lv in levels]
    if not wanted:
        process_common()
    with open(os.path.join(ROOT, "tools", "floor_lines.json"), "w", encoding="utf-8") as f:
        json.dump({r["level"]: r.get("floor_line") for r in report}, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
