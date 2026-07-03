extends RefCounted
## Часть пула мобных паттернов (MobThreats) — снаряд-тип `&"orb"` (круглые пули).
## Файл — просто «модуль-неймспейс» с вложенными классами, инстанцируется он
## сам никогда; загружается через preload() из mob_threats.gd и вызывается как
## OrbPatterns.Spray.new() и т.п. Не даёт этому одному файлу разрастись на 25 атак.

# ── Рой: быстрые шарики летят в тебя, иногда веером ──
class Spray extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "РОЙ"
        rule = "шарики летят в тебя — уходи с линии"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.15, 0.24)
            var b: Rect2 = arena.box
            var side := randi() % 4
            var p: Vector2
            match side:
                0: p = Vector2(randf_range(b.position.x, b.end.x), b.position.y - 14.0)
                1: p = Vector2(randf_range(b.position.x, b.end.x), b.end.y + 14.0)
                2: p = Vector2(b.position.x - 14.0, randf_range(b.position.y, b.end.y))
                _: p = Vector2(b.end.x + 14.0, randf_range(b.position.y, b.end.y))
            var v: Vector2 = (arena.soul - p).normalized() * randf_range(122.0, 152.0)
            arena.spawn_shape(&"orb", p, v, {"size": Vector2(9, 9), "warn": 0.12,
                "tint": Color("#ff7a5a")})
            if randf() < 0.4:                    # веер
                arena.spawn_shape(&"orb", p, v.rotated(0.28) * 0.94,
                    {"size": Vector2(9, 9), "warn": 0.12, "tint": Color("#ffd08a")})
        if elapsed() >= 6.0:
            done = true


# ── Ливень: шарики сыплются сверху струями ──
class Rain extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "ЛИВЕНЬ"
        rule = "шарики сыплются — лавируй между струями"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.12, 0.18)
            var b: Rect2 = arena.box
            for _i in range(2):
                var x := randf_range(b.position.x, b.end.x)
                arena.spawn_shape(&"orb", Vector2(x, b.position.y - 12.0),
                    Vector2(randf_range(-20, 20), randf_range(132.0, 168.0)),
                    {"size": Vector2(8, 8), "warn": 0.0, "tint": Color("#7ae0ff")})
        if elapsed() >= 6.0:
            done = true


# ── Вихрь: спираль шариков из центра ──
class Spin extends BossAttack:
    var _a := 0.0
    var _cd := 0.0
    func _init() -> void:
        name = "ВИХРЬ"
        rule = "спираль крутится — иди против вращения"
    func start(arena) -> void:
        _a = randf() * TAU
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = 0.1
            var c: Vector2 = arena.box.get_center()
            for k in [0.0, PI]:
                var v := Vector2.from_angle(_a + float(k)) * 122.0
                arena.spawn_shape(&"orb", c, v, {"size": Vector2(8, 8), "warn": 0.0,
                    "tint": Color("#c8a0ff")})
            _a += 0.5
        if elapsed() >= 6.0:
            done = true


# ── Залпы: кольца шариков из точек, беги в промежутки ──
class Burst extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "ЗАЛПЫ"
        rule = "кольца шариков — беги в промежутки меж лучей"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.5, 0.75)
            var b: Rect2 = arena.box
            var p := Vector2(randf_range(b.position.x + 24.0, b.end.x - 24.0),
                             randf_range(b.position.y + 24.0, b.end.y - 24.0))
            if p.distance_to(arena.soul) < 40.0:
                p = b.get_center() + (p - arena.soul).normalized() * 48.0
            var a0 := randf() * TAU
            for k in range(8):
                var v := Vector2.from_angle(a0 + TAU * float(k) / 8.0) * randf_range(96.0, 122.0)
                arena.spawn_shape(&"orb", p, v, {"size": Vector2(8, 8), "warn": 0.24,
                    "tint": Color("#ff9a5a")})
        if elapsed() >= 6.0:
            done = true


# ── Шквал: ветер сносит + поток шариков сверху ──
class Gust extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "ШКВАЛ"
        rule = "ветер сносит + шарики — подгребай и уворачивайся"
    func start(arena) -> void:
        var s := 1.0 if randf() < 0.5 else -1.0
        _add_force(arena, &"wind", {"dir": Vector2(s * 58.0, 0.0), "gust": Vector2(s * 18.0, 0.0)})
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.18, 0.26)
            var b: Rect2 = arena.box
            var x := randf_range(b.position.x, b.end.x)
            arena.spawn_shape(&"orb", Vector2(x, b.position.y - 12.0),
                Vector2(randf_range(-30, 30), 134.0),
                {"size": Vector2(8, 8), "warn": 0.0, "tint": Color("#8fd8e8")})
        if elapsed() >= 6.0:
            done = true


