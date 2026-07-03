extends BossKit
class_name TsiziKit
## Цизи — тема «ветер / давление». Сигнатура: порывы, толкающие сердце (сами по
## себе не урон — вызов на управление). Весь кит про воздух: порывы, вакуум,
## турбулентность, воздушный тоннель, подхваченный ветром мусор. Уникален.


# ── Порыв: сильный ветер + опасная кромка с подветренной стороны ──
class Gust extends BossAttack:
    var _cd := 0.0
    var _hard := false
    var _side := 1
    func _init(hard := false) -> void:
        _hard = hard
        name = "ПОРЫВ"
        rule = "греби ПРОТИВ ветра, прочь от кромки"
    func start(arena) -> void:
        _side = 1 if randf() < 0.5 else -1
        _add_force(arena, &"wind", {"dir": Vector2(_side * (92.0 if _hard else 74.0), 0.0),
            "gust": Vector2(_side * 28.0, 0.0)})
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.7, 1.0)
            var b: Rect2 = arena.box                    # опасная полоса у подветренной стены
            var strip := 22.0
            var rect := Rect2(b.end.x - strip, b.position.y, strip, b.size.y) if _side > 0 \
                    else Rect2(b.position.x, b.position.y, strip, b.size.y)
            arena.add_hazard_zone(rect, {"warn": 0.4, "active": 0.4, "tint": Color("#8fd8e8")})
        if elapsed() >= (3.4 if _hard else 2.8):
            done = true


# ── Вакуум-воронка: тянет к точке, в центре — мусор ──
class Vacuum extends BossAttack:
    var _hard := false
    var _pt := Vector2.ZERO
    func _init(hard := false) -> void:
        _hard = hard
        name = "ВОРОНКА"
        rule = "греби ОТ центра, не влетай в мусор"
    func start(arena) -> void:
        _pt = arena.box.get_center() + Vector2(randf_range(-30, 30), randf_range(-20, 20))
        _add_force(arena, &"vacuum", {"point": _pt, "strength": (150.0 if _hard else 110.0)})
        arena.spawn_shape(&"spinner", _pt, Vector2.ZERO,
            {"size": Vector2(30, 8), "spin": 3.0, "warn": 0.4, "life": (3.4 if _hard else 2.8),
             "tint": Color("#b6a6ff")})
    func update(_arena, _delta) -> void:
        if elapsed() >= (3.6 if _hard else 3.0):
            done = true


# ── Турбулентность: шум управления + дрейфующий мусор ──
class Turbulence extends BossAttack:
    var _cd := 0.0
    var _hard := false
    func _init(hard := false) -> void:
        _hard = hard
        name = "ТУРБУЛЕНТНОСТЬ"
        rule = "управление шатает — веди сердце заранее"
    func start(arena) -> void:
        _add_force(arena, &"turbulence", {"strength": (70.0 if _hard else 48.0)})
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.6, 0.9)
            var b: Rect2 = arena.box
            var y := b.position.y - 16.0
            var x := randf_range(b.position.x, b.end.x)
            arena.spawn_shape(&"rect", Vector2(x, y), Vector2(randf_range(-30, 30), 70.0),
                {"size": Vector2(16, 10), "angle": randf() * TAU, "spin": 2.0,
                 "warn": 0.3, "tint": Color("#c8e0ff")})
        if elapsed() >= (3.4 if _hard else 2.8):
            done = true


# ── Воздушный тоннель: змеящийся коридор под напором ветра ──
class AirTunnel extends BossAttack:
    var _hard := false
    var _phase := 0.0
    func _init(hard := false) -> void:
        _hard = hard
        name = "ВОЗДУШНЫЙ ТОННЕЛЬ"
        rule = "держись коридора, ветер сносит"
    func start(arena) -> void:
        _phase = randf() * TAU
        _add_force(arena, &"wind", {"dir": Vector2((1.0 if randf() < 0.5 else -1.0) * 40.0, 0.0)})
    func update(arena, delta) -> void:
        _phase += delta * 1.6
        var b: Rect2 = arena.box
        var ch := (56.0 if _hard else 72.0)
        var cy := b.position.y + (b.size.y - ch) * (0.5 + 0.42 * sin(_phase))
        arena.set_corridor(Rect2(b.position.x + 6.0, cy, b.size.x - 12.0, ch))
        if elapsed() >= (3.6 if _hard else 3.0):
            arena.set_corridor(Rect2())
            done = true


# ── Мусор на ветру: несколько дрейфующих лезвий ──
class Debris extends BossAttack:
    var _cd := 0.0
    var _hard := false
    func _init(hard := false) -> void:
        _hard = hard
        name = "МУСОР НА ВЕТРУ"
        rule = "уходи с траектории летящих обломков"
    func start(arena) -> void:
        _add_force(arena, &"wind", {"dir": Vector2((1.0 if randf() < 0.5 else -1.0) * 50.0, 6.0),
            "gust": Vector2(20.0, 0.0)})
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.44, 0.66) if _hard else randf_range(0.6, 0.85)
            var b: Rect2 = arena.box
            var from_left := randf() < 0.5
            var y := randf_range(b.position.y + 14.0, b.end.y - 14.0)
            var sx := b.position.x - 20.0 if from_left else b.end.x + 20.0
            arena.spawn_shape(&"blade", Vector2(sx, y),
                Vector2((110.0 if from_left else -110.0), randf_range(-16, 16)),
                {"size": Vector2(22, 7), "angle": (0.0 if from_left else PI),
                 "accel": Vector2(0, 24), "warn": 0.28, "tint": Color("#a8c4d8")})
        if elapsed() >= (3.4 if _hard else 2.8):
            done = true


func opening() -> Array:
    return [[Gust.new()], [Vacuum.new()], [AirTunnel.new()], [Gust.new(), Debris.new()]]


func pick(stage: int, phase2: bool) -> Array:
    if not phase2:
        var solo := [Gust.new(), Vacuum.new(), Turbulence.new(), AirTunnel.new(), Debris.new()]
        return [solo[randi() % solo.size()]]
    var combos := [
        [Vacuum.new(true), Debris.new(true)],
        [AirTunnel.new(true), Debris.new(true)],
        [Turbulence.new(true), Debris.new(true)],
    ]
    if randf() < 0.3:
        return [Gust.new(true)]
    return combos[randi() % combos.size()]
