extends BossKit
class_name ZhizhaKit
## Великая Жижа — тема «живое болото / кислота, поглощает арену». Сигнатура:
## сжатие безопасного пространства. Кит: наступающая кислота, щупальца,
## кислотные капли, сжатие коробки, волна тины. Уникален.

const FULL_BOX := Rect2(222, 178, 196, 150)


# ── Наступающая кислота: опасная зона растёт от края внутрь ──
class AcidRise extends BossAttack:
    var _hard := false
    var _zone
    var _from_bottom := true
    func _init(hard := false) -> void:
        _hard = hard
        name = "НАСТУПАЮЩАЯ КИСЛОТА"
        rule = "кислота прибывает — уходи от края"
    func start(arena) -> void:
        _from_bottom = randf() < 0.6
        var b: Rect2 = arena.box
        if _from_bottom:
            _zone = arena.add_hazard_zone(Rect2(b.position.x, b.end.y - 6.0, b.size.x, 6.0),
                {"warn": 0.5, "active": 99.0, "tint": Color("#8ad24a")})
        else:
            _zone = arena.add_hazard_zone(Rect2(b.position.x, b.position.y, b.size.x, 6.0),
                {"warn": 0.5, "active": 99.0, "tint": Color("#8ad24a")})
    func update(arena, delta) -> void:
        if _zone != null:
            var grow: float = (26.0 if _hard else 18.0) * delta
            var b: Rect2 = arena.box
            var r: Rect2 = _zone.rect
            if _from_bottom:
                r.position.y -= grow
                r.size.y += grow
                r.position.y = maxf(r.position.y, b.position.y + b.size.y * 0.42)
            else:
                r.size.y += grow
                r.size.y = minf(r.size.y, b.size.y * 0.58)
            _zone.rect = r
        if elapsed() >= (3.6 if _hard else 3.0):
            if _zone != null:
                _zone.active = 0.0        # снять на следующем шаге зон
            done = true


# ── Щупальца: сегменты поднимаются с телеграфом ──
class Tentacles extends BossAttack:
    var _cd := 0.0
    var _hard := false
    func _init(hard := false) -> void:
        _hard = hard
        name = "ЩУПАЛЬЦА"
        rule = "щупальца встают из тины — отойди от корня"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.5, 0.75) if _hard else randf_range(0.75, 1.05)
            var b: Rect2 = arena.box
            var x := randf_range(b.position.x + 16.0, b.end.x - 16.0)
            var h := randf_range(46.0, b.size.y - 10.0)
            arena.spawn_shape(&"segment", Vector2(x, b.end.y - h * 0.5),
                Vector2(0, -14.0),
                {"size": Vector2(14, h), "warn": 0.45, "life": 1.4,
                 "tint": Color("#5a8a3a")})
        if elapsed() >= (3.4 if _hard else 2.8):
            done = true


# ── Кислотные капли: медленно падают, лопаются лужей ──
class Droplets extends BossAttack:
    var _cd := 0.0
    var _hard := false
    var _drops: Array = []
    func _init(hard := false) -> void:
        _hard = hard
        name = "КИСЛОТНЫЕ КАПЛИ"
        rule = "уходи из-под капель и их брызг"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.4, 0.6) if _hard else randf_range(0.6, 0.85)
            var b: Rect2 = arena.box
            var x := randf_range(b.position.x + 12.0, b.end.x - 12.0)
            var d: Dictionary = arena.spawn_shape(&"rect", Vector2(x, b.position.y - 12.0),
                Vector2(0, 74.0), {"size": Vector2(12, 14), "pierce": true,
                 "warn": 0.25, "tint": Color("#9ad84a")})
            _drops.append(d)
        var still: Array = []
        for d in _drops:
            if float(d.get("warn", 0.0)) <= 0.0 and d.pos.y >= arena.box.end.y - 14.0:
                arena.add_hazard_zone(Rect2(d.pos.x - 16.0, arena.box.end.y - 10.0, 32.0, 10.0),
                    {"warn": 0.0, "active": 0.5, "tint": Color("#8ad24a")})
                d.life = 0.001            # убрать каплю
            else:
                still.append(d)
        _drops = still
        if elapsed() >= (3.4 if _hard else 2.8):
            done = true


# ── Сжатие арены: коробка стягивается (поглощение пространства) ──
class Squeeze extends BossAttack:
    var _hard := false
    func _init(hard := false) -> void:
        _hard = hard
        name = "ПОГЛОЩЕНИЕ"
        rule = "болото жрёт арену — жмись к центру"
    func start(arena) -> void:
        var w := 108.0 if _hard else 132.0
        var h := 84.0 if _hard else 102.0
        arena.move_box(Rect2(320.0 - w * 0.5, 253.0 - h * 0.5, w, h), {"flash": 0.35, "speed": 3.5})
    func update(arena, delta) -> void:
        if elapsed() >= (3.6 if _hard else 3.0):
            arena.move_box(ZhizhaKit.FULL_BOX, {"flash": 0.25, "speed": 6.0})
            done = true


# ── Волна тины: широкая полоса проходит, безопасно только в разрыве ──
class SludgeWave extends BossAttack:
    var _hard := false
    var _fired := false
    func _init(hard := false) -> void:
        _hard = hard
        name = "ВОЛНА ТИНЫ"
        rule = "встань в чистый разрыв, пока проходит волна"
    func update(arena, delta) -> void:
        if not _fired:
            _fired = true
            var b: Rect2 = arena.box
            var gap_w := 46.0 if _hard else 60.0
            var gx := randf_range(b.position.x + 8.0, b.end.x - gap_w - 8.0)
            arena.add_safe_zone(Rect2(gx, b.position.y, gap_w, b.size.y),
                {"warn": 0.6, "active": (1.0 if _hard else 0.85), "tint": Color("#6ee66e")})
        if elapsed() >= (2.0 if _hard else 1.8):
            done = true


func opening() -> Array:
    return [[AcidRise.new()], [Tentacles.new()], [Squeeze.new()], [SludgeWave.new()]]


func pick(stage: int, phase2: bool) -> Array:
    if not phase2:
        var solo := [AcidRise.new(), Tentacles.new(), Droplets.new(), SludgeWave.new()]
        return [solo[randi() % solo.size()]]
    var combos := [
        [AcidRise.new(true), Tentacles.new(true)],
        [Droplets.new(true), Tentacles.new(true)],
        [Squeeze.new(true), Droplets.new(true)],
    ]
    if randf() < 0.3:
        return [SludgeWave.new(true)]
    return combos[randi() % combos.size()]
