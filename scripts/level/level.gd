class_name Level
extends Node2D
## Уровень, собранный из LevelData: слои параллакса (Background — за бойцами,
## Foreground — перед ними), улица Street с World, героиня на старте,
## разрушаемые предметы. Камерой, волнами и замками управляют BeatCamera
## и LevelDirector (дочерние узлы сцены level.tscn).

@export var level_data: LevelData
## Сцена разрушаемого предмета (scenes/props/breakable.tscn).
@export var breakable_scene: PackedScene

@onready var background: Node2D = $Background
@onready var foreground: Node2D = $Foreground
@onready var street: Street = $Street


func _ready() -> void:
	if level_data == null:
		push_error("Level: не задан level_data")
		return
	street.configure(level_data.level_length, level_data.walk_top, level_data.walk_bottom)
	_build_layers()
	var player := street.get_node_or_null("World/Player") as Actor
	if player != null:
		player.set_walk_bounds(street.get_walk_bounds())
		player.position = player.walk_bounds.get_center() if not player.walk_bounds.has_point(level_data.player_start) else level_data.player_start
	_place_props()


func _build_layers() -> void:
	for layer_data in level_data.layers:
		var layer := BackgroundLayer.new()
		layer.setup(layer_data, level_data.walk_top, level_data.walk_bottom)
		(foreground if layer_data.in_front else background).add_child(layer)


func _place_props() -> void:
	if breakable_scene == null:
		push_error("Level: не задан breakable_scene")
		return
	for placement in level_data.props:
		var prop := breakable_scene.instantiate() as Breakable
		prop.data = placement.prop
		street.spawn_actor(prop, Vector2(placement.x, level_data.depth_to_y(placement.depth)))
