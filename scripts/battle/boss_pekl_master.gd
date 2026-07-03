extends BossKit
class_name PeklMasterKit
## Магистр Пекла (босс шахты, каждые 10 этажей) — тема «адская бюрократия».
## Сигнатура: огненные штампы по расписанию (ряды с чистым сектором) и очереди.


# ── Штампы: ряд планок падает сверху с гарантированным просветом ──
class Stamps extends BossAttack:
    var _cd := 0.0
    var _hard := false
    func _init(hard := false) -> void:
        _hard = hard
        name = "ШТАМПЫ"
        rule = "падают печати — стой в чистой колонке"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.6, 0.85) if _hard else randf_range(0.85, 1.15)
            var b: Rect2 = arena.box
            var cols := 6
            var cw := b.size.x / float(cols)
            var gap := randi() % cols
            var gap2 := -1
            if not _hard:
                gap2 = (gap + 1 + randi() % (cols - 1)) % cols   # мягче: два просвета
            for i in range(cols):
                if i == gap or i == gap2:
                    continue
                var x := b.position.x + (float(i) + 0.5) * cw
                arena.spawn_shape(&"rect", Vector2(x, b.position.y - 12.0),
                    Vector2(0, 130.0), {"size": Vector2(cw - 6.0, 14.0), "warn": 0.34,
                     "tint": Color("#e07a2a")})
        if elapsed() >= (3.4 if _hard else 2.8):
            done = true


# ── Очередь: змеящийся суженный коридор ──
class Queue extends BossAttack:
    var _hard := false
    var _phase := 0.0
    func _init(hard := false) -> void:
        _hard = hard
        name = "ОЧЕРЕДЬ"
        rule = "стой в очереди — не выходи из коридора"
    func start(arena) -> void:
        _phase = randf() * TAU
    func update(arena, delta) -> void:
        _phase += delta * 1.4
        var b: Rect2 = arena.box
        var cw := (60.0 if _hard else 78.0)
        var cx := b.position.x + (b.size.x - cw) * (0.5 + 0.44 * sin(_phase))
        arena.set_corridor(Rect2(cx, b.position.y + 4.0, cw, b.size.y - 8.0))
        if elapsed() >= (3.4 if _hard else 2.8):
            arena.set_corridor(Rect2())
            done = true


# ── Талон: «не стой тут без записи» — зона в случайном месте ──
class Ticket extends BossAttack:
    var _cd := 0.0
    var _hard := false
    func _init(hard := false) -> void:
        _hard = hard
        name = "ТАЛОН"
        rule = "печать шлёпает по клетке — уступи место"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.5, 0.75)
            var b: Rect2 = arena.box
            var w := randf_range(40.0, 66.0)
            var h := randf_range(30.0, 50.0)
            var x := randf_range(b.position.x, b.end.x - w)
            var y := randf_range(b.position.y, b.end.y - h)
            arena.add_hazard_zone(Rect2(x, y, w, h),
                {"warn": (0.3 if _hard else 0.42), "active": 0.3, "tint": Color("#ff8a3a")})
        if elapsed() >= (3.2 if _hard else 2.6):
            done = true


func opening() -> Array:
    return [[Stamps.new()], [Queue.new()], [Ticket.new()]]


func pick(stage: int, phase2: bool) -> Array:
    if not phase2:
        var solo := [Stamps.new(), Queue.new(), Ticket.new()]
        return [solo[randi() % solo.size()]]
    var combos := [
        [Stamps.new(true), Ticket.new(true)],
        [Queue.new(true), Ticket.new(true)],
    ]
    if randf() < 0.3:
        return [Stamps.new(true)]
    return combos[randi() % combos.size()]
