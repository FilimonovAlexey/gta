class_name LevelData
extends Resource
## Описание уровня: размеры улицы, сегменты с замками и волнами, слои фона
## и разрушаемые предметы. Файлы — data/levels/*.tres; сцену собирает Level.

## Код уровня (имя папки assets/backgrounds/<код>, файла data/levels/<код>.tres).
@export var level_id: String = ""
## Название для баннера в начале уровня.
@export var display_name: String = ""
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
## Фон арены в конце уровня — кадр 1280x720 на месте последнего замка (lock_x ± 640).
## Пока файла нет — арену рисуют обычные слои.
@export_file("*.png", "*.webp") var arena_texture_path: String = ""
## Разрушаемые предметы.
@export var props: Array[PropPlacement] = []


## Центр камеры в последнем замке (арена) или INF, если сегментов нет.
func get_arena_x() -> float:
	return segments[-1].lock_x if not segments.is_empty() else INF


## y по доле глубины (0 — walk_top, 1 — walk_bottom).
func depth_to_y(depth: float) -> float:
	return lerpf(walk_top, walk_bottom, clampf(depth, 0.0, 1.0))
