"""Нарезка листов персонажей в кадры анимаций и SpriteFrames (этап 6.1).

Запуск: python3 tools/slice_sheets.py [персонаж ...] [--no-godot]
        (без персонажей — все из art_source/animations.json). Нужны Pillow и numpy.

Вход: art_source/<персонаж>/<лист>.png — 1536x1024, сетка 3x2 (кадры 1..6 слева направо, сверху вниз),
фон — сплошной зелёный, персонаж смотрит вправо. Конфиг — art_source/animations.json.

Что делает:
1. Хромакей (imgutil.chroma_key): фон в HSV с допуском, мягкий край 1–2 px, despill.
2. Фигуры — по связным областям альфы (imgutil.find_figures), не по сетке: мелкие куски приклеиваются
   к ближайшей фигуре; порядок — по строкам, затем по x. Не шесть фигур — ошибка с именем файла
   (лист пропускается, скрипт завершится с кодом 1).
3. Выравнивание: один масштаб на персонажа (target_height / средняя высота фигур листа стойки);
   низ фигуры — на базовой линии кадра; по x опора — центр торса (медиана центров масс строк в полосе
   torso_band высоты фигуры), а не центр рамки; ручная поправка — offsets в конфиге.
4. Выход: assets/sprites/<персонаж>/<анимация>_<NN>.png (старые png персонажа удаляются)
   и assets/sprites/<персонаж>/<персонаж>.tres (SpriteFrames — собирает Godot headless:
   tools/build_sprite_frames.gd; пропустить — --no-godot).
5. Контроль: tools/preview/<персонаж>_sheet.png (все кадры, красная базовая линия, синяя ось опоры,
   подозрительные — в оранжевой рамке), tools/preview/<персонаж>_<анимация>.gif,
   отчёт — в консоль и tools/preview/slice_report.txt.
Отсутствующие листы пропускаются с предупреждением.
"""
import json
import os
import subprocess
import sys
from dataclasses import dataclass, field

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from imgutil import FigureCountError, chroma_key, detect_key, extract, find_figures, load, resize, save, to_image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ART = os.path.join(ROOT, "art_source")
CONFIG = os.path.join(ART, "animations.json")
OUT = os.path.join(ROOT, "assets", "sprites")
PREVIEW = os.path.join(ROOT, "tools", "preview")
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
SHEET_COLS, SHEET_ROWS = 3, 2
FIGURES_PER_SHEET = SHEET_COLS * SHEET_ROWS
## Масштаб превью-сетки и GIF относительно кадра.
PREVIEW_SCALE = 0.5


@dataclass
class SourceFrame:
    """Фигура с листа: пиксели (обрезаны по рамке) и замеры в пикселях листа."""
    sheet: str
    index: int                  # 1..6
    pixels: np.ndarray
    height: int                 # высота по альфе > 50%
    bottom: float               # нижняя строка фигуры относительно рамки
    torso_x: float              # опора по x относительно рамки
    touches_edge: bool
    pieces: int


@dataclass
class OutFrame:
    anim: str
    number: int                 # 1..N в анимации
    source: SourceFrame
    image: np.ndarray
    issues: list[str] = field(default_factory=list)


def figure_metrics(pixels: np.ndarray, band: tuple[float, float]) -> tuple[int, float, float]:
    """Высота, нижняя строка (+1) и опора по x: медиана центров масс строк в полосе band высоты фигуры."""
    alpha = pixels[..., 3] / 255.0
    solid = alpha > 0.5
    rows = np.nonzero(solid.any(1))[0]
    top, bottom = int(rows.min()), int(rows.max()) + 1
    height = bottom - top
    y0 = top + int(round(height * band[0]))
    y1 = max(y0 + 1, top + int(round(height * band[1])))
    xs = np.arange(pixels.shape[1], dtype=np.float32)
    centers = []
    for y in range(y0, y1):
        w = alpha[y]
        total = float(w.sum())
        if total > 1.0:
            centers.append(float((w * xs).sum()) / total)
    torso_x = float(np.median(centers)) if centers else pixels.shape[1] / 2.0
    return height, float(bottom), torso_x


