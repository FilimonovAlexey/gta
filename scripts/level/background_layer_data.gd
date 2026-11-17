class_name BackgroundLayerData
extends Resource
## Слой параллакса. Если файл texture_path существует — слой показывает картинку,
## повторяя её по горизонтали (масштаб — под высоту экрана 720 px). Если нет —
## рисуется цветной плейсхолдер стиля placeholder_style.

## Как рисовать плейсхолдер, пока нет картинки.
enum PlaceholderStyle { SKY, FAR, MID, STREET, FRONT }

## Имя узла слоя.
@export var name: String = "Layer"
## Скорость прокрутки относительно камеры: 1 — вместе с миром, меньше — дальше, больше — ближе.
@export var scroll_scale: float = 1.0
## Картинка слоя (assets/backgrounds/…). Пока файла нет — плейсхолдер.
@export_file("*.png", "*.webp", "*.jpg") var texture_path: String = ""
## Рисуется перед бойцами (передний план).
@export var in_front: bool = false
@export var placeholder_style: PlaceholderStyle = PlaceholderStyle.SKY
## Основной цвет плейсхолдера.
@export var placeholder_color: Color = Color(0.4, 0.2, 0.55)
