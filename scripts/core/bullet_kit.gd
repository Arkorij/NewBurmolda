extends RefCounted
class_name BulletKit
## Тулкит НИЗКОУРОВНЕВЫХ примитивов буллет-хелла (не готовые атаки!).
## Работает НАД состоянием арены (battle_scene) — тот же паттерн, что Sprites:
## каждая функция принимает `arena` как контекст и читает/пишет его поля
## (bullets/zones/forces/box/soul). Авторы атак (BossKit/MobThreats) собирают
## угрозы ТОЛЬКО через эти фабрики — прямого draw_circle/bullets.append в атаках нет.
##
## Гарантии, которые примитивы обеспечивают сами (атаки на них полагаются):
##  • честный телеграф: угроза с warn>0 безвредна и визуально помечена;
##  • централизованный урон: попадание зовёт arena._bullet_hit() (уворот/броня);
##  • авто-очистка: фигуры — по выходу за коробку/жизни, зоны/поля — по таймерам;
##  • достижимость: clamp_step() не даёт «телепорта» безопасных точек.
##
## Виды фигур (узнаваемый силуэт, НЕ «кружок по цвету-скорости»):
##   &"rect"    планка   — прямоугольник, летит/висит
##   &"blade"   лезвие   — тонкая пластина от пивота наружу (можно вращать spin)
##   &"segment" сегмент  — кусок стены (толстый прямоугольник)
##   &"spinner" вертушка — крутящаяся полоса вокруг центра

const GRAZE_R := 13.0


# ─────────────── ФИГУРНЫЕ УГРОЗЫ ───────────────
static func spawn_shape(arena, shape: StringName, pos: Vector2, vel: Vector2,
        opts: Dictionary = {}) -> Dictionary:
    ## Заспавнить фигуру. Возвращает её Dictionary — храни ссылку для update().
    var size: Vector2 = opts.get("size", Vector2(24, 8))
    var warn: float = float(opts.get("warn", 0.0)) * arena.warn_mult
    var s := {
        "shape": shape,
        "pos": pos,
        "vel": vel * arena.speed_mult,
        "accel": opts.get("accel", Vector2.ZERO),
        "angle": float(opts.get("angle", 0.0)),
        "spin": float(opts.get("spin", 0.0)),
        "half": size * 0.5,
        "warn": warn,
        "warn0": maxf(warn, 0.0001),
        "safe": bool(opts.get("safe", false)),
        "pierce": bool(opts.get("pierce", false)),
        "tint": opts.get("tint", Color("#e8e8f4")),
        "life": float(opts.get("life", 0.0)),   # >0 → живёт столько секунд (для вертушек/хлыстов)
        "grz": false,
    }
    arena.bullets.append(s)
    return s


static func _shape_center(s: Dictionary) -> Vector2:
    if s.shape == &"blade":
        return s.pos + Vector2.from_angle(s.angle) * s.half.x
    return s.pos


static func _orect_hit(center: Vector2, half: Vector2, angle: float,
        point: Vector2, r: float) -> bool:
    ## Точка (с радиусом r) внутри ориентированного прямоугольника?
    var local := (point - center).rotated(-angle)
    return absf(local.x) <= half.x + r and absf(local.y) <= half.y + r


static func _orect_corners(center: Vector2, half: Vector2, angle: float) -> PackedVector2Array:
    var c := Vector2(cos(angle), sin(angle))
    var ax := c * half.x
    var ay := c.orthogonal() * half.y
    return PackedVector2Array([
        center - ax - ay, center + ax - ay, center + ax + ay, center - ax + ay])


