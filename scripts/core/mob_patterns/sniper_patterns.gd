extends RefCounted
## Часть пула мобных паттернов (MobThreats) — почти-моментальные пули: у края
## мигает точка-origin (линию не показывает), затем очень быстрый выстрел —
## траекторию нужно угадать. Модуль-неймспейс, см. orb_patterns.gd.

# ── Снайпер: точка мигает у края (линию НЕ показывает), потом очень быстрый выстрел ──
class Sniper extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "СНАЙПЕР"
        rule = "точка мигает у края — угадай линию и двигайся"
    func _fire(arena, warn := 0.46) -> void:
        var b: Rect2 = arena.box
        var side := randi() % 4
        var p: Vector2
        match side:
            0: p = Vector2(randf_range(b.position.x, b.end.x), b.position.y - 10.0)
            1: p = Vector2(randf_range(b.position.x, b.end.x), b.end.y + 10.0)
            2: p = Vector2(b.position.x - 10.0, randf_range(b.position.y, b.end.y))
            _: p = Vector2(b.end.x + 10.0, randf_range(b.position.y, b.end.y))
        # направление зафиксировано на СЕЙЧАС, но игроку показывается только
        # мигающая точка-origin (warn держит пулю на месте) — не сама траектория
        var v: Vector2 = (arena.soul - p).normalized() * 330.0
        arena.spawn_shape(&"orb", p, v, {"size": Vector2(7, 7), "warn": warn,
            "tint": Color("#fff0f0")})
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.6, 0.85)
            _fire(arena)
        if elapsed() >= 6.0:
            done = true


# ── Двойной снайпер: две точки мигают и стреляют разом ──
class SniperDuo extends Sniper:
    func _init() -> void:
        name = "ДВОЙНОЙ СНАЙПЕР"
        rule = "две точки мигают — обе линии надо угадать"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.9, 1.2)
            _fire(arena)
            _fire(arena)
        if elapsed() >= 6.0:
            done = true


# ── Залп снайпера: 3 точки мигают со сдвигом и стреляют очередью ──
class SniperVolley extends Sniper:
    func _init() -> void:
        name = "ЗАЛП СНАЙПЕРА"
        rule = "три вспышки подряд — читай очередь"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(1.1, 1.4)
            _fire(arena, 0.4)      # сдвиг по warn → выстрелы очередью
            _fire(arena, 0.54)
            _fire(arena, 0.68)
        if elapsed() >= 6.0:
            done = true
