extends Node
## Autoload «Events» — глобальная шина сигналов.
##
## Системы не держат прямых ссылок друг на друга: одна испускает сигнал
## здесь, другая подписывается. Сигналы добавляются по мере появления систем
## (дальше: score_changed, lives_changed, wave_cleared, boss_defeated…).
##
## Сигналы испускаются из других скриптов, поэтому у каждого стоит
## @warning_ignore("unused_signal"): иначе проверка выдаёт UNUSED_SIGNAL.
##
## class_name не задаётся намеренно: он конфликтовал бы с именем autoload.

## Героиня погибла (после падения и мигания).
@warning_ignore("unused_signal")
signal player_died
## Враг побеждён (в начале падения); score — очки за него из EnemyData.
@warning_ignore("unused_signal")
signal enemy_defeated(score: int)
## Подобран бонус data (PickupData) бойцом collector.
@warning_ignore("unused_signal")
signal pickup_collected(data: PickupData, collector: Node2D)
## Камера встала в замок сегмента index, выходят волны.
@warning_ignore("unused_signal")
signal segment_started(index: int)
## Началась волна wave сегмента segment.
@warning_ignore("unused_signal")
signal wave_started(segment: int, wave: int)
## Все волны сегмента index побеждены, замок снят.
@warning_ignore("unused_signal")
signal segment_cleared(index: int)
## Камера встала в арене босса.
@warning_ignore("unused_signal")
signal boss_arena_reached
## Последний сегмент уровня пройден (арена зачищена) — дальше следующий уровень.
@warning_ignore("unused_signal")
signal level_cleared
