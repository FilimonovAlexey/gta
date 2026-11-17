class_name Level
extends Node2D
## Уровень, собранный из LevelData: слои параллакса (Background — за бойцами,
## Foreground — перед ними), фон арены, улица Street с World, героиня на старте,
## разрушаемые предметы. Камерой, волнами и замками управляют BeatCamera
## и LevelDirector (дочерние узлы сцены level.tscn).
##
## Какой уровень строить, решает Game (Game.get_current_level_data()): данные берутся
## в _enter_tree, до _ready дочерних узлов, и передаются LevelDirector. Экспортное
## level_data — запасной вариант, если Game ничего не выбрал.

## Ширина экрана — арена занимает lock_x ± половина, px.
const SCREEN_WIDTH: float = 1280.0

@export var level_data: LevelData
## Сцена разрушаемого предмета (scenes/props/breakable.tscn).
@export var breakable_scene: PackedScene

@onready var background: Node2D = $Background
@onready var foreground: Node2D = $Foreground
@onready var street: Street = $Street


func _enter_tree() -> void:
	var chosen: LevelData = Game.get_current_level_data()
	if chosen != null:
		level_data = chosen
	var director := get_node_or_null("LevelDirector") as LevelDirector
	if director != null:
		director.level_data = level_data
	if level_data != null:
		(get_node("Street") as Street).configure(level_data.level_length, level_data.walk_top, level_data.walk_bottom)


func _ready() -> void:
	if level_data == null:
		push_error("Level: не задан level_data")
		return
	print("Уровень %d: %s (%s)" % [Game.level_index + 1, level_data.display_name, level_data.level_id])
	build_backdrop(level_data, background, foreground)
	var player := street.get_node_or_null("World/Player") as Actor
	if player != null:
		player.set_walk_bounds(street.get_walk_bounds())
		player.position = player.walk_bounds.get_center() if not player.walk_bounds.has_point(level_data.player_start) else level_data.player_start
	_place_props()


## Слои параллакса и фон арены уровня data в узлы background (за бойцами) и foreground (перед ними).
## Используется и уровнем, и отладочной сценой предпросмотра фонов.
static func build_backdrop(data: LevelData, back: Node2D, front: Node2D) -> void:
	for layer_data in data.layers:
		var layer := BackgroundLayer.new()
		layer.setup(layer_data, data.walk_top, data.walk_bottom, data.level_length)
		(front if layer_data.in_front else back).add_child(layer)
	if not data.arena_texture_path.is_empty() and ResourceLoader.exists(data.arena_texture_path) and not data.segments.is_empty():
		var texture := load(data.arena_texture_path) as Texture2D
		var arena := Sprite2D.new()
		arena.name = "Arena"
		arena.texture = texture
		arena.centered = false
		arena.scale = Vector2(SCREEN_WIDTH / texture.get_width(), BackgroundLayer.SCREEN_HEIGHT / texture.get_height())
		arena.position = Vector2(data.get_arena_x() - SCREEN_WIDTH * 0.5, 0.0)
		back.add_child(arena)


func _place_props() -> void:
	if breakable_scene == null:
		push_error("Level: не задан breakable_scene")
		return
	for placement in level_data.props:
		var prop := breakable_scene.instantiate() as Breakable
		prop.data = placement.prop
		street.spawn_actor(prop, Vector2(placement.x, level_data.depth_to_y(placement.depth)))
