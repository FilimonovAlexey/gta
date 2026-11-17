class_name BeatCamera
extends Camera2D
## Камера битемапа: едет за героиней только вправо и никогда не возвращается.
## y фиксирован. Героиня не может уйти за края экрана: каждый физический кадр
## камера выдаёт ей границы ходьбы = полоса улицы ∩ видимая часть экрана.
##
## Замок: камера не заезжает дальше stop_x (центр камеры в замке сегмента).
## Доехав, встаёт (locked) и испускает stop_reached; release(next_stop_x)
## снимает замок и задаёт следующий. Замками управляет LevelDirector.

## Камера встала в stop_x.
signal stop_reached

## За кем следить (героиня).
@export var target: Actor
## Улица — для полосы ходьбы и длины.
@export var street: Street
## Насколько впереди героини держать центр камеры, px.
@export var look_ahead: float = 80.0
## Скорость догоняния: доля расстояния до цели за секунду (экспоненциально).
@export var follow_speed: float = 6.0
## Отступ героини от краёв экрана, px.
@export var screen_margin: float = 40.0

## Дальше этого x центра камера не едет (INF — до конца улицы).
var stop_x: float = INF
## Камера стоит в замке.
var locked: bool = false


func _ready() -> void:
	position_smoothing_enabled = false
	global_position = Vector2(_clamp_center(_desired_x()), get_half_size().y)
	reset_smoothing()


func _physics_process(delta: float) -> void:
	if locked:
		global_position.x = stop_x
	else:
		var goal: float = maxf(global_position.x, _clamp_center(_desired_x()))
		var x: float = lerpf(global_position.x, goal, 1.0 - exp(-follow_speed * delta))
		# Подъезд к замку: последний пиксель — сразу, иначе экспонента не доедет.
		if stop_x < INF and goal >= stop_x and stop_x - x < 1.0:
			x = stop_x
		global_position.x = maxf(x, global_position.x)
		if stop_x < INF and global_position.x >= stop_x:
			global_position.x = stop_x
			locked = true
			stop_reached.emit()
	_confine_target()


## Снять замок; дальше камера едет до next_stop_x (INF — до конца улицы).
func release(next_stop_x: float = INF) -> void:
	locked = false
	stop_x = next_stop_x


## Половина видимой области в мировых пикселях.
func get_half_size() -> Vector2:
	return get_viewport_rect().size * 0.5 / zoom


## Видимая часть мира по положению камеры (без отставания canvas transform).
func get_view_rect() -> Rect2:
	var half: Vector2 = get_half_size()
	return Rect2(global_position - half, half * 2.0)


func _desired_x() -> float:
	if target == null or not is_instance_valid(target):
		return global_position.x
	return target.global_position.x + look_ahead


## Центр камеры в пределах улицы и не дальше замка.
func _clamp_center(x: float) -> float:
	var half: float = get_half_size().x
	var right: float = (street.street_width if street != null else x + half) - half
	return minf(clampf(x, half, maxf(right, half)), stop_x)


## Героиня ходит только в пределах экрана.
func _confine_target() -> void:
	if target == null or not is_instance_valid(target) or street == null:
		return
	var bounds: Rect2 = street.get_walk_bounds()
	var view: Rect2 = street.get_global_transform().affine_inverse() * get_view_rect()
	var left: float = maxf(bounds.position.x, view.position.x + screen_margin)
	var right: float = minf(bounds.end.x, view.end.x - screen_margin)
	target.set_walk_bounds(Rect2(left, bounds.position.y, maxf(right - left, 1.0), bounds.size.y))
