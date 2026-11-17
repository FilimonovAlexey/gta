class_name ActorSprite
extends AnimatedSprite2D
## Спрайт бойца (узел Visual/Sprite в actor.tscn).
##
## Грузит SpriteFrames, собранные tools/slice_sheets.py (assets/sprites/<персонаж>/<персонаж>.tres),
## и берёт из их метаданных масштаб (display_scale) и смещение (sprite_offset): опора кадра
## (низ фигуры, центр торса) совпадает с точкой на земле бойца. Масштаб всех персонажей меняется
## в одном месте — display_scale в art_source/animations.json (и перезапуск slice_sheets.py).
##
## Каким кадром показывать состояние, решает Actor; спрайт только находит анимацию:
## своя → FRAMES; нет своей, но есть замена «анимация:кадр» из ActorStats.animation_fallbacks →
## FALLBACK (стоп-кадр); нет ничего → NONE (боец рисуется прямоугольником-плейсхолдером).
## О каждой недостающей анимации персонажа предупреждает один раз за запуск.

## Что удалось показать.
enum Shown { NONE, FRAMES, FALLBACK }

## Уже выданные предупреждения: "<персонаж>/<анимация>" → true. Общие для всех экземпляров.
static var _warned: Dictionary = {}

## Имя персонажа (по имени файла SpriteFrames) — для предупреждений.
var character: String = ""

## Замены недостающих анимаций: имя → "другая:кадр".
var _fallbacks: Dictionary = {}
## Кэш поиска: имя → [имя анимации в SpriteFrames, стоп-кадр (-1 — своя анимация)].
var _resolved: Dictionary = {}


## Загрузить SpriteFrames по пути. Возвращает false, если файла нет (боец остаётся плейсхолдером).
func setup(frames_path: String, fallbacks: Dictionary) -> bool:
	_fallbacks = fallbacks
	_resolved.clear()
	if frames_path.is_empty():
		return false
	character = frames_path.get_file().get_basename()
	if not ResourceLoader.exists(frames_path):
		_warn_once("", "нет файла SpriteFrames %s — плейсхолдер" % frames_path)
		return false
	var frames := load(frames_path) as SpriteFrames
	if frames == null:
		_warn_once("", "%s — не SpriteFrames, плейсхолдер" % frames_path)
		return false
	sprite_frames = frames
	var k: float = frames.get_meta("display_scale", 0.5)
	scale = Vector2(k, k)
	centered = true
	offset = frames.get_meta("sprite_offset", Vector2.ZERO)
	return true


func is_ready() -> bool:
	return sprite_frames != null


## Есть ли у персонажа своя анимация anim (без замен).
func has_own(anim: StringName) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(anim)


## Сколько кадров в своей анимации anim (0 — её нет).
func get_own_frame_count(anim: StringName) -> int:
	return sprite_frames.get_frame_count(anim) if has_own(anim) else 0


## Скорость своей анимации, кадров в секунду (0 — её нет).
func get_own_fps(anim: StringName) -> float:
	return sprite_frames.get_animation_speed(anim) if has_own(anim) else 0.0


## Показать кадр index анимации anim и остановиться на нём (кадры ведёт боец).
## Смена кадра испускает frame_changed.
func show_frame(anim: StringName, index: int) -> Shown:
	var target: Array = _resolve(anim)
	if target.is_empty():
		return Shown.NONE
	var anim_name: StringName = target[0]
	var fixed: int = target[1]
	if animation != anim_name:
		animation = anim_name
	if is_playing():
		pause()
	var last: int = sprite_frames.get_frame_count(anim_name) - 1
	var wanted: int = clampi(index if fixed < 0 else fixed, 0, last)
	if frame != wanted:
		frame = wanted
	return Shown.FRAMES if fixed < 0 else Shown.FALLBACK


## Проиграть анимацию anim по кругу со скоростью speed (отрицательная — задом наперёд).
## frozen — пауза на текущем кадре (хитстоп).
func play_loop(anim: StringName, speed: float, frozen: bool) -> Shown:
	var target: Array = _resolve(anim)
	if target.is_empty():
		return Shown.NONE
	if target[1] >= 0:
		return show_frame(anim, 0)
	speed_scale = speed
	if frozen:
		if animation != target[0]:
			animation = target[0]
		pause()
	elif animation != target[0] or not is_playing():
		play(target[0])
	return Shown.FRAMES


## Найти, что показывать вместо anim: [имя, стоп-кадр] или [] — нечего.
func _resolve(anim: StringName) -> Array:
	if _resolved.has(anim):
		return _resolved[anim]
	var result: Array = []
	if sprite_frames == null:
		pass
	elif sprite_frames.has_animation(anim):
		result = [anim, -1]
	else:
		var spec: String = str(_fallbacks.get(String(anim), ""))
		var parts: PackedStringArray = spec.split(":")
		var other := StringName(parts[0])
		if not spec.is_empty() and sprite_frames.has_animation(other):
			var index: int = parts[1].to_int() if parts.size() > 1 else 0
			result = [other, index]
			_warn_once(anim, "нет анимации «%s» — запасной кадр %s" % [anim, spec])
		else:
			_warn_once(anim, "нет анимации «%s» и замены — плейсхолдер" % anim)
	_resolved[anim] = result
	return result


func _warn_once(anim: StringName, text: String) -> void:
	var key: String = "%s/%s" % [character, anim]
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning("Спрайт %s: %s" % [character, text])
