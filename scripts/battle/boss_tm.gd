extends BossKit
class_name TmKit
## ТМ (финальный босс Адской Шахты, каждые 25 этажей) — тема «тьма/безмолвие/
## четыре глаза». Сигнатура: четыре сметающих взгляда-лезвия из углов, оставляющих
## центр. Плюс сгущение тьмы (сжатие арены) и одно слово «тм».

const FULL_BOX := Rect2(222, 178, 196, 150)


# ── Четыре глаза: 4 лезвия-взгляда крутятся из углов, центр остаётся ──
class FourEyes extends BossAttack:
    var _hard := false
    var _blades: Array = []
    func _init(hard := false) -> void:
        _hard = hard
        name = "ЧЕТЫРЕ ГЛАЗА"
        rule = "взгляды метут от углов — держи центр"
    func start(arena) -> void:
        var b: Rect2 = arena.box
        var corners := [b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]
        var base := [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]
        var spin := (1.4 if _hard else 1.0)
        var reach := b.size.length() * 0.42
        for i in range(4):
            var bl = arena.spawn_shape(&"blade", corners[i], Vector2.ZERO,
                {"size": Vector2(reach, 8.0), "angle": base[i], "spin": spin,
                 "warn": 0.5, "life": (3.6 if _hard else 3.0), "tint": Color("#8a6ad0")})
            _blades.append(bl)
    func update(_arena, _delta) -> void:
        if elapsed() >= (3.8 if _hard else 3.2):
            done = true


# ── Тьма сгущается: арена медленно стягивается ──
class DarkClose extends BossAttack:
    var _hard := false
    func _init(hard := false) -> void:
        _hard = hard
        name = "ТЬМА СГУЩАЕТСЯ"
        rule = "тьма съедает края — не отставай от света"
    func start(arena) -> void:
        var w := 104.0 if _hard else 128.0
        var h := 80.0 if _hard else 98.0
        arena.move_box(Rect2(320.0 - w * 0.5, 253.0 - h * 0.5, w, h),
            {"flash": 0.35, "speed": (4.0 if _hard else 2.8)})
    func update(arena, delta) -> void:
        if elapsed() >= (3.6 if _hard else 3.0):
            arena.move_box(TmKit.FULL_BOX, {"flash": 0.25, "speed": 6.0})
            done = true


# ── «тм.»: одно широкое лезвие через всю ширину, долгий честный телеграф ──
class TmWord extends BossAttack:
    var _hard := false
    var _fired := false
    func _init(hard := false) -> void:
        _hard = hard
        name = "«тм.»"
        rule = "медленная плита — уйди в оставленный край"
    func update(arena, delta) -> void:
        if not _fired:
            _fired = true
            var b: Rect2 = arena.box
            var top := randf() < 0.5
            arena.spawn_shape(&"segment",
                Vector2(b.get_center().x, b.position.y - 18.0 if top else b.end.y + 18.0),
                Vector2(0, (54.0 if top else -54.0)),
                {"size": Vector2(b.size.x - 40.0, 22.0), "warn": (0.7 if _hard else 0.85),
                 "tint": Color("#2a2038")})
        if elapsed() >= (3.0 if _hard else 2.6):
            done = true


func opening() -> Array:
    return [[FourEyes.new()], [DarkClose.new()], [TmWord.new()]]


func pick(stage: int, phase2: bool) -> Array:
    if not phase2:
        var solo := [FourEyes.new(), DarkClose.new(), TmWord.new()]
        return [solo[randi() % solo.size()]]
    var combos := [
        [FourEyes.new(true), TmWord.new(true)],
        [DarkClose.new(true), TmWord.new(true)],
    ]
    if randf() < 0.3:
        return [FourEyes.new(true)]
    return combos[randi() % combos.size()]
