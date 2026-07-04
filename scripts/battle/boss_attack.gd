extends RefCounted
class_name BossAttack
## Одна атака врага — маленький автомат состояний (телеграф → активна → готово).
## Наследники переопределяют start()/update(). Атака ЧИТАЕТ поле арены
## (arena.soul/box/phase2/stage/bh_t) и СОЗДАЁТ угрозы ТОЛЬКО через фабрики
## примитивов арены (arena.spawn_shape/add_force/add_hazard_zone/…), а не
## руками через bullets.append/draw_circle.
##
## Каждая атака несёт короткое ПРАВИЛО (name/rule) — показывается игроку в HUD,
## чтобы «хаос» читался как решаемая головоломка (принцип order-in-chaos).

var done := false
var name := "АТАКА"       # короткое имя (в HUD)
var rule := ""            # правило-подсказка: что делать игроку
var hold := 0.0           # секунды «отойди» перед стартом: атаки, стартующие
                          # ИЗ ЦЕНТРА, дают время убраться (иначе неуворачиваемо);
                          # арена удлиняет фазу мобов на hold

var _t := 0.0             # секунды с начала атаки
var _forces: Array = []   # id силовых полей — снимаются в _cleanup()


func start(_arena) -> void:
    ## Заспавнить телеграф/начальные угрозы, включить поля. Переопредели.
    pass


func update(_arena, _delta: float) -> void:
    ## Кадр: двигать/доспавнивать угрозы; выставить done=true, когда отыграла.
    pass


func tick(arena, delta: float) -> void:
    ## Служебная обёртка: ведёт таймер и зовёт update(); при done — чистит поля.
    _t += delta
    update(arena, delta)
    if done:
        _cleanup(arena)


func elapsed() -> float:
    return _t


func holding() -> bool:
    ## true, пока идёт пауза «отойди от центра» (см. hold).
    return _t < hold


func _show_hold(arena) -> void:
    ## Мигающее кольцо-предупреждение в центре на время hold: «уйди отсюда».
    ## Реализовано честным warn-телеграфом орба, который умирает сразу после.
    arena.spawn_shape(&"orb", arena.box.get_center(), Vector2.ZERO,
        {"size": Vector2(30, 30), "warn": hold, "life": 0.01,
         "tint": Color("#ffd08a")})


func _add_force(arena, kind: StringName, opts: Dictionary = {}) -> int:
    var id: int = arena.add_force(kind, opts)
    _forces.append(id)
    return id


func _cleanup(arena) -> void:
    ## Снять все поля этой атаки; коридор/синий режим сбрасываются ареной между битами.
    for id in _forces:
        arena.remove_force(id)
    _forces.clear()
