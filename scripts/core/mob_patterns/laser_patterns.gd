extends RefCounted
## Часть пула мобных паттернов (MobThreats) — тонкие быстрые лучи (как у боссов,
## но уже и с коротким телеграфом, чтобы влезть в 3-5с бой). Модуль-неймспейс,
## см. orb_patterns.gd для пояснения схемы.

# ── Луч-развёртка: тонкий луч бьёт полосой в новом месте ──
class LaserSweep extends BossAttack:
    var _cd := 0.0
    var _horiz := true
    func _init() -> void:
        name = "ЛУЧ-РАЗВЁРТКА"
        rule = "тонкий луч бьёт полосой — успей сойти с неё"
    func start(arena) -> void:
        _horiz = randf() < 0.5
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.34, 0.48)
            var b: Rect2 = arena.box
            if _horiz:
                var ly := randf_range(b.position.y + 6.0, b.end.y - 16.0)
                arena.add_hazard_zone(Rect2(b.position.x, ly, b.size.x, 11.0),
                    {"warn": 0.32, "active": 0.16, "tint": Color("#ff5a3a")})
            else:
                var lx := randf_range(b.position.x + 6.0, b.end.x - 16.0)
                arena.add_hazard_zone(Rect2(lx, b.position.y, 11.0, b.size.y),
                    {"warn": 0.32, "active": 0.16, "tint": Color("#ff5a3a")})
        if elapsed() >= 6.0:
            done = true


# ── Луч-крест: горизонтальный + вертикальный тонкие лучи разом ──
class LaserCross extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "ЛУЧ-КРЕСТ"
        rule = "крест из лучей — стой в свободной клетке"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.55, 0.75)
            var b: Rect2 = arena.box
            var ly := randf_range(b.position.y + 6.0, b.end.y - 16.0)
            var lx := randf_range(b.position.x + 6.0, b.end.x - 16.0)
            arena.add_hazard_zone(Rect2(b.position.x, ly, b.size.x, 11.0),
                {"warn": 0.4, "active": 0.18, "tint": Color("#ff7a3a")})
            arena.add_hazard_zone(Rect2(lx, b.position.y, 11.0, b.size.y),
                {"warn": 0.4, "active": 0.18, "tint": Color("#ff7a3a")})
        if elapsed() >= 6.0:
            done = true
