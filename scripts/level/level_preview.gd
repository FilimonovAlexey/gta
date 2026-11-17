class_name LevelPreview
extends Node2D
## Отладочная сцена: снимки фонов всех уровней без боёвки (scenes/level/level_preview.tscn).
## Для каждого уровня из Game.LEVELS строит слои (Level.build_backdrop), рисует полосу ходьбы
## (жёлтые линии walk_top / walk_bottom) и мерные прямоугольники ростом с бойца у дальнего
## и ближнего края, ставит камеру в несколько точек и сохраняет кадр в PNG.
## Запуск — только с окном (в headless нет рендера):
##   godot --path . res://scenes/level/level_preview.tscn -- --shots=<папка> [--levels=1,3]

## Где снимать: x центра камеры; последняя точка — арена.
const SHOT_XS: Array[float] = [640.0, 2900.0, 5200.0]
## Рост мерного бойца, px.
const FIGURE_HEIGHT: float = 180.0
## Кадров ожидания перед снимком (параллаксу нужен кадр, чтобы встать).
const SETTLE_FRAMES: int = 3

@onready var camera: Camera2D = $Camera


func _ready() -> void:
	var out_dir: String = ""
	var only: Array[int] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			out_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--levels="):
			for part in arg.get_slice("=", 1).split(","):
				only.append(part.to_int() - 1)
	if out_dir.is_empty():
		push_error("LevelPreview: нужен аргумент --shots=<папка>")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in Game.LEVELS.size():
		if only.is_empty() or only.has(i):
			await _shoot_level(load(Game.LEVELS[i]) as LevelData, out_dir)
	get_tree().quit()


func _shoot_level(data: LevelData, out_dir: String) -> void:
	var back := Node2D.new()
	var front := Node2D.new()
	var marks := Node2D.new()
	add_child(back)
	add_child(marks)
	add_child(front)
	Level.build_backdrop(data, back, front)
	_add_marks(marks, data)
	var xs: Array[float] = SHOT_XS.duplicate()
	xs.append(data.get_arena_x())
	for x in xs:
		camera.position = Vector2(x, 360.0)
		for f in SETTLE_FRAMES:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = "%s/%s_%05d.png" % [out_dir, data.level_id, int(x)]
		get_viewport().get_texture().get_image().save_png(path)
		print("Снимок: ", path)
	for node in [back, marks, front]:
		node.queue_free()
	await get_tree().process_frame


## Полоса ходьбы и мерные бойцы по всей длине уровня.
func _add_marks(parent: Node2D, data: LevelData) -> void:
	for y in [data.walk_top, data.walk_bottom]:
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(0.0, y), Vector2(data.level_length, y)])
		line.width = 2.0
		line.default_color = Color(1.0, 0.9, 0.1, 0.9)
		parent.add_child(line)
	var x: float = 400.0
	while x < data.level_length:
		for y in [data.walk_top, data.walk_bottom]:
			var figure := ColorRect.new()
			figure.color = Color(1.0, 0.4, 0.7, 0.75)
			figure.position = Vector2(x - 30.0, y - FIGURE_HEIGHT)
			figure.size = Vector2(60.0, FIGURE_HEIGHT)
			parent.add_child(figure)
		x += 600.0
