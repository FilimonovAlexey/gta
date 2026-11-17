"""Раскладка art_source/_inbox по утверждённому плану (этап 6.0).

Только перемещает: ничего не удаляет и не перезаписывает. Если файл с новым именем уже есть,
старый уходит в art_source/_alternates/ с суффиксом _vN. Каждое перемещение дописывается в
art_source/manifest.csv (по нему можно откатить: new_path → original_name).
Запуск: python3 tools/organize_inbox.py
"""
import csv
import os
import shutil
import unicodedata

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art_source")
ROOT = os.path.normpath(ROOT)
INBOX = os.path.join(ROOT, "_inbox")
MANIFEST = os.path.join(ROOT, "manifest.csv")

# исходное имя (NFC) → (новый путь от art_source, что это, заметки)
PLAN = {
    "main_a.png": ("backgrounds/cellblock/main_a.png", "cellblock: основной слой — ряд камер", "верх ~50 px прозрачный; пол с y≈415/724"),
    "main_b.png": ("backgrounds/cellblock/main_b.png", "cellblock: основной слой — будка охраны и шкафчики", "размер 2304x768, остальные 2172x724"),
    "main_с.png": ("backgrounds/cellblock/main_c.png", "cellblock: основной слой — столовая", "в исходном имени кириллическая «с»"),
    "Героиня.jpg": ("heroine/anchor.jpg", "героиня: якорь", "JPEG, артефакты на краю ключа"),
    "Оранжевая героиня_ шесть кадров дыхания.png": ("heroine/H1.png", "героиня: H1 стойка", ""),
    "Шесть кадров шагающей героини.png": ("heroine/H2.png", "героиня: H2 ходьба", ""),
    "Спрайт-лист героини_ поворот на носке.png": ("heroine/H3.png", "героиня: H3 джеб + кросс", ""),
    "Оранжевая героиня_ шесть боевых поз.png": ("heroine/H4.png", "героиня: H4 апперкот + удар ногой", ""),
    "Героиня в шести прыжковых позах.png": ("heroine/H5.png", "героиня: H5 прыжок + удар в прыжке", "удар ногой низкий, похож на подкат — кандидат на перегенерацию"),
    "Шесть реакций героини в оранжевом.png": ("heroine/H6.png", "героиня: H6 урон + падение", "кадр 6 заходит за границу ячейки — резать по фигурам"),
    "Оранжевая героиня в шести позах.png": ("heroine/H7.png", "героиня: H7 подъём + победная поза", ""),
    "Самоуверенный патрульный с дубинкой.png": ("patrol/anchor.png", "патрульный: якорь", ""),
    "Шагающий патрульный с жезлом.png": ("patrol/E1.png", "патрульный: E1 ходьба", ""),
    "Пляжный велопатрульный в боксерской стойке.png": ("bike/anchor.png", "велопатруль: якорь", ""),
    "Шестикадровый спрайт дерзкого велогонщика.png": ("bike/E1.png", "велопатруль: E1 ходьба", ""),
    "Тяжёлый щитоносец с прозрачным щитом.png": ("riot/anchor.png", "ОМОН: якорь", "полупрозрачный щит поверх ключа"),
    "Шестикадровый спрайт бронированного щитоносца.png": ("riot/E1.png", "ОМОН: E1 ходьба", "полупрозрачный щит поверх ключа"),
    "Тактический командир затягивает перчатку.png": ("boss/anchor.png", "босс: якорь", "броня почти чёрная, не тёмно-серая"),
    "Шестикадровый спрайт-лист командира с исправленной позой.png": ("boss/E1.png", "босс: E1 ходьба", "броня почти чёрная"),
}


def free_alternate(rel: str) -> str:
    base, ext = os.path.splitext(os.path.basename(rel))
    sub = os.path.dirname(rel)
    n = 2
    while True:
        cand = os.path.join("_alternates", sub, f"{base}_v{n}{ext}")
        if not os.path.exists(os.path.join(ROOT, cand)):
            return cand
        n += 1


def main() -> None:
    new_file = not os.path.exists(MANIFEST)
    with open(MANIFEST, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        if new_file:
            w.writerow(["original_name", "new_path", "what", "size", "notes"])
        for name in sorted(os.listdir(INBOX)):
            if name.startswith("."):
                continue
            key = unicodedata.normalize("NFC", name)
            if key not in PLAN:
                print("нет в плане, оставляю:", key)
                continue
            rel, what, notes = PLAN[key]
            src = os.path.join(INBOX, name)
            with Image.open(src) as im:
                size = f"{im.width}x{im.height}"
            dst = os.path.join(ROOT, rel)
            if os.path.exists(dst):
                alt = free_alternate(rel)
                os.makedirs(os.path.dirname(os.path.join(ROOT, alt)), exist_ok=True)
                shutil.move(dst, os.path.join(ROOT, alt))
                w.writerow([rel, alt, "вытеснен новым файлом", "", "был на месте " + rel])
                print("старый →", alt)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.move(src, dst)
            w.writerow([key, rel, what, size, notes])
            print(f"{key} → {rel}")


if __name__ == "__main__":
    main()
