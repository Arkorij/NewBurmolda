extends RefCounted
## Часть пула мобных паттернов (MobThreats) — снаряд-тип `&"cross"` (летающие
## вертящиеся кресты). Модуль-неймспейс, см. orb_patterns.gd для пояснения схемы.

# ── Крестопад: вертящиеся кресты сыплются сверху ──
class XRain extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "КРЕСТОПАД"
        rule = "кресты сыплются сверху — лавируй между ними"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.18, 0.26)
            var b: Rect2 = arena.box
            var x := randf_range(b.position.x, b.end.x)
            arena.spawn_shape(&"cross", Vector2(x, b.position.y - 12.0),
                Vector2(randf_range(-16, 16), randf_range(118.0, 148.0)),
                {"size": Vector2(10, 10), "spin": 4.5, "warn": 0.0, "tint": Color("#ff9ad0")})
        if elapsed() >= 6.0:
            done = true


# ── Кресторой: кресты летят в тебя с краёв ──
class XSpray extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "КРЕСТОРОЙ"
        rule = "вертящиеся кресты летят в тебя — уходи с линии"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.2, 0.3)
            var b: Rect2 = arena.box
            var side := randi() % 4
            var p: Vector2
            match side:
                0: p = Vector2(randf_range(b.position.x, b.end.x), b.position.y - 14.0)
                1: p = Vector2(randf_range(b.position.x, b.end.x), b.end.y + 14.0)
                2: p = Vector2(b.position.x - 14.0, randf_range(b.position.y, b.end.y))
                _: p = Vector2(b.end.x + 14.0, randf_range(b.position.y, b.end.y))
            var v: Vector2 = (arena.soul - p).normalized() * randf_range(108.0, 138.0)
            arena.spawn_shape(&"cross", p, v, {"size": Vector2(11, 11), "spin": 5.5,
                "warn": 0.14, "tint": Color("#ffd08a")})
        if elapsed() >= 6.0:
            done = true


# ── Крестовихрь: кресты по спирали из центра ──
class XSpiral extends BossAttack:
    var _a := 0.0
    var _cd := 0.0
    func _init() -> void:
        name = "КРЕСТОВИХРЬ"
        rule = "кресты по спирали — иди против вращения"
    func start(arena) -> void:
        _a = randf() * TAU
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = 0.16
            var c: Vector2 = arena.box.get_center()
            for k in [0.0, PI]:
                var v := Vector2.from_angle(_a + float(k)) * 108.0
                arena.spawn_shape(&"cross", c, v, {"size": Vector2(11, 11), "spin": 6.0,
                    "warn": 0.0, "tint": Color("#c8a0ff")})
            _a += 0.5
        if elapsed() >= 6.0:
            done = true
