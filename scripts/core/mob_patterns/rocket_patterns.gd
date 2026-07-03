extends RefCounted
## Часть пула мобных паттернов (MobThreats) — самонаводящиеся ракеты со взрывным
## следом, вылетающие с краёв. Модуль-неймспейс, см. orb_patterns.gd.

# ── Ракеты: наводятся ~0.9с, потом летят прямо; тянут огненный след, взрыв в конце ──
class Rockets extends BossAttack:
    var _cd := 0.0
    var _rk: Array = []
    func _init() -> void:
        name = "РАКЕТЫ"
        rule = "ракеты наводятся — сорви их резким манёвром"
    func _spawn_one(arena, from_left: bool) -> void:
        var b: Rect2 = arena.box
        var p := Vector2(b.position.x - 14.0 if from_left else b.end.x + 14.0,
                         randf_range(b.position.y, b.end.y))
        var r: Dictionary = arena.spawn_shape(&"orb", p, (arena.soul - p).normalized() * 66.0,
            {"size": Vector2(11, 11), "warn": 0.2, "life": 2.1, "tint": Color("#ff6a3a")})
        r["steer"] = 0.9
        _rk.append(r)
    func _tick_rockets(arena, delta: float) -> void:
        var still: Array = []
        for r in _rk:
            if float(r.get("life", 0.0)) <= 0.0:      # ракета «сдохла» → взрыв кольцом
                for k in range(6):
                    var ev := Vector2.from_angle(TAU * float(k) / 6.0) * 94.0
                    arena.spawn_shape(&"orb", r.pos, ev, {"size": Vector2(7, 7),
                        "warn": 0.5, "tint": Color("#ff9a3a")})
                continue
            var st := float(r.get("steer", 0.0))
            if st > 0.0 and float(r.get("warn", 0.0)) <= 0.0:
                r["steer"] = st - delta
                var want: Vector2 = (arena.soul - r.pos).normalized() * 96.0
                r.vel = r.vel.lerp(want, 2.4 * delta).limit_length(112.0)
            if float(r.get("warn", 0.0)) <= 0.0:
                arena._spark_burst(r.pos, 1, Color("#ffb060"))   # взрывной след
            still.append(r)
        _rk = still
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.7, 1.0)
            _spawn_one(arena, randf() < 0.5)
        _tick_rockets(arena, delta)
        if elapsed() >= 6.0:
            done = true


# ── Залп ракет: пара ракет с противоположных краёв ──
class RocketPair extends Rockets:
    func _init() -> void:
        name = "ЗАЛП РАКЕТ"
        rule = "ракеты с двух сторон — уводи их одну от другой"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(1.1, 1.5)
            _spawn_one(arena, true)
            _spawn_one(arena, false)
        _tick_rockets(arena, delta)
        if elapsed() >= 6.0:
            done = true
