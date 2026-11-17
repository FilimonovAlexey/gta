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

@export_group("Спрайт")
## SpriteFrames персонажа (assets/sprites/<персонаж>/<персонаж>.tres). Пусто или нет файла —
## прямоугольник-плейсхолдер.
@export_file("*.tres") var sprite_frames_path: String = ""
## Замены недостающих анимаций: "имя" → "другая_анимация:кадр" (стоп-кадр).
## Нет ни анимации, ни замены — на это состояние боец рисуется прямоугольником.
@export var animation_fallbacks: Dictionary = {}
## Сколько px проходит боец за один цикл анимации walk (два шага). По нему ходьба
## ускоряется и замедляется вместе со скоростью, чтобы ноги не скользили.
@export var walk_stride: float = 170.0

@export_group("Тело")
## Хёртбокс в координатах бойца, смотрящего вправо: (0,0) — точка на земле, y вверх
## отрицательный. Подогнан под спрайт стойки (рамка F1 лежит на рисунке).
@export var hurtbox_rect: Rect2 = Rect2(-30.0, -180.0, 60.0, 180.0)
## Полуоси эллипса тени на земле (по ширине стопы в стойке).
@export var shadow_radius: Vector2 = Vector2(38.0, 12.0)

@export_group("Реакции на урон")
## Оглушение после лёгкого попадания (HURT), с.
@export var hurt_time: float = 0.3
## Вертикальная скорость подброса при сбивании с ног, px/с.
@export var knockdown_launch_velocity: float = 450.0
## Сколько боец лежит после падения (DOWN), с.
@export var down_time: float = 0.8
## Длительность подъёма (GETUP), с.
@export var getup_time: float = 0.4
## Неуязвимость с миганием после подъёма, с.
@export var getup_invuln_time: float = 0.5
## Мигание лежащего мёртвого бойца перед исчезновением, с.
@export var death_blink_time: float = 1.0
## Если между попаданиями прошло больше — счётчик «подряд» начинается заново, с.
@export var hit_chain_window: float = 0.5
## На каком попадании подряд боец падает, даже если удар не сбивающий.
@export var hits_to_knockdown: int = 3

@export_group("Атаки")
## Сколько помнится нажатие attack, сделанное во время удара, с.
@export var attack_buffer_time: float = 0.15
## Через сколько секунд без нажатий серия сбрасывается к первому удару, с.
@export var combo_reset_time: float = 0.4

@export_group("Подбор")
## Насколько близко по x к бонусу нужно стоять, чтобы подобрать, px.
@export var pickup_range_x: float = 70.0
## Допуск по глубине при подборе, px.
@export var pickup_depth_tolerance: float = 24.0
## Сколько длится подбор (боец стоит на месте), с.
@export var pickup_time: float = 0.25

@export_group("Победа")
## Сколько героиня празднует снятие замка (анимация victory), с.
@export var victory_time: float = 1.0
