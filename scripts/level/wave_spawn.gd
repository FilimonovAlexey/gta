class_name WaveSpawn
extends Resource
## Один враг волны: тип, сторона экрана, глубина и задержка от начала волны.

enum ScreenSide { LEFT, RIGHT }

## Тип врага (data/enemies/*.tres).
@export var enemy: EnemyData
## Из-за какого края экрана выходит. Если с этой стороны конец улицы — с другой.
@export var side: ScreenSide = ScreenSide.RIGHT
## Глубина в полосе ходьбы: 0 — дальний край (walk_top), 1 — ближний (walk_bottom).
@export_range(0.0, 1.0) var depth: float = 0.5
## Через сколько секунд после начала волны появляется, с.
@export var delay: float = 0.0
