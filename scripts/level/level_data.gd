class_name LevelData
extends Resource
## Описание уровня: размеры улицы, сегменты с замками и волнами, слои фона
## и разрушаемые предметы. Файлы — data/levels/*.tres; сцену собирает Level.

## Длина улицы, px.
@export var level_length: float = 8000.0
## Полоса ходьбы по глубине (y), px.
@export var walk_top: float = 430.0
@export var walk_bottom: float = 680.0
## Где стоит героиня в начале.
@export var player_start: Vector2 = Vector2(300.0, 560.0)
## Сегменты по порядку (lock_x возрастает).
@export var segments: Array[LevelSegment] = []
## Слои параллакса сзади наперёд.
@export var layers: Array[BackgroundLayerData] = []
## Разрушаемые предметы.
@export var props: Array[PropPlacement] = []


## y по доле глубины (0 — walk_top, 1 — walk_bottom).
func depth_to_y(depth: float) -> float:
	return lerpf(walk_top, walk_bottom, clampf(depth, 0.0, 1.0))