static func step_hazards(arena, delta: float) -> void:
    ## Двинуть фигуры и зоны, проверить попадания. Зовётся ПОСЛЕ клампа души,
    ## чтобы столкновение считалось по актуальной позиции сердца.
    var r: float = arena._hit_r
    var core: Vector2 = arena.soul
    # ── фигуры ──
    var alive: Array = []
    for s in arena.bullets:
        var warn: float = s.warn
        if warn > 0.0:                       # телеграф: неподвижна и безвредна
            s.warn = warn - delta
            alive.append(s)
            continue
        s.vel += s.accel * delta
        s.pos += s.vel * delta
        s.angle += s.spin * delta
        if s.life > 0.0:
            s.life -= delta
            if s.life <= 0.0:
                continue
        var center := _shape_center(s)
        var is_round: bool = s.shape == &"orb" or s.shape == &"cross"   # круглый хитбокс
        var hit := false
        if arena._iframe <= 0.0 and not s.safe:
            if is_round:
                hit = center.distance_to(core) < s.half.x + r
            else:
                hit = _orect_hit(center, s.half, s.angle, core, r)
        if hit:
            arena._bullet_hit()
        else:
            # грейз (впритирку) — искры и лёгкая дрожь, только для настоящих угроз
            var grazed: bool = center.distance_to(core) < s.half.x + GRAZE_R if is_round \
                    else _orect_hit(center, s.half, s.angle, core, GRAZE_R)
            if not s.safe and not s.grz and grazed:
                s.grz = true
                arena._graze_t = 0.3
                arena._shake = maxf(arena._shake, 1.4)
                arena._spark_burst(center, 2, Color("#b8f0ff"))
            # авто-очистка: по жизни (если задана) или по выходу за коробку
            if s.life > 0.0:
                alive.append(s)
            else:
                var margin := 220.0 if s.pierce else 60.0
                if arena.box.grow(margin).has_point(s.pos):
                    alive.append(s)
    arena.bullets = alive
    step_zones(arena, delta)


static func step_zones(arena, delta: float) -> void:
    var r: float = arena._hit_r
    var core: Vector2 = arena.soul
    var zalive: Array = []
    for z in arena.zones:
        var warn: float = z.warn
        var active: float = z.active
        var was_warn: bool = z.t < warn
        z.t += delta
        if was_warn and z.t >= warn:         # момент «выстрела»
            arena._shake = maxf(arena._shake, 2.4)
            arena._spark_burst(z.rect.get_center(), 5, z.get("tint", Color("#ffb060")))
        if z.t >= warn + active:
            continue                          # отыграла — снять
        if z.t >= warn and arena._iframe <= 0.0:
            var soul_r := Rect2(core.x - r * 0.5, core.y - r * 0.5, r, r)
            var danger: bool
            if z.get("safe_inside", false):   # безопасная зона: бьёт СНАРУЖИ rect
                danger = not z.rect.grow(-r).has_point(core)
            else:                             # опасная зона: бьёт ВНУТРИ rect
                danger = z.rect.intersects(soul_r)
            if danger:
                arena._bullet_hit()
        zalive.append(z)
    arena.zones = zalive


# ─────────────── СИЛОВЫЕ ПОЛЯ (двигают само сердце) ───────────────
static func add_force(arena, kind: StringName, opts: Dictionary = {}) -> int:
    var id: int = arena._force_seq
    arena._force_seq = id + 1
    arena.forces.append({
        "id": id, "kind": kind,
        "dir": opts.get("dir", Vector2.ZERO),
        "point": opts.get("point", arena.box.get_center()),
        "strength": float(opts.get("strength", 90.0)),
        "rect": opts.get("rect", Rect2()),
        "has_rect": opts.has("rect"),
        "gust": opts.get("gust", Vector2.ZERO),
        "t": 0.0,
    })
    return id


static func remove_force(arena, id: int) -> void:
    var keep: Array = []
    for f in arena.forces:
        if f.id != id:
            keep.append(f)
    arena.forces = keep


static func step_forces(arena, delta: float) -> void:
    ## Применить поля к arena.soul. Зовётся МЕЖДУ движением от ввода и клампом.
    for f in arena.forces:
        f.t += delta
        if f.has_rect and not f.rect.has_point(arena.soul):
            continue
        match f.kind:
            &"wind", &"conveyor":
                var push: Vector2 = f.dir + f.gust * sin(f.t * 4.0)
                arena.soul += push * delta
            &"vacuum":
                var to: Vector2 = f.point - arena.soul
                if to.length() > 2.0:
                    arena.soul += to.normalized() * f.strength * delta
            &"turbulence":
                arena.soul += Vector2(randf_range(-1, 1), randf_range(-1, 1)) \
                        * f.strength * delta


# ─────────────── ТАЙМИНГОВЫЕ ЗОНЫ ───────────────
static func add_hazard_zone(arena, rect: Rect2, opts: Dictionary = {}) -> Dictionary:
    var z := {
        "rect": rect, "t": 0.0,
        "warn": float(opts.get("warn", 0.45)) * arena.warn_mult,
        "active": float(opts.get("active", 0.3)),
        "tint": opts.get("tint", Color("#ff5a3a")),
        "safe_inside": false,
    }
    arena.zones.append(z)
    return z


