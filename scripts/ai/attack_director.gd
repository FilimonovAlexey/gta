class_name AttackDirector
extends Node
## Узел уровня, раздающий врагам «токены атаки»: одновременно атакуют
## не больше max_attackers врагов, остальные ждут (WAIT).
##
## Враг просит токен (request_token), директор каждый физический кадр
## раздаёт свободные токены просящим. Приоритет — у того, кто дольше всех
## пробыл на экране без атаки (Enemy.get_time_without_attack()).
## Враг возвращает токен (release_token), когда атака закончилась или он
## получил удар; мёртвых и удалённых директор вычищает сам.
## Враги находят директора через группу GROUP.

const GROUP: StringName = &"attack_director"

## Сколько врагов могут атаковать одновременно.
@export var max_attackers: int = 2

## Враги с токеном.
var _holders: Array[Enemy] = []
## Враги, ждущие токена.
var _requests: Array[Enemy] = []


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(_delta: float) -> void:
	_prune(_holders)
	_prune(_requests)
	while _holders.size() < max_attackers and not _requests.is_empty():
		var best: Enemy = _pick_most_patient()
		_requests.erase(best)
		_holders.append(best)


## Встать в очередь за токеном (повторный вызов ничего не меняет).
func request_token(enemy: Enemy) -> void:
	if not _holders.has(enemy) and not _requests.has(enemy):
		_requests.append(enemy)


## Вернуть токен или выйти из очереди.
func release_token(enemy: Enemy) -> void:
	_holders.erase(enemy)
	_requests.erase(enemy)


func has_token(enemy: Enemy) -> bool:
	return _holders.has(enemy)


func is_requesting(enemy: Enemy) -> bool:
	return _requests.has(enemy)


func _pick_most_patient() -> Enemy:
	var best: Enemy = _requests[0]
	for enemy in _requests:
		if enemy.get_time_without_attack() > best.get_time_without_attack():
			best = enemy
	return best


## Убрать удалённых и мёртвых.
static func _prune(list: Array[Enemy]) -> void:
	for i in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[i]) or not list[i].is_alive() or not list[i].is_inside_tree():
			list.remove_at(i)
