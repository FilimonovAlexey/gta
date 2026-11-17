class_name EnemyData
extends ActorStats
## Параметры типа врага: всё из ActorStats (здоровье, скорости, реакции)
## плюс внешний вид, атаки и характер ИИ. Файлы — data/enemies/*.tres.
##
## Новый тип врага = новый .tres с этим скриптом; сцена общая (scenes/enemies/enemy.tscn).

@export_group("Враг")
## Тип врага (для подписи отладки и логов): patrol, bike, riot…
@export var enemy_type: String = "enemy"
## Цвет плейсхолдер-прямоугольника.
@export var placeholder_color: Color = Color(0.2, 0.35, 0.85)
## Атаки по порядку: за один заход ATTACK враг проводит их все подряд.
@export var attacks: Array[AttackData] = []
## С какого расстояния по x враг начинает атаку, px.
@export var attack_range: float = 120.0
## На каком расстоянии по x от героини враг ждёт своей очереди, px.
@export var preferred_distance: float = 220.0
## Агрессивность: как охотно и как скоро просит разрешения атаковать.
@export_range(0.0, 1.0) var aggression: float = 0.5
## Очки за победу над врагом.
@export var score: int = 100

@export_group("ИИ")
## Решения принимаются раз в случайный интервал из этого диапазона, с.
@export var decision_interval_min: float = 0.2
@export var decision_interval_max: float = 0.4
## Через сколько секунд враг разворачивается к героине, если она оказалась за спиной.
@export var turn_delay: float = 0.15
## Вероятность отойти (RETREAT) после своей атаки.
@export_range(0.0, 1.0) var retreat_after_attack_chance: float = 0.3
## Вероятность отойти после полученного удара.
@export_range(0.0, 1.0) var retreat_after_hit_chance: float = 0.3
## На сколько дальше обычной дистанции ожидания отходит при RETREAT, px.
@export var retreat_distance: float = 120.0

@export_group("Щит")
## Щит спереди: удары в лицо без guard_break блокируются, лёгкие удары со спины
## наносят урон, но не прерывают врага.
@export var has_shield: bool = false
## С какой скоростью щит отталкивает ударившего, px/с.
@export var shield_pushback: float = 200.0
