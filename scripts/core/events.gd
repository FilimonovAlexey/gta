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
