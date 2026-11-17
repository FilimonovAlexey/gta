class_name BackgroundLayerData
extends Resource
## Слой параллакса. Картинки — texture_paths (assets/backgrounds/<уровень>/…); из списка берутся
## только существующие файлы. Если нет ни одной — рисуется плейсхолдер стиля placeholder_style.
##
## Обычный слой (scatter = false): картинки идут подряд (main_a → main_b → main_c) и вся полоса
## повторяется по горизонтали; масштаб — под высоту экрана 720 px.
## Декор (scatter = true): картинки-предметы (props_01…06) расставляются по длине уровня
## с шагом scatter_step_min…max, низом на линию scatter_baseline; без повтора.

## Как рисовать плейсхолдер, пока нет картинок.
## NONE — ничего; SOLID — заливка placeholder_color; PLAIN — простая стена и пол уровня;
## SKY/FAR/MID/STREET/FRONT — закатный Майами (Ошен-драйв).
enum PlaceholderStyle { SKY, FAR, MID, STREET, FRONT, NONE, SOLID, PLAIN }

## Имя узла слоя.
@export var name: String = "Layer"
## Скорость прокрутки относительно камеры: 1 — вместе с миром, меньше — дальше, больше — ближе.
@export var scroll_scale: float = 1.0
## Картинки слоя по порядку. Несуществующие файлы пропускаются.
@export var texture_paths: Array[String] = []
## Рисуется перед бойцами (передний план).
@export var in_front: bool = false
@export var placeholder_style: PlaceholderStyle = PlaceholderStyle.SKY
## Основной цвет плейсхолдера.
@export var placeholder_color: Color = Color(0.4, 0.2, 0.55)

@export_group("Декор")
## Расставлять картинки как отдельные предметы вдоль уровня.
@export var scatter: bool = false
## Шаг между предметами (случайный в пределах), px слоя.
@export var scatter_step_min: float = 500.0
@export var scatter_step_max: float = 900.0
## y низа предметов (точка опоры — низ по центру), px экрана.
@export var scatter_baseline: float = 720.0
## Зерно случайной расстановки — одинаковая раскладка при каждом запуске.
@export var scatter_seed: int = 1
