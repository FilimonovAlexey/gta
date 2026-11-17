class_name ActorStats
extends Resource
## Параметры бойца: здоровье, скорости ходьбы, прыжок и тайминги.
##
## Значения задаются в data/*.tres, а не в коде.

## Максимальное здоровье.
@export var max_health: int = 100
## Скорость ходьбы вдоль улицы, px/с.
@export var walk_speed_x: float = 280.0
## Скорость ходьбы вглубь улицы, px/с (обычно ~60% от walk_speed_x).
@export var walk_speed_y: float = 168.0
## Начальная вертикальная скорость прыжка, px/с.
@export var jump_velocity: float = 600.0
## Ускорение свободного падения, px/с².
@export var gravity: float = 2000.0
## Длительность приземления после прыжка, с.
@export var land_time: float = 0.1
