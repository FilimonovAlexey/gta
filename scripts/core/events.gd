extends Node
## Autoload «Events» — глобальная шина сигналов.
##
## Системы не держат прямых ссылок друг на друга: одна испускает сигнал
## здесь, другая подписывается. Сигналы будут добавляться по мере появления
## систем, например:
##   signal actor_damaged(actor: Actor, amount: int)
##   signal actor_died(actor: Actor)
##   signal score_changed(score: int)
##   signal lives_changed(lives: int)
##   signal wave_cleared(wave_index: int)
##   signal boss_defeated
##
## Пока пусто: объявленный, но не используемый сигнал даёт предупреждение
## UNUSED_SIGNAL, а проверка требует вывода без предупреждений.
##
## class_name не задаётся намеренно: он конфликтовал бы с именем autoload.
