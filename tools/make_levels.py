"""Генератор data/levels/<уровень>.tres для пяти уровней сюжета (этап 6.0).

Запуск: python3 tools/make_levels.py — перезаписывает все пять файлов.
Источник правды для волн, предметов и слоёв — таблицы ниже (волны сегментов 1–4 скопированы
с прежнего ocean_drive.tres). Пути к картинкам прописаны всегда: пока файла нет, слой рисует
плейсхолдер, а когда tools/process_backgrounds.py положит картинку в assets/backgrounds/<уровень>/,
она подхватится без правки .tres.
walk_top берётся из tools/floor_lines.json (линия пола main_a, пишет process_backgrounds.py) + FLOOR_MARGIN.
"""
import json
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
FLOOR_LINES = os.path.join(ROOT, "tools", "floor_lines.json")

LEVEL_LENGTH = 8000.0
## Насколько ниже линии пола начинается полоса ходьбы, px.
FLOOR_MARGIN = 15.0
DEFAULT_WALK = (430.0, 680.0)

# Стили плейсхолдера (BackgroundLayerData.PlaceholderStyle).
SKY, FAR, MID, STREET, FRONT, NONE, SOLID, PLAIN = range(8)
LEFT, RIGHT = 0, 1

ENEMIES = {"patrol": "res://data/enemies/patrol.tres", "bike": "res://data/enemies/bike.tres", "riot": "res://data/enemies/riot.tres"}
PROPS = {"crate": "res://data/props/crate.tres", "trash_bin": "res://data/props/trash_bin.tres",
         "newspaper_box": "res://data/props/newspaper_box.tres"}

# (lock_x, волны); волна — список (враг, сторона, глубина, задержка).
SEGMENTS = [
    (1500.0, [[("patrol", RIGHT, 0.3, 0.0), ("patrol", LEFT, 0.7, 0.6)],
              [("bike", RIGHT, 0.4, 0.0), ("bike", LEFT, 0.75, 0.5)]]),
    (2900.0, [[("patrol", RIGHT, 0.3, 0.0), ("bike", LEFT, 0.6, 0.4), ("patrol", RIGHT, 0.8, 1.0)],
              [("riot", RIGHT, 0.5, 0.0)]]),
    (4300.0, [[("riot", RIGHT, 0.5, 0.0), ("patrol", LEFT, 0.3, 0.3), ("patrol", LEFT, 0.8, 0.9)],
              [("bike", RIGHT, 0.2, 0.0), ("bike", LEFT, 0.4, 0.3), ("bike", RIGHT, 0.7, 0.6), ("bike", LEFT, 0.9, 0.9)]]),
    (5800.0, [[("patrol", RIGHT, 0.3, 0.0), ("bike", LEFT, 0.5, 0.3), ("patrol", LEFT, 0.8, 0.8), ("bike", RIGHT, 0.6, 1.2)],
              [("riot", RIGHT, 0.4, 0.0), ("patrol", LEFT, 0.6, 0.4), ("bike", RIGHT, 0.85, 0.8), ("riot", LEFT, 0.2, 1.4)]]),
]
ARENA_X = LEVEL_LENGTH - 640.0
# Арена без босса: усиленная финальная волна копов.
FINAL_WAVES = [
    [("patrol", RIGHT, 0.3, 0.0), ("patrol", LEFT, 0.7, 0.4), ("bike", RIGHT, 0.5, 0.8), ("riot", LEFT, 0.2, 1.2)],
    [("riot", RIGHT, 0.4, 0.0), ("riot", LEFT, 0.7, 0.5), ("patrol", RIGHT, 0.2, 0.9), ("bike", LEFT, 0.9, 1.3),
     ("patrol", RIGHT, 0.6, 1.8)],
]
PROP_SPOTS = [(900.0, 0.2), (1750.0, 0.8), (2400.0, 0.3), (3300.0, 0.15), (3900.0, 0.85), (5000.0, 0.4),
              (6400.0, 0.7), (6900.0, 0.25)]

# Уровни по сюжету. placeholders: (sky, far, mid, main, front) — (стиль, цвет).
LEVELS = [
    {"id": "cellblock", "name": "CELLBLOCK", "boss": False, "props": ("crate", "trash_bin"),
     "placeholders": [(SOLID, "141c1f"), (NONE, "1b2a2c"), (NONE, "2a3b3d"), (PLAIN, "4f7575"), (NONE, "0b1012")]},
    {"id": "yard", "name": "THE YARD", "boss": False, "props": ("crate", "trash_bin"),
     "placeholders": [(SOLID, "0d1228"), (NONE, "1a2238"), (NONE, "2b3348"), (PLAIN, "5a5f55"), (NONE, "0b0d14")]},
    {"id": "everglades", "name": "EVERGLADES", "boss": False, "props": ("crate", "trash_bin"),
     "placeholders": [(SOLID, "2d4a3e"), (NONE, "23402f"), (NONE, "2f5238"), (PLAIN, "4a4a48"), (NONE, "0f1a12")]},
    {"id": "ocean_drive", "name": "OCEAN DRIVE", "boss": False, "props": ("newspaper_box", "trash_bin"),
     "placeholders": [(SKY, "2a1446"), (FAR, "4a2370"), (MID, "6b338c"), (STREET, "dba8b8"), (FRONT, "1f0f2e")]},
    {"id": "port", "name": "THE PORT", "boss": True, "props": ("crate", "trash_bin"),
     "placeholders": [(SOLID, "f2a477"), (NONE, "c98a6a"), (NONE, "8a6a60"), (PLAIN, "7a7a80"), (NONE, "1a1a22")]},
]