static func add_safe_zone(arena, rect: Rect2, opts: Dictionary = {}) -> Dictionary:
    ## Внутри rect безопасно, снаружи (в коробке) бьёт — после телеграфа.
    var z := {
        "rect": rect, "t": 0.0,
        "warn": float(opts.get("warn", 0.55)) * arena.warn_mult,
        "active": float(opts.get("active", 0.7)),
        "tint": opts.get("tint", Color("#6ee66e")),
        "safe_inside": true,
    }
    arena.zones.append(z)
    return z


# ─────────────── УПРАВЛЕНИЕ АРЕНОЙ ───────────────
static func set_corridor(arena, rect: Rect2, _opts: Dictionary = {}) -> void:
    ## Запереть душу в коридор (жёсткие стены, без урона). Пустой rect — снять.
    arena.corridor = rect
    arena.has_corridor = rect.size.x > 1.0 and rect.size.y > 1.0


static func set_blue_mode(arena, on: bool) -> void:
    arena.soul_mode = "blue" if on else "free"
    if on:
        arena.soul_vel = Vector2.ZERO


static func move_box(arena, target: Rect2, opts: Dictionary = {}) -> void:
    arena.box_target = target
    arena._box_flash = float(opts.get("flash", 0.35))
    arena._box_lerp = float(opts.get("speed", 9.0))


# ─────────────── ДОСТИЖИМОСТЬ ───────────────
static func clamp_step(prev: float, target: float, max_step: float) -> float:
    ## Шаг к target не дальше max_step — безопасная точка/щель не «телепортируется».
    return prev + clampf(target - prev, -max_step, max_step)


# ─────────────── ОТРИСОВКА (делегируется из arena._draw) ───────────────
static func draw_all(arena) -> void:
    _draw_field(arena)
    _draw_zones(arena)
    _draw_shapes(arena)


static func _draw_field(arena) -> void:
    for f in arena.forces:
        match f.kind:
            &"wind", &"conveyor":
                var d: Vector2 = f.dir
                if d.length() < 1.0:
                    continue
                var dir := d.normalized()
                var fb: Rect2 = arena.box
                for i in range(5):
                    var base := fb.position + Vector2(
                        fmod(f.t * 120.0 + i * 53.0, fb.size.x),
                        14.0 + i * (fb.size.y - 20.0) / 4.0)
                    arena.draw_line(base, base + dir * 16.0, Color("#8fd8e8", 0.45), 2.0)
            &"vacuum":
                var vp: Vector2 = f.point
                for k in range(3):
                    var rad := 12.0 + fmod(f.t * 40.0 + k * 22.0, 66.0)
                    arena.draw_arc(vp, rad, 0, TAU, 20, Color("#b6a6ff", 0.35), 1.5)
                arena.draw_circle(vp, 3.0, Color("#d8ccff", 0.8))
            &"turbulence":
                var tb: Rect2 = arena.box
                for k in range(10):
                    var p := tb.position + Vector2(
                        randf() * tb.size.x, randf() * tb.size.y)
                    arena.draw_rect(Rect2(p.x, p.y, 2, 2), Color("#c8e0ff", 0.25), true)
    if arena.has_corridor:
        # затемнить всё вне коридора + яркая рамка коридора
        var b: Rect2 = arena.box
        var c: Rect2 = arena.corridor
        arena.draw_rect(Rect2(b.position.x, b.position.y, b.size.x, c.position.y - b.position.y),
                Color("#101018", 0.55), true)
        arena.draw_rect(Rect2(b.position.x, c.end.y, b.size.x, b.end.y - c.end.y),
                Color("#101018", 0.55), true)
        arena.draw_rect(Rect2(b.position.x, c.position.y, c.position.x - b.position.x, c.size.y),
                Color("#101018", 0.55), true)
        arena.draw_rect(Rect2(c.end.x, c.position.y, b.end.x - c.end.x, c.size.y),
                Color("#101018", 0.55), true)
        arena.draw_rect(c, Color("#8fd8e8", 0.8), false, 2.0)


