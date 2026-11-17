extends SceneTree
## Сборка SpriteFrames из кадров, нарезанных tools/slice_sheets.py (вызывается им же).
## Запуск: godot --headless --path . --script res://tools/build_sprite_frames.gd -- --spec=<путь к json>
## Картинки должны быть уже импортированы (`godot --headless --path . --import`).
## В метаданные ресурса пишутся frame_size, pivot (опора в кадре: низ фигуры, центр торса),
## display_scale и sprite_offset — offset для AnimatedSprite2D (centered = true), при котором опора
## попадает в начало координат узла.


func _initialize() -> void:
	var spec_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--spec="):
			spec_path = arg.substr(7)
	if spec_path.is_empty():
		push_error("build_sprite_frames: не задан --spec=<json>")
		quit(1)
		return
	var text: String = FileAccess.get_file_as_string(spec_path)
	var specs: Variant = JSON.parse_string(text)
	if not specs is Array:
		push_error("build_sprite_frames: не прочитан %s" % spec_path)
		quit(1)
		return
	var failed: int = 0
	for spec: Dictionary in specs:
		if not _build(spec):
			failed += 1
	quit(1 if failed > 0 else 0)


func _build(spec: Dictionary) -> bool:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var count: int = 0
	for anim: Dictionary in spec["animations"]:
		var anim_name := StringName(anim["name"])
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(anim["fps"]))
		frames.set_animation_loop(anim_name, bool(anim["loop"]))
		for path: String in anim["frames"]:
			var texture := load(path) as Texture2D
			if texture == null:
				push_error("build_sprite_frames: нет текстуры %s" % path)
				return false
			frames.add_frame(anim_name, texture)
			count += 1
	var size := Vector2(spec["frame_size"][0], spec["frame_size"][1])
	var pivot := Vector2(spec["pivot"][0], spec["pivot"][1])
	frames.set_meta(&"frame_size", size)
	frames.set_meta(&"pivot", pivot)
	frames.set_meta(&"display_scale", float(spec["display_scale"]))
	frames.set_meta(&"sprite_offset", size * 0.5 - pivot)
	var out: String = spec["out"]
	var err := ResourceSaver.save(frames, out)
	if err != OK:
		push_error("build_sprite_frames: не сохранён %s (%s)" % [out, error_string(err)])
		return false
	print("SpriteFrames %s: анимаций %d, кадров %d" % [out, frames.get_animation_names().size(), count])
	return true
