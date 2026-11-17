class_name AttackData
extends Resource
## Параметры одной атаки. Значения задаются в data/attacks/**/*.tres.
##
## Атака синхронизирована с анимацией бойца: animation — имя анимации в SpriteFrames
## (jab, cross… у героини, attack у копов), frame_durations — сколько секунд держится
## каждый кадр (замах длиннее, удар короткий), active_frames — номера кадров (с 0),
## на которых включён хитбокс. Фазы считаются по кадрам: до первого активного кадра —
## замах (STARTUP), активные — ACTIVE, после — восстановление (RECOVERY).
## Хитбокс включает Actor по сигналу frame_changed спрайта (без спрайта — по тому же
## таймлайну напрямую).
##
## hitbox_rect — прямоугольник удара в координатах бойца, смотрящего вправо:
## начало координат — точка на земле под ногами, y вверх отрицательный.
## Прямоугольник уже учитывает height: в прыжке он поднимается вместе с бойцом,
## а при взгляде влево отражается по x.

## Имя атаки (для отладочной подписи).
@export var name: String = ""
## Урон по здоровью цели.
@export var damage: int = 10
## Анимация атаки в SpriteFrames бойца.
@export var animation: StringName = &""
## Длительность каждого кадра анимации, с.
@export var frame_durations: PackedFloat32Array = PackedFloat32Array([0.05, 0.06, 0.15])
## Кадры (с 0), на которых хитбокс включён.
@export var active_frames: PackedInt32Array = PackedInt32Array([1])
## Зона удара относительно бойца (см. описание класса).
@export var hitbox_rect: Rect2 = Rect2(20.0, -150.0, 70.0, 30.0)
## Скорость отброса цели, px/с: при HURT затухает за время оглушения,
## при сбивании с ног — горизонтальная скорость полёта.
@export var knockback: float = 60.0
## Сбивает ли удар с ног.
@export var knockdown: bool = false
## Сколько замирают атакующий и цель в момент попадания, с.
@export_range(0.0, 0.2, 0.01) var hitstop: float = 0.05
## Пробивает ли щит спереди (апперкот, удар в прыжке).
@export var guard_break: bool = false
## Рывок вперёд в активное окно, px/с (0 — без рывка). Используется врагами.
@export var lunge_speed: float = 0.0


func get_frame_count() -> int:
	return frame_durations.size()


## Кадр атаки в момент t от её начала; -1 — атака кончилась.
func get_frame_at(t: float) -> int:
	var end: float = 0.0
	for i in frame_durations.size():
		end += frame_durations[i]
		if t < end:
			return i
	return -1


func is_active_frame(index: int) -> bool:
	return active_frames.has(index)


## Момент начала первого активного кадра от начала атаки, с.
func get_active_start() -> float:
	var t: float = 0.0
	for i in frame_durations.size():
		if is_active_frame(i):
			return t
		t += frame_durations[i]
	return t


## Момент конца последнего активного кадра от начала атаки, с.
func get_active_end() -> float:
	var t: float = 0.0
	var end: float = 0.0
	for i in frame_durations.size():
		t += frame_durations[i]
		if is_active_frame(i):
			end = t
	return end


## Полная длительность атаки, с.
func get_total_time() -> float:
	var t: float = 0.0
	for d in frame_durations:
		t += d
	return t
