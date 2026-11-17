class_name EnemySpawner
extends Node
## Появление врагов за краем экрана: spawn(data) ставит врага чуть за видимой
## частью улицы, и он выходит (ENTER) к точке на тротуаре внутри экрана.
##
## В тестовой улице: клавиши 1/2/3 в режиме отладки (Debug.spawn_requested)
## спавнят enemy_types[0..2]; с --autoplay враги появляются сами,
## пока живых меньше autoplay_max_enemies.

## Улица, в World которой появляются враги.
@export var street: Street
## Общая сцена врага (scenes/enemies/enemy.tscn).
@export var enemy_scene: PackedScene
## Типы врагов; индекс = номер клавиши минус один.
@export var enemy_types: Array[EnemyData] = []
## Насколько за краем экрана появляется враг, px.
@export var spawn_margin: float = 80.0
## Насколько внутрь экрана он выходит, px.
@export var entry_inset: float = 160.0
## --autoplay: сам выпускать врагов (в тестовой улице). В уровне волнами ведёт LevelDirector.
@export var autoplay_spawning: bool = true
## --autoplay: сколько врагов держать на улице одновременно и как часто добавлять.
@export var autoplay_max_enemies: int = 3
@export var autoplay_spawn_interval: float = 2.5

var _autoplay: bool = OS.get_cmdline_user_args().has("--autoplay")
var _autoplay_timer: float = 0.5
var _autoplay_next_type: int = 0


func _ready() -> void:
	Debug.spawn_requested.connect(_on_spawn_requested)


func _physics_process(delta: float) -> void:
	if not _autoplay or not autoplay_spawning or enemy_types.is_empty():
		return
	_autoplay_timer -= delta
	if _autoplay_timer > 0.0:
		return
	_autoplay_timer = autoplay_spawn_interval
	if _count_alive_enemies() < autoplay_max_enemies:
		spawn(enemy_types[_autoplay_next_type % enemy_types.size()])
		_autoplay_next_type += 1


## Создать врага типа data за краем экрана side (1 — справа, -1 — слева, 0 — случайно;
## если там конец улицы — за другим) на глубине depth (0..1 в полосе ходьбы, < 0 — случайно).
func spawn(data: EnemyData, side: int = 0, depth: float = -1.0) -> Enemy:
	if street == null or enemy_scene == null or data == null:
		push_error("EnemySpawner: не заданы street, enemy_scene или data")
		return null
	var view: Rect2 = street.get_global_transform().affine_inverse() * StreetCamera.get_visible_world_rect(get_viewport())
	var bounds: Rect2 = street.get_walk_bounds()
	if side == 0:
		side = 1 if randf() < 0.5 else -1
	var y: float = bounds.position.y + bounds.size.y * (depth if depth >= 0.0 else randf())
	var x: float = _offscreen_x(view, side)
	if x < bounds.position.x or x > bounds.end.x:
		side = -side
		x = _offscreen_x(view, side)
	var entry_x: float = view.position.x + entry_inset if side < 0 else view.end.x - entry_inset
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.data = data
	enemy.set_enter_point(Vector2(entry_x, y))
	street.spawn_actor(enemy, Vector2(x, y))
	print("Спавн врага: %s (%s)" % [data.enemy_type, "справа" if side > 0 else "слева"])
	return enemy


func _offscreen_x(view: Rect2, side: int) -> float:
	return view.end.x + spawn_margin if side > 0 else view.position.x - spawn_margin


func _count_alive_enemies() -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and enemy.is_alive():
			count += 1
	return count


func _on_spawn_requested(index: int) -> void:
	if index >= 0 and index < enemy_types.size():
		spawn(enemy_types[index])
