"""Общие операции с картинками для tools/*.py: загрузка/сохранение, хромакей, поиск фигур по альфе.

Картинки — numpy float32 (H, W, 4), RGBA 0..255. Нужны Pillow и numpy (без scipy).
Пользуются: process_backgrounds.py (фоны), slice_sheets.py (спрайты персонажей).
"""
import os
from collections import deque
from dataclasses import dataclass, field

import numpy as np
from PIL import Image, ImageFilter

KEYS = {"magenta": (255, 0, 255), "green": (0, 255, 0)}


# --- Файлы и масштаб -------------------------------------------------------------

def load(path: str) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA")).astype(np.float32)


def to_image(a: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def save(a: np.ndarray, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    to_image(a).save(path, optimize=True)


def resize(a: np.ndarray, w: int, h: int) -> np.ndarray:
    """LANCZOS через премультипликацию, чтобы прозрачные пиксели не давали тёмную кайму."""
    img = to_image(a).convert("RGBa").resize((max(1, w), max(1, h)), Image.LANCZOS).convert("RGBA")
    return np.array(img).astype(np.float32)


def scale(a: np.ndarray, k: float) -> np.ndarray:
    return resize(a, round(a.shape[1] * k), round(a.shape[0] * k))


# --- Альфа и ключ ------------------------------------------------------------------

def has_real_alpha(a: np.ndarray) -> bool:
    return float((a[..., 3] < 200).mean()) > 0.002


def normalize_alpha(a: np.ndarray) -> np.ndarray:
    """Почти непрозрачная альфа (максимум 240–254) → растянуть до 255."""
    top = float(np.percentile(a[..., 3], 99))
    if 240.0 <= top < 255.0:
        a = a.copy()
        a[..., 3] = np.clip(a[..., 3] * 255.0 / top, 0, 255)
        a[..., 3] = np.where(a[..., 3] > 250, 255, a[..., 3])
    return a


def border_pixels(a: np.ndarray, width: int = 4) -> np.ndarray:
    return np.concatenate([a[:width].reshape(-1, a.shape[2]), a[-width:].reshape(-1, a.shape[2]),
                           a[:, :width].reshape(-1, a.shape[2]), a[:, -width:].reshape(-1, a.shape[2])])


def detect_key(a: np.ndarray) -> str | None:
    """Ключевой цвет по рамке картинки шириной 4 px: magenta, green или None."""
    border = border_pixels(a)
    r, g, b = np.median(border[:, 0]), np.median(border[:, 1]), np.median(border[:, 2])
    if r > 180 and b > 180 and g < 90:
        return "magenta"
    if g > 180 and r < 90 and b < 90:
        return "green"
    return None


def key_strength(a: np.ndarray, key: str) -> np.ndarray:
    """Насколько пиксель «ключевой»: превышение ключевого канала над остальными (0 — нет примеси)."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    if key == "green":
        return g - np.maximum(r, b)
    return np.minimum(r, b) - g


def rgb_to_hsv(a: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Тон в градусах 0..360, насыщенность и яркость 0..1."""
    rgb = a[..., :3] / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    safe = np.where(d > 1e-6, d, 1.0)
    h = np.where(mx == r, ((g - b) / safe) % 6.0, np.where(mx == g, (b - r) / safe + 2.0, (r - g) / safe + 4.0))
    h = np.where(d > 1e-6, h * 60.0, 0.0)
    s = np.where(mx > 1e-6, d / np.where(mx > 1e-6, mx, 1.0), 0.0)
    return h, s, mx


def _min_filter(mask: np.ndarray, size: int) -> np.ndarray:
    img = Image.fromarray(mask.astype(np.uint8) * 255)
    return np.array(img.filter(ImageFilter.MinFilter(size))) > 127


def _max_filter(mask: np.ndarray, size: int) -> np.ndarray:
    img = Image.fromarray(mask.astype(np.uint8) * 255)
    return np.array(img.filter(ImageFilter.MaxFilter(size))) > 127


@dataclass
class KeySettings:
    """Допуски хромакея. Фон — пиксель, у которого тон в пределах hue_tol от ключа,
    насыщенность >= sat_min и яркость >= val_min. edge_px — ширина мягкого края (1–2 px)."""
    hue_tol: float = 30.0
    sat_min: float = 0.30
    val_min: float = 0.25
    edge_px: int = 2


def chroma_key(a: np.ndarray, key: str, settings: KeySettings | None = None) -> np.ndarray:
    """Ключ → альфа.

    1. Фон определяется в HSV с допуском (жёсткая маска).
    2. Мягкий край только в полосе edge_px вокруг контура: альфа там — «распутывание» смеси
       с ключом (сколько ключевого канала в пикселе относительно чистого фона).
    3. Despill в той же полосе: ключевой канал не выше остальных — без зелёной/пурпурной каймы.
    """
    cfg = settings or KeySettings()
    a = a.copy()
    key_rgb = np.array(KEYS[key], np.float32)
    key_h, _, _ = rgb_to_hsv(key_rgb.reshape(1, 1, 3))
    h, s, v = rgb_to_hsv(a)
    dh = np.abs(h - float(key_h[0, 0]))
    dh = np.minimum(dh, 360.0 - dh)
    background = (dh <= cfg.hue_tol) & (s >= cfg.sat_min) & (v >= cfg.val_min)
    fg = ~background
    # Полоса края: снаружи — до 1 px за контуром, внутри — до edge_px от фона.
    outer = _max_filter(fg, 3)
    inner = _min_filter(fg, 2 * cfg.edge_px + 1)
    band = outer & ~inner
    strength = key_strength(a, key)
    pure = float(np.median(strength[background])) if background.any() else 255.0
    unmixed = 1.0 - np.clip(strength / max(pure, 1.0), 0.0, 1.0)
    alpha = np.where(inner, 1.0, np.where(band, unmixed, 0.0))
    # Пиксель, признанный фигурой, не должен стать совсем прозрачным, и наоборот.
    alpha = np.where(band & fg, np.maximum(alpha, 0.35), alpha)
    alpha = np.where(band & ~fg, np.minimum(alpha, 0.65), alpha)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    if key == "green":
        a[..., 1] = np.where(band, np.minimum(g, np.maximum(r, b)), g)
    else:
        spill = np.clip(np.minimum(r, b) - g, 0, None)
        a[..., 0] = np.where(band, r - spill, r)
        a[..., 2] = np.where(band, b - spill, b)
    a[..., 3] = alpha * 255.0
    return a


# --- Поиск фигур ----------------------------------------------------------------------

@dataclass
class Figure:
    """Фигура на листе: рамка (x0, y0, x1, y1) в пикселях листа и маска своих пикселей."""
    box: tuple[int, int, int, int]
    mask: np.ndarray            # bool (y1-y0, x1-x0): какие пиксели рамки принадлежат фигуре
    area: int
    pieces: int = 1             # сколько связных кусков склеено
    touches_edge: bool = False  # фигура касается края листа (вероятно, обрезана)
    notes: list[str] = field(default_factory=list)

    @property
    def width(self) -> int:
        return self.box[2] - self.box[0]

    @property
    def height(self) -> int:
        return self.box[3] - self.box[1]


class FigureCountError(Exception):
    pass


def label_components(mask: np.ndarray) -> tuple[np.ndarray, int]:
    """Связные области (8-связность). Возвращает карту меток (0 — фон) и число областей."""
    h, w = mask.shape
    labels = np.zeros((h, w), np.int32)
    count = 0
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if labels[y0, x0]:
            continue
        count += 1
        labels[y0, x0] = count
        q = deque([(y0, x0)])
        while q:
            cy, cx = q.popleft()
            for ny in (cy - 1, cy, cy + 1):
                if ny < 0 or ny >= h:
                    continue
                for nx in (cx - 1, cx, cx + 1):
                    if 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
                        labels[ny, nx] = count
                        q.append((ny, nx))
    return labels, count


def _box_distance(a: tuple, b: tuple) -> float:
    dx = max(0, max(a[0], b[0]) - min(a[2], b[2]))
    dy = max(0, max(a[1], b[1]) - min(a[3], b[3]))
    return float(np.hypot(dx, dy))


def find_figures(alpha: np.ndarray, count: int, rows: int = 1, name: str = "",
                 strict: bool = True, step: int = 2, threshold: float = 10.0,
                 small_fraction: float = 0.08, attach_distance: float = 160.0,
                 dust_area: int = 60) -> list[Figure]:
    """Фигуры по связным областям альфы, а не по сетке.

    - Области ищутся на сетке с шагом step (блок step x step занят, если в нём есть пиксель альфы > threshold).
    - Мелкие куски (площадь < small_fraction медианной площади count крупнейших: волосы, отлетевшая кепка)
      приклеиваются к ближайшей крупной фигуре, если до неё не дальше attach_distance px; пыль — выбрасывается.
    - Порядок: по строкам (rows штук, сверху вниз), внутри строки — по x.
    - Если крупных фигур не count: strict — FigureCountError с именем файла, иначе берутся count крупнейших.
    """
    h, w = alpha.shape
    sh, sw = (h + step - 1) // step, (w + step - 1) // step
    padded = np.zeros((sh * step, sw * step), bool)
    padded[:h, :w] = alpha > threshold
    small = padded.reshape(sh, step, sw, step).any(axis=(1, 3))
    labels, n = label_components(small)
    if n == 0:
        raise FigureCountError(f"{name}: на листе не найдено ни одной фигуры")
    areas = np.bincount(labels.ravel(), minlength=n + 1)[1:] * step * step
    boxes = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero(labels == i)
        boxes.append((xs.min() * step, ys.min() * step, min(w, (xs.max() + 1) * step), min(h, (ys.max() + 1) * step)))
    order = np.argsort(-areas)
    top = areas[order[:count]]
    big_limit = small_fraction * float(np.median(top))
    big = [int(i) for i in order if areas[i] >= big_limit]
    groups: dict[int, list[int]] = {i: [i] for i in big}
    dropped = 0
    for i in order:
        i = int(i)
        if i in groups:
            continue
        if areas[i] < dust_area:
            dropped += 1
            continue
        dist, nearest = min((_box_distance(boxes[i], boxes[j]), j) for j in big)
        if dist <= attach_distance:
            groups[nearest].append(i)
        else:
            dropped += 1
    if len(big) != count:
        msg = f"{name}: найдено фигур {len(big)}, ожидалось {count} (площади: " + \
              ", ".join(str(int(areas[i])) for i in big[:count + 3]) + ")"
        if strict:
            raise FigureCountError(msg)
        print(f"    внимание: {msg}")
        big = big[:count]
    full_labels = np.repeat(np.repeat(labels, step, 0), step, 1)[:h, :w]
    figures = []
    for i in big:
        member = np.isin(full_labels, np.array(groups[i]) + 1) & (alpha > 0)
        ys = np.nonzero(member.any(1))[0]
        xs = np.nonzero(member.any(0))[0]
        x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
        fig = Figure((x0, y0, x1, y1), member[y0:y1, x0:x1], int(member.sum()), len(groups[i]))
        fig.touches_edge = x0 <= 1 or y0 <= 1 or x1 >= w - 1 or y1 >= h - 1
        figures.append(fig)
    if dropped:
        figures[0].notes.append(f"выброшено мелких кусков: {dropped}")
    # По строкам: сортировка по центру y, деление на rows равных групп, внутри — по x.
    figures.sort(key=lambda f: (f.box[1] + f.box[3]) / 2)
    per_row = max(1, len(figures) // max(1, rows))
    ordered = []
    for r in range(0, len(figures), per_row):
        ordered.extend(sorted(figures[r:r + per_row], key=lambda f: (f.box[0] + f.box[2]) / 2))
    return ordered


def extract(a: np.ndarray, fig: Figure) -> np.ndarray:
    """Пиксели фигуры (чужие пиксели в её рамке — прозрачные)."""
    x0, y0, x1, y1 = fig.box
    crop = a[y0:y1, x0:x1].copy()
    crop[..., 3] *= fig.mask
    return crop