def preview_font() -> ImageFont.ImageFont:
    for path in ("/System/Library/Fonts/Supplemental/Arial.ttf", "/Library/Fonts/Arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(path, 13)
        except OSError:
            pass
    return ImageFont.load_default()


class CharacterJob:
    def __init__(self, name: str, cfg: dict, defaults: dict):
        self.name = name
        self.cfg = {**defaults, **cfg}
        self.src_dir = os.path.join(ART, name)
        self.out_dir = os.path.join(OUT, name)
        self.frame_w, self.frame_h = self.cfg["frame_size"]
        self.pivot = (self.frame_w // 2, self.frame_h - int(self.cfg["baseline_margin"]))
        self.sheets: dict[str, list[SourceFrame]] = {}
        self.report: list[str] = []
        self.errors = 0
        self.scale = 0.0
        self.ref_height = 0.0
        self.frames: list[OutFrame] = []
        self.animations: list[dict] = []

    def log(self, line: str) -> None:
        self.report.append(line)
        print(line)

    def sheet_path(self, sheet: str) -> str | None:
        for ext in (".png", ".jpg", ".jpeg", ".webp"):
            p = os.path.join(self.src_dir, sheet + ext)
            if os.path.exists(p):
                return p
        return None

    def load_sheet(self, sheet: str) -> list[SourceFrame] | None:
        if sheet in self.sheets:
            return self.sheets[sheet]
        path = self.sheet_path(sheet)
        if path is None:
            self.sheets[sheet] = None
            return None
        rel = os.path.relpath(path, ROOT)
        a = load(path)
        key = detect_key(a) or self.cfg["key"]
        a = chroma_key(a, key)
        try:
            figures = find_figures(a[..., 3], FIGURES_PER_SHEET, rows=SHEET_ROWS, name=rel)
        except FigureCountError as e:
            self.log(f"  ОШИБКА {e}")
            self.errors += 1
            self.sheets[sheet] = None
            return None
        result = []
        for i, fig in enumerate(figures, 1):
            px = extract(a, fig)
            h, bottom, tx = figure_metrics(px, tuple(self.cfg["torso_band"]))
            result.append(SourceFrame(sheet, i, px, h, bottom, tx, fig.touches_edge, fig.pieces))
        notes = [n for f in figures for n in f.notes]
        heights = ", ".join(str(f.height) for f in result)
        glued = sum(f.pieces - 1 for f in result)
        extra = (f"; приклеено кусков: {glued}" if glued else "") + (f"; {'; '.join(notes)}" if notes else "")
        self.log(f"  {rel}: фигур {len(figures)}, высоты {heights} (ключ {key}){extra}")
        self.sheets[sheet] = result
        return result

    def compute_scale(self) -> bool:
        for sheet in (self.cfg["scale_sheet"], self.cfg.get("scale_fallback")):
            if not sheet:
                continue
            frames = self.load_sheet(sheet)
            if frames:
                self.ref_height = float(np.mean([f.height for f in frames]))
                self.scale = self.cfg["target_height"] / self.ref_height
                note = "" if sheet == self.cfg["scale_sheet"] else \
                    f" — ВНИМАНИЕ: нет листа стойки {self.cfg['scale_sheet']}, масштаб по {sheet}"
                self.log(f"  масштаб {self.scale:.4f}: средняя высота {self.ref_height:.1f} px на {sheet}"
                         f" → {self.cfg['target_height']} px{note}")
                return True
        self.log(f"  ОШИБКА: нет листа для масштаба ({self.cfg['scale_sheet']}"
                 f"{' / ' + self.cfg['scale_fallback'] if self.cfg.get('scale_fallback') else ''}) — персонаж пропущен")
        self.errors += 1
        return False

    def render(self, src: SourceFrame, issues: list[str]) -> np.ndarray:
        k = self.scale
        img = resize(src.pixels, round(src.pixels.shape[1] * k), round(src.pixels.shape[0] * k))
        dx, dy = self.cfg["offsets"].get(f"{src.sheet}:{src.index}", (0, 0))
        x = int(round(self.pivot[0] - src.torso_x * img.shape[1] / src.pixels.shape[1])) + int(dx)
        y = int(round(self.pivot[1] - src.bottom * img.shape[0] / src.pixels.shape[0])) + int(dy)
        frame = np.zeros((self.frame_h, self.frame_w, 4), np.float32)
        fx0, fy0 = max(0, x), max(0, y)
        fx1, fy1 = min(self.frame_w, x + img.shape[1]), min(self.frame_h, y + img.shape[0])
        frame[fy0:fy1, fx0:fx1] = img[fy0 - y:fy1 - y, fx0 - x:fx1 - x]
        lost = img[..., 3].sum() - frame[..., 3].sum()
        if lost > 255.0 * 20:
            sides = [s for s, cut in (("слева", x < 0), ("сверху", y < 0), ("справа", x + img.shape[1] > self.frame_w),
                                      ("снизу", y + img.shape[0] > self.frame_h)) if cut]
            issues.append(f"не влезает в кадр {self.frame_w}x{self.frame_h} ({', '.join(sides)})")
        return frame

    def run(self) -> None:
        self.log(f"[{self.name}]")
        if not os.path.isdir(self.src_dir):
            self.log(f"  внимание: нет папки {os.path.relpath(self.src_dir, ROOT)} — пропуск")
            return
        if not self.compute_scale():
            return
        tol = float(self.cfg["height_tolerance"])
        missing = []
        for anim in self.cfg["animations"]:
            frames = self.load_sheet(anim["sheet"])
            if frames is None:
                if anim["sheet"] not in missing and self.sheet_path(anim["sheet"]) is None:
                    missing.append(anim["sheet"])
                continue
            out = []
            for n, idx in enumerate(anim["frames"], 1):
                src = frames[idx - 1]
                issues: list[str] = []
                ratio = src.height / self.ref_height
                if not anim.get("free_height") and abs(ratio - 1.0) > tol:
                    issues.append(f"высота {ratio:.0%} от стойки")
                if src.touches_edge:
                    issues.append("фигура касается края холста (обрезана?)")
                image = self.render(src, issues)
                out.append(OutFrame(anim["name"], n, src, image, issues))
            self.frames.extend(out)
            self.animations.append({
                "name": anim["name"],
                "fps": float(anim.get("fps", self.cfg["fps"])),
                "loop": bool(anim.get("loop", self.cfg["loop"])),
                "frames": [f"res://assets/sprites/{self.name}/{f.anim}_{f.number:02d}.png" for f in out],
                "sources": [f"{f.source.sheet}:{f.source.index}" for f in out],
            })
        for sheet in missing:
            names = [a["name"] for a in self.cfg["animations"] if a["sheet"] == sheet]
            self.log(f"  внимание: нет листа {sheet} — пропущены анимации: {', '.join(names)}")
        self.write_frames()
        self.write_previews()
        suspicious = [f for f in self.frames if f.issues]
        self.log(f"  анимаций {len(self.animations)}, кадров {len(self.frames)}, подозрительных {len(suspicious)}")
        for f in suspicious:
            self.log(f"    ? {f.anim}_{f.number:02d} ({f.source.sheet}:{f.source.index}): {'; '.join(f.issues)}")

    def write_frames(self) -> None:
        os.makedirs(self.out_dir, exist_ok=True)
        for fn in os.listdir(self.out_dir):
            if fn.endswith(".png") or fn.endswith(".png.import"):
                os.remove(os.path.join(self.out_dir, fn))
        for f in self.frames:
            save(f.image, os.path.join(self.out_dir, f"{f.anim}_{f.number:02d}.png"))

    def write_previews(self) -> None:
        if not self.frames:
            return
        cw, ch = round(self.frame_w * PREVIEW_SCALE), round(self.frame_h * PREVIEW_SCALE)
        px, py = round(self.pivot[0] * PREVIEW_SCALE), round(self.pivot[1] * PREVIEW_SCALE)
        font = preview_font()
        cols = max(len(a["frames"]) for a in self.animations)
        label_h = 18
        grid = Image.new("RGB", (cols * cw, len(self.animations) * (ch + label_h)), (40, 40, 48))
        draw = ImageDraw.Draw(grid)
        by_anim: dict[str, list[OutFrame]] = {}
        for f in self.frames:
            by_anim.setdefault(f.anim, []).append(f)
        for r, anim in enumerate(self.animations):
            gif_frames = []
            for c, f in enumerate(by_anim[anim["name"]]):
                cell = self.preview_cell(f, cw, ch, px, py)
                ox, oy = c * cw, r * (ch + label_h)
                grid.paste(cell, (ox, oy + label_h))
                color = (255, 150, 0) if f.issues else (200, 200, 200)
                draw.text((ox + 4, oy + 2), f"{anim['name']}_{f.number:02d}  {f.source.sheet}:{f.source.index}",
                          fill=color, font=font)
                if f.issues:
                    draw.rectangle((ox, oy + label_h, ox + cw - 1, oy + label_h + ch - 1), outline=(255, 150, 0), width=3)
                gif_frames.append(cell)
            ms = int(round(1000.0 / anim["fps"]))
            durations = [ms] * len(gif_frames)
            if not anim["loop"]:
                durations[-1] = ms + 500
            gif = [g.quantize(colors=255, method=Image.Quantize.MEDIANCUT) for g in gif_frames]
            gif[0].save(os.path.join(PREVIEW, f"{self.name}_{anim['name']}.gif"), save_all=True,
                        append_images=gif[1:], duration=durations, loop=0, disposal=2)
        grid.save(os.path.join(PREVIEW, f"{self.name}_sheet.png"))

    @staticmethod
    def preview_cell(f: OutFrame, cw: int, ch: int, px: int, py: int) -> Image.Image:
        cell = Image.new("RGBA", (cw, ch), (92, 92, 104, 255))
        sprite = to_image(f.image).resize((cw, ch), Image.LANCZOS)
        cell.alpha_composite(sprite)
        d = ImageDraw.Draw(cell)
        d.line((0, py, cw, py), fill=(255, 60, 60), width=1)
        d.line((px, 0, px, ch), fill=(80, 140, 255), width=1)
        return cell.convert("RGB")

    def spec(self) -> dict:
        return {
            "name": self.name,
            "out": f"res://assets/sprites/{self.name}/{self.name}.tres",
            "frame_size": [self.frame_w, self.frame_h],
            "pivot": list(self.pivot),
            "display_scale": float(self.cfg["display_scale"]),
            "animations": self.animations,
        }


def run_godot(specs: list[dict]) -> bool:
    if not os.path.exists(GODOT):
        print(f"внимание: Godot не найден ({GODOT}; путь — переменная GODOT), .tres не собраны")
        return False
    spec_path = os.path.join(PREVIEW, "sprite_frames_spec.json")
    with open(spec_path, "w", encoding="utf-8") as f:
        json.dump(specs, f, ensure_ascii=False, indent=1)
    print("Godot: импорт картинок…")
    subprocess.run([GODOT, "--headless", "--path", ROOT, "--import"], capture_output=True, text=True)
    print("Godot: сборка SpriteFrames…")
    r = subprocess.run([GODOT, "--headless", "--path", ROOT, "--script", "res://tools/build_sprite_frames.gd",
                        "--", f"--spec={spec_path}"], capture_output=True, text=True)
    lines = [ln for ln in (r.stdout + r.stderr).splitlines() if ln.strip() and not ln.startswith("Godot Engine")]
    for ln in lines:
        print("  " + ln)
    return r.returncode == 0


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    use_godot = "--no-godot" not in sys.argv
    with open(CONFIG, encoding="utf-8") as f:
        config = json.load(f)
    chars = config["characters"]
    unknown = [a for a in args if a not in chars]
    if unknown:
        print(f"нет в {os.path.relpath(CONFIG, ROOT)}: {', '.join(unknown)}; есть: {', '.join(chars)}")
        return 2
    os.makedirs(PREVIEW, exist_ok=True)
    # Godot не должен импортировать превью.
    open(os.path.join(PREVIEW, ".gdignore"), "a").close()
    jobs = [CharacterJob(name, chars[name], config["defaults"]) for name in (args or list(chars))]
    for job in jobs:
        job.run()
    errors = sum(j.errors for j in jobs)
    specs = [j.spec() for j in jobs if j.animations]
    if specs and use_godot and not run_godot(specs):
        errors += 1
    with open(os.path.join(PREVIEW, "slice_report.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(line for j in jobs for line in j.report) + "\n")
    print(f"Готово: персонажей {len(specs)}, ошибок {errors}. Превью и отчёт — {os.path.relpath(PREVIEW, ROOT)}/")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