def color(hex6: str) -> str:
    r, g, b = (int(hex6[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"Color({r:.3f}, {g:.3f}, {b:.3f}, 1)"


def strings(items: list[str]) -> str:
    return "Array[String]([" + ", ".join(f'"{s}"' for s in items) + "])"


def build(level: dict, floor_lines: dict) -> str:
    lid = level["id"]
    base = f"res://assets/backgrounds/{lid}/"
    line = floor_lines.get(lid)
    walk_top, walk_bottom = (line + FLOOR_MARGIN, 695.0) if line else DEFAULT_WALK
    ext = [("Script", "res://scripts/level/level_data.gd", "1_level"),
           ("Script", "res://scripts/level/level_segment.gd", "2_segment"),
           ("Script", "res://scripts/level/wave_data.gd", "3_wave"),
           ("Script", "res://scripts/level/wave_spawn.gd", "4_spawn"),
           ("Script", "res://scripts/level/background_layer_data.gd", "5_layer"),
           ("Script", "res://scripts/level/prop_placement.gd", "6_placement")]
    ids = {}
    for name, path in list(ENEMIES.items()) + [(p, PROPS[p]) for p in level["props"]]:
        ids[name] = f"{len(ext) + 1}_{name}"
        ext.append(("Resource", path, ids[name]))
    subs: list[str] = []

    def sub(rid: str, body: str) -> str:
        subs.append(f'[sub_resource type="Resource" id="{rid}"]\n{body}\n')
        return f'SubResource("{rid}")'

    segments = SEGMENTS + ([] if level["boss"] else [(ARENA_X, FINAL_WAVES)])
    seg_refs = []
    for si, (lock_x, waves) in enumerate(segments, 1):
        is_final = si == len(segments) and not level["boss"]
        wave_refs = []
        for wi, wave in enumerate(waves, 1):
            spawn_refs = []
            for ki, (enemy, side, depth, delay) in enumerate(wave, 1):
                spawn_refs.append(sub(f"Spawn_s{si}w{wi}_{ki}",
                                      f'script = ExtResource("4_spawn")\nenemy = ExtResource("{ids[enemy]}")\n'
                                      f"side = {side}\ndepth = {depth}\ndelay = {delay}"))
            wave_refs.append(sub(f"Wave_s{si}_{wi}", f'script = ExtResource("3_wave")\nspawns = Array[ExtResource("4_spawn")]([{", ".join(spawn_refs)}])'))
        body = f'script = ExtResource("2_segment")\nlock_x = {lock_x}\nwaves = Array[ExtResource("3_wave")]([{", ".join(wave_refs)}])'
        if is_final:
            body += '\nbanner_text = "FINAL WAVE"'
        seg_refs.append(sub(f"Segment_{si}", body))
    if level["boss"]:
        seg_refs.append(sub("Segment_boss", f'script = ExtResource("2_segment")\nlock_x = {ARENA_X}\nis_boss_arena = true\nbanner_text = "BOSS — TODO"'))

    layer_specs = [("Sky", 0.05, ["sky.png"], False), ("Far", 0.2, ["far.png"], False), ("Mid", 0.5, ["mid.png"], False),
                   ("Main", 1.0, ["main_a.png", "main_b.png", "main_c.png"], False),
                   ("Props", 1.25, [f"props_{i:02d}.png" for i in range(1, 7)], True)]
    layer_refs = []
    for (name, scroll, files, front), (style, col) in zip(layer_specs, level["placeholders"]):
        body = (f'script = ExtResource("5_layer")\nname = "{name}"\nscroll_scale = {scroll}\n'
                f"texture_paths = {strings([base + f for f in files])}\nin_front = {'true' if front else 'false'}\n"
                f"placeholder_style = {style}\nplaceholder_color = {color(col)}")
        if front:
            body += f"\nscatter = true\nscatter_step_min = 500.0\nscatter_step_max = 900.0\nscatter_baseline = 720.0\nscatter_seed = {len(lid) * 7919}"
        layer_refs.append(sub(f"Layer_{name.lower()}", body))

    prop_refs = []
    for pi, (x, depth) in enumerate(PROP_SPOTS, 1):
        kind = level["props"][(pi - 1) % 2]
        prop_refs.append(sub(f"Prop_{pi}", f'script = ExtResource("6_placement")\nprop = ExtResource("{ids[kind]}")\nx = {x}\ndepth = {depth}'))

    out = ['[gd_resource type="Resource" script_class="LevelData" format=3]\n']
    out += [f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in ext]
    out.append("")
    out += subs
    out.append(f'''[resource]
script = ExtResource("1_level")
level_id = "{lid}"
display_name = "{level['name']}"
level_length = {LEVEL_LENGTH}
walk_top = {walk_top}
walk_bottom = {walk_bottom}
player_start = Vector2(300, {round((walk_top + walk_bottom) / 2)})
segments = Array[ExtResource("2_segment")]([{", ".join(seg_refs)}])
layers = Array[ExtResource("5_layer")]([{", ".join(layer_refs)}])
arena_texture_path = "{base}arena.png"
props = Array[ExtResource("6_placement")]([{", ".join(prop_refs)}])
''')
    return "\n".join(out)


def main() -> None:
    floor_lines = {}
    if os.path.exists(FLOOR_LINES):
        with open(FLOOR_LINES, encoding="utf-8") as f:
            floor_lines = {k: v for k, v in json.load(f).items() if v}
    for level in LEVELS:
        path = os.path.join(ROOT, "data", "levels", level["id"] + ".tres")
        with open(path, "w", encoding="utf-8") as f:
            f.write(build(level, floor_lines))
        print(f"{path}: walk {floor_lines.get(level['id'], '—')}")


if __name__ == "__main__":
    main()
