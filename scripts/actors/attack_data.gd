class_name AttackData
extends Resource
## Параметры одной атаки. Значения задаются в data/attacks/**/*.tres.
##
## Тайминги идут подряд: startup (замах) → active (хитбокс включён) → recovery
## (возврат в стойку).
##
## hitbox_rect — прямоугольник удара в координатах бойца, смотрящего вправо:
## начало координат — точка на земле под ногами, y вверх отрицательный.
## Прямоугольник уже учитывает height: в прыжке он поднимается вместе с бойцом,
## а при взгляде влево отражается по x.

## Имя атаки (для отладочной подписи).
@export var name: String = ""
## Урон по здоровью цели.
@export var damage: int = 10
## Замах до включения хитбокса, с.
@export var startup: float = 0.05
## Сколько хитбокс включён, с.
@export var active: float = 0.06
## Возврат в стойку после активного окна, с.
@export var recovery: float = 0.15
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


## Момент конца активного окна от начала атаки, с.
func get_active_end() -> float:
	return startup + active


## Полная длительность атаки, с.
func get_total_time() -> float:
	return startup + active + recovery
