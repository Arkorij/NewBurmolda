extends RefCounted
class_name BossKit
## База кита босса: держит СВОЙ авторский набор атак. Наследники
## (KalitinKit/TsiziKit/…) переопределяют opening() и pick(). Ни один кит
## не переиспользует атаки другого — только общий тулкит примитивов (BulletKit).
##
## opening() — срежиссированные первые «биты» боя (драматургия подачи):
##   Array из «бит»-элементов, где бит — это Array[BossAttack] (1 = соло,
##   2 = комбо). Проигрываются по порядку, пока не кончатся.
## pick(stage, phase2) — следующий бит после открытия: соло/комбо из СВОИХ
##   атак, усложняющееся по stage/phase2 (эскалация — докрутка своих механик,
##   НЕ подмешивание чужих).

func opening() -> Array:
    ## -> Array[ Array[BossAttack] ]. По умолчанию пусто (сразу pick()).
    return []


func pick(_stage: int, _phase2: bool) -> Array:
    ## -> Array[BossAttack] (1-2 атаки). Переопредели у конкретного босса.
    return []


# ─── помощники для наследников ───
func _beat(a: BossAttack) -> Array:
    return [a]


func _combo(a: BossAttack, b: BossAttack) -> Array:
    return [a, b]