# ── Крест: 4-рукавный крест шариков, вращается ──
class Cross extends BossAttack:
    var _a := 0.0
    var _cd := 0.0
    func _init() -> void:
        name = "КРЕСТ"
        rule = "крест лучей крутится — лавируй между рукавами"
    func start(arena) -> void:
        _a = randf() * TAU
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = 0.14
            var c: Vector2 = arena.box.get_center()
            for k in [0.0, PI * 0.5, PI, PI * 1.5]:
                var v := Vector2.from_angle(_a + k) * 118.0
                arena.spawn_shape(&"orb", c, v, {"size": Vector2(8, 8), "warn": 0.0,
                    "tint": Color("#ff9ad0")})
            _a += 0.22
        if elapsed() >= 6.0:
            done = true


# ── Зигзаг: волнистый поток шариков с одного края ──
class Zigzag extends BossAttack:
    var _cd := 0.0
    var _wt := 0.0
    var _side := 1.0
    func _init() -> void:
        name = "ЗИГЗАГ"
        rule = "волна виляет по синусоиде — поймай ритм"
    func start(arena) -> void:
        _side = 1.0 if randf() < 0.5 else -1.0
    func update(arena, delta) -> void:
        _wt += delta
        _cd -= delta
        if _cd <= 0.0:
            _cd = 0.1
            var b: Rect2 = arena.box
            var y: float = b.position.y + b.size.y * 0.5 + sin(_wt * 5.0) * (b.size.y * 0.42)
            var sx: float = b.position.x - 14.0 if _side > 0.0 else b.end.x + 14.0
            arena.spawn_shape(&"orb", Vector2(sx, y),
                Vector2(150.0 * _side, cos(_wt * 5.0) * 90.0),
                {"size": Vector2(8, 8), "warn": 0.0, "tint": Color("#7ae0ff")})
        if elapsed() >= 6.0:
            done = true


# ── Пульс: расширяющееся кольцо шариков из центра ──
class Pulse extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "ПУЛЬС"
        rule = "кольцо расширяется — беги наружу вовремя"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = 0.62
            var c: Vector2 = arena.box.get_center()
            var n := 10
            for k in range(n):
                var v := Vector2.from_angle(TAU * float(k) / float(n)) * 104.0
                arena.spawn_shape(&"orb", c, v, {"size": Vector2(8, 8), "warn": 0.2,
                    "tint": Color("#ffd08a")})
        if elapsed() >= 6.0:
            done = true


# ── Схождение: шарики летят с краёв в центр коробки (не в душу) ──
class Converge extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "СХОЖДЕНИЕ"
        rule = "летит в центр арены — не стой посередине"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = 0.2
            var b: Rect2 = arena.box
            var c: Vector2 = b.get_center()
            var side := randi() % 4
            var p: Vector2
            match side:
                0: p = Vector2(randf_range(b.position.x, b.end.x), b.position.y - 14.0)
                1: p = Vector2(randf_range(b.position.x, b.end.x), b.end.y + 14.0)
                2: p = Vector2(b.position.x - 14.0, randf_range(b.position.y, b.end.y))
                _: p = Vector2(b.end.x + 14.0, randf_range(b.position.y, b.end.y))
            var v: Vector2 = (c - p).normalized() * 132.0
            arena.spawn_shape(&"orb", p, v, {"size": Vector2(8, 8), "warn": 0.0,
                "tint": Color("#ff7a5a")})
        if elapsed() >= 6.0:
            done = true


# ── Завеса: стена шариков с щелью наступает сбоку ──
class Wall extends BossAttack:
    var _cd := 0.0
    var _gap := 0.0
    func _init() -> void:
        name = "ЗАВЕСА"
        rule = "стена шариков наступает — ныряй в разрыв"
    func start(arena) -> void:
        var b: Rect2 = arena.box
        _gap = randf_range(b.position.y + 20.0, b.end.y - 20.0)
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = 0.55
            var b: Rect2 = arena.box
            var from_left := randf() < 0.5
            var sx: float = b.position.x - 14.0 if from_left else b.end.x + 14.0
            var vx := 96.0 if from_left else -96.0
            var y := b.position.y + 10.0
            while y < b.end.y:
                if absf(y - _gap) > 22.0:
                    arena.spawn_shape(&"orb", Vector2(sx, y), Vector2(vx, 0.0),
                        {"size": Vector2(7, 7), "warn": 0.16, "tint": Color("#e8e8f4")})
                y += 15.0
            _gap = clampf(_gap + randf_range(-40.0, 40.0), b.position.y + 20.0, b.end.y - 20.0)
        if elapsed() >= 6.0:
            done = true


