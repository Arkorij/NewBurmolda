extends BossKit
class_name OverseerKit
## Надзиратель Пекла (мини-босс шахты, каждые 5 этажей) — тема «завод/смена/плеть».
## Сигнатура: хлёст плетью по чёткой линии. Мини-босс — 3 атаки, короче и мягче
## полноценных мировых боссов.


# ── Плеть: лезвие-хлыст по прямой ──
class Whip extends BossAttack:
    var _hard := false
    func _init(hard := false) -> void:
        _hard = hard
        name = "ПЛЕТЬ"
        rule = "хлыст бьёт по линии — сойди с неё"
    func start(arena) -> void:
        var b: Rect2 = arena.box
        var from_left := randf() < 0.5
        var y := randf_range(b.position.y + 16.0, b.end.y - 16.0)
        arena.spawn_shape(&"blade",
            Vector2(b.position.x - 10.0 if from_left else b.end.x + 10.0, y),
            Vector2((150.0 if from_left else -150.0), 0.0),
            {"size": Vector2(30, 8), "angle": (0.0 if from_left else PI),
             "warn": 0.42, "tint": Color("#c46a3a")})
    func update(_arena, _delta) -> void:
        if elapsed() >= (2.2 if _hard else 2.0):
            done = true


# ── Цепи: маятники с потолка, проход между ними ──
class Chains extends BossAttack:
    var _hard := false
    var _cd := 0.0
    func _init(hard := false) -> void:
        _hard = hard
        name = "ЦЕПИ"
        rule = "качаются цепи — проскочи в просвет"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.7, 1.0)
            var b: Rect2 = arena.box
            var n := 3 if _hard else 2
            var slot := b.size.x / float(n + 1)
            var skip := randi() % n           # один просвет гарантирован
            for i in range(n):
                if i == skip:
                    continue
                var x := b.position.x + slot * float(i + 1)
                arena.spawn_shape(&"segment", Vector2(x, b.position.y + 8.0),
                    Vector2(0, 60.0), {"size": Vector2(10, 40), "warn": 0.35,
                     "tint": Color("#8a7a5a")})
        if elapsed() >= (3.0 if _hard else 2.6):
            done = true


# ── Окрик «Смена не окончена!»: зона теснит в угол ──
class Shout extends BossAttack:
    var _fired := false
    func _init(_hard := false) -> void:
        name = "«СМЕНА НЕ ОКОНЧЕНА!»"
        rule = "оставлен один угол — беги туда"
    func update(arena, delta) -> void:
        if not _fired:
            _fired = true
            var b: Rect2 = arena.box
            var safe := 64.0
            var corner := randi() % 4
            var sx := b.position.x if corner in [0, 2] else b.end.x - safe
            var sy := b.position.y if corner in [0, 1] else b.end.y - safe
            arena.add_safe_zone(Rect2(sx, sy, safe, safe),
                {"warn": 0.55, "active": 0.9, "tint": Color("#e0a050")})
        if elapsed() >= 1.9:
            done = true


func opening() -> Array:
    return [[Whip.new()], [Chains.new()], [Shout.new()]]


func pick(stage: int, phase2: bool) -> Array:
    var solo := [Whip.new(phase2), Chains.new(phase2), Shout.new()]
    if phase2 and randf() < 0.4:
        return [Whip.new(true), Chains.new(true)]
    return [solo[randi() % solo.size()]]
