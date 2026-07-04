extends BossKit
class_name KalitinKit
## Калитин — тема «компьютерное железо / техник-мастер». Сигнатура: ветер
## вентиляторов, сносящий сердце. Все атаки — из мира ПК: кулеры, планки ОЗУ,
## скачки напряжения, кабели. Ни одна не встречается у других боссов.

const FULL_BOX := Rect2(222, 178, 196, 150)


# ── Вентиляторы + планки ОЗУ (сигнатурная, комбо средой+фигурой) ──
class FansRam extends BossAttack:
    var _cd := 0.0
    var _hard := false
    var _side := 1
    func _init(hard := false) -> void:
        _hard = hard
        name = "ВЕНТИЛЯТОРЫ+ОЗУ"
        rule = "греби против ветра, огибай планки"
    func start(arena) -> void:
        _side = 1 if randf() < 0.5 else -1
        _add_force(arena, &"wind", {"dir": Vector2(_side * (78.0 if _hard else 62.0), 0.0),
            "gust": Vector2(_side * 22.0, 0.0)})
        if _hard:
            _add_force(arena, &"wind", {"dir": Vector2(0.0, 18.0), "gust": Vector2(0.0, 16.0)})
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.42, 0.66) if _hard else randf_range(0.6, 0.85)
            var b: Rect2 = arena.box
            var from_left := randf() < 0.5
            var y := randf_range(b.position.y + 18.0, b.end.y - 18.0)
            var sx: float = b.position.x - 22.0 if from_left else b.end.x + 22.0
            var vx := (128.0 if from_left else -128.0)
            arena.spawn_shape(&"rect", Vector2(sx, y), Vector2(vx, 0.0),
                {"size": Vector2(28, 12), "warn": 0.26, "tint": Color("#6fce9a")})
        if elapsed() >= (3.6 if _hard else 3.0):
            done = true


# ── Перегрев: троттлинг — коробка сжимается, края пышут жаром ──
class Overheat extends BossAttack:
    var _hard := false
    func _init(hard := false) -> void:
        _hard = hard
        name = "ПЕРЕГРЕВ"
        rule = "место сжимается — ищи центр"
    func start(arena) -> void:
        var w := 118.0 if _hard else 138.0
        arena.move_box(Rect2(320.0 - w * 0.5, 253.0 - 46.0, w, 92.0), {"flash": 0.35, "speed": 6.0})
    func update(arena, delta) -> void:
        # редкие искры-разряды по краям сжатой зоны
        if elapsed() >= (3.4 if _hard else 2.8):
            arena.move_box(KalitinKit.FULL_BOX, {"flash": 0.25, "speed": 7.0})
            done = true


# ── Скачки напряжения: тонкие разряды с резким телеграфом (ритм) ──
class VoltageSurges extends BossAttack:
    var _cd := 0.0
    var _hard := false
    func _init(hard := false) -> void:
        _hard = hard
        name = "СКАЧКИ НАПРЯЖЕНИЯ"
        rule = "разряды бьют по полосам — лови паузу"
    func update(arena, delta) -> void:
        _cd -= delta
        if _cd <= 0.0:
            _cd = randf_range(0.34, 0.5) if _hard else randf_range(0.5, 0.72)
            var b: Rect2 = arena.box
            if randi() % 2 == 0:
                var ly := randf_range(b.position.y + 8.0, b.end.y - 26.0)
                arena.add_hazard_zone(Rect2(b.position.x, ly, b.size.x, 18.0),
                    {"warn": 0.24, "active": 0.22, "tint": Color("#ffe14a")})
            else:
                var lx := randf_range(b.position.x + 8.0, b.end.x - 26.0)
                arena.add_hazard_zone(Rect2(lx, b.position.y, 18.0, b.size.y),
                    {"warn": 0.24, "active": 0.22, "tint": Color("#ffe14a")})
        if elapsed() >= (3.4 if _hard else 2.8):
            done = true


# ── Кабельный хлыст: вращающееся лезвие-кабель от пивота ──
class CableWhip extends BossAttack:
    var _hard := false
    var _blade
    func _init(hard := false) -> void:
        _hard = hard
        name = "КАБЕЛЬНЫЙ ХЛЫСТ"
        rule = "обойди дугу по радиусу"
    func start(arena) -> void:
        var b: Rect2 = arena.box
        var pivot := Vector2(b.get_center().x, b.position.y - 6.0)
        var spin := (2.4 if _hard else 1.8) * (1.0 if randf() < 0.5 else -1.0)
        # короче и живёт меньше (не проходит пол-экрана); направление вращения
        # подсказывает еле заметная дуга-стрелка у пивота (рисует BulletKit)
        _blade = arena.spawn_shape(&"blade", pivot, Vector2.ZERO,
            {"size": Vector2(b.size.y * 0.78, 9.0), "angle": PI * 0.5,
             "spin": spin, "warn": 0.4, "life": (2.6 if _hard else 2.0),
             "tint": Color("#d0d6e0")})
    func update(arena, delta) -> void:
        if _blade != null and _blade.get("life", 1.0) <= 0.0:
            done = true
        if elapsed() >= 4.0:
            done = true


func opening() -> Array:
    return [[FansRam.new()], [VoltageSurges.new()], [CableWhip.new()], [FansRam.new(), VoltageSurges.new()]]


func pick(stage: int, phase2: bool) -> Array:
    if not phase2:
        var solo := [FansRam.new(), VoltageSurges.new(), CableWhip.new(), Overheat.new()]
        return [solo[randi() % solo.size()]]
    # фаза ярости: свои механики комбинируются и жёстче
    var combos := [
        [FansRam.new(true), VoltageSurges.new(true)],
        [Overheat.new(true), CableWhip.new(true)],
        [FansRam.new(true), CableWhip.new(true)],
    ]
    if randf() < 0.3:
        return [FansRam.new(true)]
    return combos[randi() % combos.size()]