# ── Морось: редкие шарики со всех сторон вразнобой ──
class Drizzle extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "МОРОСЬ"
        rule = "редкие капли отовсюду — не расслабляйся"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.2, 0.35)
            var b: Rect2 = arena.box
            var side := randi() % 3
            var p: Vector2
            var v: Vector2
            match side:
                0:
                    p = Vector2(randf_range(b.position.x, b.end.x), b.position.y - 12.0)
                    v = Vector2(randf_range(-20.0, 20.0), 112.0)
                1:
                    p = Vector2(b.position.x - 12.0, randf_range(b.position.y, b.end.y))
                    v = Vector2(102.0, randf_range(-20.0, 20.0))
                _:
                    p = Vector2(b.end.x + 12.0, randf_range(b.position.y, b.end.y))
                    v = Vector2(-102.0, randf_range(-20.0, 20.0))
            arena.spawn_shape(&"orb", p, v, {"size": Vector2(7, 7), "warn": 0.0,
                "tint": Color("#8fd8e8")})
        if elapsed() >= 6.0:
            done = true


# ── Орбита: 3 шарика кружат по кольцу вокруг центра ──
class Orbit extends BossAttack:
    var _orbs: Array = []
    func _init() -> void:
        name = "ОРБИТА"
        rule = "шарики кружат по кольцу — не пересекайся с ним"
    func start(arena) -> void:
        var c: Vector2 = arena.box.get_center()
        var n := 3
        for i in range(n):
            var ang: float = TAU * float(i) / float(n)
            var p: Vector2 = c + Vector2.from_angle(ang) * 50.0
            _orbs.append(arena.spawn_shape(&"orb", p, Vector2.ZERO,
                {"size": Vector2(9, 9), "warn": 0.0, "tint": Color("#c8a0ff"), "life": 5.5}))
    func update(arena, _delta) -> void:
        var c: Vector2 = arena.box.get_center()
        for o in _orbs:
            var to_c: Vector2 = c - o.pos
            o.vel = to_c.orthogonal().normalized() * 92.0 + to_c.normalized() * 30.0
        if elapsed() >= 5.5:
            done = true


# ── Змей: шарики летят по изогнутой дуге с одного края ──
class Snake extends BossAttack:
    var _cd := 0.0
    var _side := 1.0
    func _init() -> void:
        name = "ЗМЕЙ"
        rule = "шарики летят по дуге — читай изгиб пути"
    func start(arena) -> void:
        _side = 1.0 if randf() < 0.5 else -1.0
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = 0.13
            var b: Rect2 = arena.box
            var y := randf_range(b.position.y + 16.0, b.end.y - 16.0)
            var sx: float = b.position.x - 14.0 if _side > 0.0 else b.end.x + 14.0
            arena.spawn_shape(&"orb", Vector2(sx, y), Vector2(100.0 * _side, -40.0),
                {"size": Vector2(7, 7), "warn": 0.0, "accel": Vector2(0, 90.0),
                 "tint": Color("#9ad84a")})
        if elapsed() >= 6.0:
            done = true


# ── Углы: диагональные потоки шариков со всех 4 углов к центру ──
class Corner extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "УГЛЫ"
        rule = "диагонали из углов — держись середины стороны"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = 0.42
            var b: Rect2 = arena.box
            var c: Vector2 = b.get_center()
            var corners := [b.position, Vector2(b.end.x, b.position.y), b.end,
                             Vector2(b.position.x, b.end.y)]
            for p in corners:
                var v: Vector2 = (c - p).normalized() * 94.0
                arena.spawn_shape(&"orb", p, v, {"size": Vector2(8, 8), "warn": 0.22,
                    "tint": Color("#ff9a5a")})
        if elapsed() >= 6.0:
            done = true


# ── Мины: точки-маркеры плантуются и лопаются кольцом после паузы ──
class Mines extends BossAttack:
    var _cd := 0.0
    func _init() -> void:
        name = "МИНЫ"
        rule = "мина щёлкает и взрывается кольцом — не стой рядом"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = 0.5
            var b: Rect2 = arena.box
            var p := Vector2(randf_range(b.position.x + 20.0, b.end.x - 20.0),
                             randf_range(b.position.y + 20.0, b.end.y - 20.0))
            if p.distance_to(arena.soul) < 30.0:
                p = b.get_center()
            arena.spawn_shape(&"orb", p, Vector2.ZERO, {"size": Vector2(6, 6), "warn": 0.0,
                "safe": true, "life": 0.85, "tint": Color("#ff5a3a")})
            for k in range(6):
                var v := Vector2.from_angle(TAU * float(k) / 6.0) * 90.0
                arena.spawn_shape(&"orb", p, v, {"size": Vector2(7, 7), "warn": 0.85,
                    "tint": Color("#ff8a5a")})
        if elapsed() >= 6.0:
            done = true