static func _draw_zones(arena) -> void:
    for z in arena.zones:
        var warn: float = z.warn
        var tint: Color = z.get("tint", Color("#ff5a3a"))
        if z.get("safe_inside", false):
            # безопасная зона: подсветить безопасный прямоугольник, вокруг — опасность
            if z.t < warn:
                var a: float = 0.12 + 0.2 * (z.t / warn)
                arena.draw_rect(arena.box, Color(tint.darkened(0.2), a * 0.5), true)
                arena.draw_rect(z.rect, Color("#101018", 0.6), true)
                arena.draw_rect(z.rect, Color(tint, 0.9), false, 2.0)
            else:
                arena.draw_rect(z.rect, Color(tint, 0.22), true)
                arena.draw_rect(z.rect, Color(tint, 0.95), false, 2.0)
            continue
        if z.t < warn:
            var a2: float = 0.15 + 0.25 * (z.t / warn) * (0.5 + 0.5 * sin(z.t * 24.0))
            arena.draw_rect(z.rect, Color(tint, a2), true)
            arena.draw_rect(z.rect, Color(tint, 0.8), false, 1.0)
        else:
            arena.draw_rect(z.rect, Color("#fff0d0", 0.95), true)
            arena.draw_rect(z.rect.grow(2), Color(tint, 0.6), false, 2.0)


static func _draw_shapes(arena) -> void:
    for s in arena.bullets:
        var center := _shape_center(s)
        var tint: Color = s.get("tint", Color("#e8e8f4"))
        var warn: float = s.warn
        if s.safe:                                   # обманка — зелёный контур
            var pts0 := _orect_corners(center, s.half, s.angle)
            arena.draw_polyline(_closed(pts0), Color("#6ee66e", 0.9), 1.6)
            continue
        if s.shape == &"orb":                        # круглая пуля (моб-буллетхелл)
            var rad: float = s.half.x
            if warn > 0.0:
                arena.draw_arc(center, rad + 1.5, 0, TAU, 12,
                    Color(tint, 0.4 + 0.4 * sin((float(s.warn0) - warn) * 22.0)), 1.5)
            else:
                arena.draw_circle(center, rad, tint)
                arena.draw_circle(center, rad * 0.45, tint.darkened(0.4))
            continue
        if s.shape == &"cross":                      # летающий крест (моб-буллетхелл)
            var arm: float = s.half.x * 1.9          # визуальные лучи длиннее хитбокса
            var cd := Vector2.from_angle(s.angle)
            var cp := cd.orthogonal()
            var ca: float = 1.0
            if warn > 0.0:
                ca = 0.35 + 0.35 * sin((float(s.warn0) - warn) * 22.0)
            arena.draw_line(center - cd * arm, center + cd * arm, Color(tint, ca), 3.0)
            arena.draw_line(center - cp * arm, center + cp * arm, Color(tint, ca), 3.0)
            if warn <= 0.0:
                arena.draw_circle(center, 1.6, tint.lightened(0.4))
            continue
        if warn > 0.0:                               # телеграф — призрак фигуры
            var a: float = 0.25 + 0.35 * (1.0 - warn / float(s.warn0)) \
                    * (0.5 + 0.5 * sin((float(s.warn0) - warn) * 22.0))
            var ptsw := _orect_corners(center, s.half, s.angle)
            arena.draw_colored_polygon(ptsw, Color(tint, a * 0.5))
            arena.draw_polyline(_closed(ptsw), Color(tint, minf(a + 0.3, 0.95)), 1.5)
            continue
        var pts := _orect_corners(center, s.half, s.angle)
        arena.draw_colored_polygon(pts, tint)
        match s.shape:
            &"blade":                                # лезвие — светлая режущая кромка
                arena.draw_line(pts[1], pts[2], tint.lightened(0.5), 2.0)
            &"spinner":                              # вертушка — ступица в центре
                arena.draw_circle(center, 3.0, tint.darkened(0.35))
            &"segment":                              # сегмент стены — тёмная окантовка
                arena.draw_polyline(_closed(pts), tint.darkened(0.4), 1.5)
            _:                                       # планка — заклёпки по краям
                arena.draw_circle(pts[0].lerp(pts[3], 0.5), 1.6, tint.darkened(0.4))
                arena.draw_circle(pts[1].lerp(pts[2], 0.5), 1.6, tint.darkened(0.4))


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
    var out := PackedVector2Array(pts)
    out.append(pts[0])
    return out
