extends Control
## Бой в стиле Undertale: меню БОЙ/ДЕЙСТВИЕ/ПРЕДМЕТ/МИЛОСТЬ, ход врага = bullet-hell.
## Модель боя — Battle (core/battle.gd). Приёмы — Attacks. Кольца/крит — внутри Battle.
## Задать до add_child: enemy=[имя,hp,dmg] ИЛИ boss_key, и danger.

signal battle_over(result: String)     # "win" | "lose" | "flee"

var enemy = null
var boss_key = null
var danger := 1
var biome := ""      # биом локации — влияет на физику уворота ("" = без эффекта)

enum Phase { MESSAGE, MENU, SUB, BULLETS, DONE }
var phase: int = Phase.MESSAGE

var battle: Battle
var player: Player

# UI
var enemy_label: Label
var enemy_box: ColorRect
var hp_bg: ColorRect
var hp_fg: ColorRect
var log_label: Label
var stat_label: Label
var hint_label: Label
var main_menu: SoulMenu
var sub_menu: SoulMenu

# печатная машинка
var _full := ""
var _reveal := 0.0
var _after: Callable = Callable()

# подменю
var _sub_kind := ""
var _fight_ids: Array = []
var _item_keys: Array = []

# bullet-hell
var box := Rect2(222, 178, 196, 150)
var box_target := Rect2(222, 178, 196, 150)   # коробка «дышит» — плавно меняет размер
var soul := Vector2.ZERO
var soul_vel := Vector2.ZERO     # инерция души (для скользких биомов)
var bullets: Array = []          # {pos, vel, kind, cls}  (cls: 0 медл/1 обыч/2 быстр)
var zones: Array = []            # лазеры: {rect, t}   (t<WARN — телеграф, потом бьёт)
var active: Array = []           # активные паттерны: [{pat, cd}] — до 2 одновременно!
var _seg_t := 0.0                # таймер смены набора атак внутри фазы
var wind := Vector2.ZERO         # шквал Цизи — сносит душу
var _wind_t := 0.0
var _emit_a := 0.0               # угол спирали
var _bh_t := 0.0
var _bh_dur := 4.2
var _iframe := 0.0
var _shake := 0.0                # тряска экрана при уроне
var _evade_t := 0.0              # вспышка «уворот!»
const SOUL_SPEED := 150.0
const SOUL_SIZE := 10.0
const LASER_WARN := 0.8          # телеграф луча
const LASER_ACTIVE := 0.35       # сколько луч жжёт

# имена паттернов (показываются игроку)
const PATTERN_NAMES := {
    "aimed": "РОЙ", "rain": "ЛИВЕНЬ", "walls": "КОСТИ", "spiral": "ВИХРЬ",
    "homing": "ПРЕСЛЕДОВАТЕЛИ", "wind": "ШКВАЛ", "laser": "ЛУЧИ",
}
# цвет пули = её скорость: голубая медленная, жёлтая обычная, красная быстрая
const SPEED_COL := {0: Color("#7ae0ff"), 1: Color("#fff0a0"), 2: Color("#ff7a5a")}
# у каждого ВИДА моба свой стиль атак (по ключу спрайта)
const MOB_STYLE := {
    "komar": ["aimed", "spiral"], "bee": ["aimed", "spiral"], "flyer": ["aimed", "spiral"],
    "kostyashka": ["walls", "aimed"], "skel_boy": ["walls", "rain"], "skel_girl": ["walls", "spiral"],
    "sliz": ["rain", "homing"], "zhaba": ["rain", "aimed"], "meduza": ["rain", "homing"],
    "ghost": ["homing", "spiral"], "ventil": ["wind", "aimed"], "pauk": ["walls", "rain"],
    "mushroom": ["spiral", "rain"], "zmey": ["spiral", "aimed"], "leech": ["aimed", "rain"],
    "snowman": ["rain", "laser"], "singer": ["laser", "spiral"], "liana": ["walls", "spiral"],
    "wolf": ["aimed", "rain"], "kaban": ["aimed", "walls"], "krysa": ["aimed", "rain"],
    "fish": ["rain", "aimed"], "kirpich": ["walls", "rain"], "thug": ["aimed", "walls"],
    "mutant": ["homing", "aimed"], "imp": ["spiral", "laser"], "eldritch": ["homing", "laser"],
    # обитатели Адской Шахты
    "ash_bug": ["walls", "rain"], "ember": ["spiral", "aimed"], "magma_crab": ["walls", "aimed"],
    "shade": ["homing", "spiral"], "lava_fish": ["rain", "spiral"],
    "overseer": ["walls", "laser"], "pekl_master": ["laser", "spiral"], "tm": ["homing", "laser"],
}


func _ready() -> void:
    player = GameState.player
    battle = Battle.new(player, boss_key, enemy, danger)
    _build_ui()
    _refresh_stats()
    set_process_unhandled_input(true)
    _show_lines(["Тебе преградил путь %s!" % battle.ename], _to_menu)


# ─────────────── UI ───────────────
func _build_ui() -> void:
    enemy_label = _label("", 20, Vector2(0, 26), 640, HORIZONTAL_ALIGNMENT_CENTER)

    hp_bg = ColorRect.new()
    hp_bg.color = Color("#3a0d0d")
    hp_bg.position = Vector2(220, 150)
    hp_bg.size = Vector2(200, 12)
    add_child(hp_bg)
    hp_fg = ColorRect.new()
    hp_fg.color = Color("#e24b4a")
    hp_fg.position = Vector2(220, 150)
    hp_fg.size = Vector2(200, 12)
    add_child(hp_fg)

    log_label = _label("", 15, Vector2(48, 188), 544, HORIZONTAL_ALIGNMENT_LEFT)
    log_label.size = Vector2(544, 200)
    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    stat_label = _label("", 14, Vector2(48, 410), 544, HORIZONTAL_ALIGNMENT_LEFT)
    hint_label = _label("", 13, Vector2(0, 456), 626, HORIZONTAL_ALIGNMENT_RIGHT)
    hint_label.add_theme_color_override("font_color", Color("#6a6a80"))

    main_menu = SoulMenu.new()
    main_menu.position = Vector2(70, 438)
    main_menu.col_w = 138
    add_child(main_menu)
    main_menu.chosen.connect(_on_main)

    sub_menu = SoulMenu.new()
    sub_menu.position = Vector2(64, 188)
    add_child(sub_menu)
    sub_menu.chosen.connect(_on_sub)
    sub_menu.cancelled.connect(_to_menu)
    sub_menu.hide_menu()


func _label(txt: String, sz: int, pos: Vector2, w: int, align: int) -> Label:
    var l := Label.new()
    l.text = txt
    l.position = pos
    l.size = Vector2(w, 24)
    l.add_theme_font_size_override("font_size", sz)
    l.horizontal_alignment = align
    add_child(l)
    return l


func _refresh_stats() -> void:
    enemy_label.text = "%s   HP %d/%d" % [battle.ename, max(0, battle.enemy_hp), battle.enemy_max]
    var ratio: float = clampf(float(battle.enemy_hp) / float(max(1, battle.enemy_max)), 0.0, 1.0)
    hp_fg.size = Vector2(200.0 * ratio, 12)
    stat_label.text = "%s   ♥ %d/%d    ⛃ %d бурмолды   ур.%d" % [
        player.pname, player.hp, player.max_hp, player.burmolda, player.level]


# ─────────────── печать сообщений ───────────────
func _show_lines(lines: Array, after: Callable) -> void:
    _full = "\n".join(lines)
    log_label.text = _full
    log_label.visible = true
    log_label.visible_characters = 0
    _reveal = 0.0
    _after = after
    phase = Phase.MESSAGE
    main_menu.hide_menu()
    sub_menu.hide_menu()
    hint_label.text = "▼ ENTER"
    queue_redraw()


func _advance_message() -> void:
    if log_label.visible_characters != -1 and log_label.visible_characters < _full.length():
        log_label.visible_characters = -1
        return
    var cb := _after
    _after = Callable()
    hint_label.text = ""
    if cb.is_valid():
        cb.call()


# ─────────────── меню ───────────────
func _to_menu() -> void:
    phase = Phase.MENU
    sub_menu.hide_menu()
    log_label.visible = true
    main_menu.setup(["БОЙ", "ДЕЙСТВИЕ", "ПРЕДМЕТ", "МИЛОСТЬ"], true)
    hint_label.text = "← → выбор · ENTER"
    queue_redraw()


func _on_main(i: int) -> void:
    if phase != Phase.MENU:
        return
    match i:
        0: _open_fight()
        1: _open_act()
        2: _open_item()
        3: _flee()


func _open_fight() -> void:
    _sub_kind = "fight"
    _fight_ids = []
    var names: Array = []
    for a in Attacks.available(player):
        names.append(a["name"])
        _fight_ids.append(a["id"])
    main_menu.hide_menu()
    log_label.visible = false
    sub_menu.setup(names)
    phase = Phase.SUB
    hint_label.text = "↑ ↓ · ENTER · ESC назад"


func _open_item() -> void:
    _sub_kind = "item"
    _item_keys = []
    var names: Array = []
    for opt in battle.heal_options():
        _item_keys.append(opt[0])
        names.append(opt[1])
    main_menu.hide_menu()
    log_label.visible = false
    sub_menu.setup(names)
    phase = Phase.SUB
    hint_label.text = "↑ ↓ · ENTER · ESC назад"


func _open_act() -> void:
    _sub_kind = "act"
    var names: Array = ["Осмотреть врага"]
    if boss_key == "kalitin":
        names.append("Достать паяльник и термофен")
    main_menu.hide_menu()
    log_label.visible = false
    sub_menu.setup(names)
    phase = Phase.SUB
    hint_label.text = "↑ ↓ · ENTER · ESC назад"


func _on_sub(i: int) -> void:
    if phase != Phase.SUB:
        return
    match _sub_kind:
        "fight":
            Sfx.play("hit")
            _resolve_action(Attacks.execute(_fight_ids[i], battle))
        "item":
            _resolve_action(battle.use_item(_item_keys[i]))
        "act":
            if i == 0:
                _show_lines(["%s: HP %d, злобность %d." % [battle.ename, battle.enemy_hp, battle.edmg],
                             "Пахнет кринжом и мокрой шерстью."], _enemy_phase)
            else:
                _resolve_action(battle.kalitin_fear())


func _resolve_action(msgs: Array) -> void:
    _show_lines(msgs, _after_player)


func _after_player() -> void:
    if not battle.enemy_alive():
        _victory()
    else:
        _enemy_phase()


# ─────────────── ход врага / bullet-hell ───────────────
func _enemy_phase() -> void:
    if battle.enemy_frozen:
        battle.enemy_frozen = false
        _show_lines(["❄ %s застыл и пропускает ход!" % battle.ename], _to_menu)
        return
    var pre: Array = battle.check_phase2()   # босс на 50% HP свирепеет
    if not pre.is_empty():
        _shake = 5.0
    var pd := battle.poison_tick()
    if pd > 0:
        pre.append("☠ яд грызёт %s: -%d HP" % [battle.ename, pd])
        _refresh_stats()
        if not battle.enemy_alive():
            _show_lines(pre, _victory)
            return
    _show_lines(pre + battle.enemy_attack_lines(), _begin_bullets)


func _pick_pool() -> Array:
    ## Пул паттернов: у боссов фирменный (во 2-й фазе шире), у мобов — по виду.
    var pool: Array
    match boss_key:
        "tsizi":
            pool = ["wind", "spiral", "aimed"]
            if battle.phase2:
                pool.append_array(["walls", "rain"])
        "kalitin":
            pool = ["walls", "laser", "rain"]
            if battle.phase2:
                pool.append_array(["spiral", "homing"])
        "zhizha":
            pool = ["rain", "homing", "spiral"]
            if battle.phase2:
                pool.append_array(["laser", "walls"])
        _:
            pool = MOB_STYLE.get(Sprites.mob_key(battle.ename), ["aimed", "rain"]).duplicate()
            if danger >= 6:      # в бездне даже комар лютует
                for extra in ["homing", "laser"]:
                    if not pool.has(extra):
                        pool.append(extra)
    return pool


func _reshuffle(announce := true) -> void:
    ## Сменить набор атак: 1 или 2 паттерна ОДНОВРЕМЕННО (комбо).
    var pool := _pick_pool()
    pool.shuffle()
    var combo_chance := 0.35 + danger * 0.03 + (0.3 if battle.phase2 else 0.0)
    var n := 2 if (pool.size() >= 2 and randf() < combo_chance) else 1
    active = []
    for i in range(n):
        active.append({"pat": pool[i], "cd": 0.15 * i})
    if not _has_pat("wind"):
        wind = Vector2.ZERO
    # коробка «дышит»: иногда сжимается/расширяется (во 2-й фазе — при каждой смене)
    if randf() < 0.45 or battle.phase2:
        var w := randf_range(150.0, 232.0)
        var h := randf_range(108.0, 166.0)
        var c := Vector2(320.0, 253.0)
        box_target = Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
    _seg_t = randf_range(2.1, 3.0)
    var names: Array = []
    for e in active:
        names.append(PATTERN_NAMES.get(e.pat, "АТАКА"))
    hint_label.text = "⚠ %s!%s · 🟢 безвредны · 🔴 быстрые" % [" + ".join(names), _biome_tag()]
    if announce:
        Sfx.play("select")


func _has_pat(p: String) -> bool:
    for e in active:
        if e.pat == p:
            return true
    return false


# ─────────────── спецэффекты биома ───────────────
func _biome_kind() -> String:
    ## "ice" — скольжение · "hot" — стенки жгут · "goo" — вязко · "" — обычный.
    if biome in ["ice", "opera_ice"]:
        return "ice"
    if biome in ["volcano", "hell"]:
        return "hot"
    if biome in ["swamp", "water", "jungle", "acidfield"]:
        return "goo"
    return ""


func _biome_tag() -> String:
    match _biome_kind():
        "ice": return " · ❄ СКОЛЬЗКО"
        "hot": return " · 🔥 СТЕНЫ ЖГУТ"
        "goo": return " · 🟢 ВЯЗКО"
    return ""


func _begin_bullets() -> void:
    phase = Phase.BULLETS
    main_menu.hide_menu()
    sub_menu.hide_menu()
    log_label.text = ""
    box = Rect2(222, 178, 196, 150)
    box_target = box
    soul = box.position + box.size * 0.5
    soul_vel = Vector2.ZERO
    bullets.clear()
    zones.clear()
    wind = Vector2.ZERO
    _wind_t = 0.0
    _emit_a = randf() * TAU
    # длительность растёт с опасностью; у боссов дольше, во 2-й фазе ещё дольше
    _bh_dur = 4.2 + danger * 0.12 + (1.4 if boss_key != null else 0.0) \
            + (0.8 if battle.phase2 else 0.0)
    _bh_t = 0.0
    _iframe = 0.0
    _reshuffle(false)
    queue_redraw()


func _process(delta: float) -> void:
    # тряска экрана (затухает)
    if _shake > 0.0:
        _shake = maxf(0.0, _shake - 26.0 * delta)
        position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
    elif position != Vector2.ZERO:
        position = Vector2.ZERO
    _evade_t = maxf(0.0, _evade_t - delta)
    if phase == Phase.MESSAGE:
        if log_label.visible_characters != -1:
            _reveal += delta * 45.0
            log_label.visible_characters = int(_reveal)
        return
    if phase == Phase.BULLETS:
        _bullets_step(delta)


func _bullets_step(delta: float) -> void:
    _bh_t += delta
    _iframe = max(0.0, _iframe - delta)

    # ── смена/комбинация атак внутри фазы ──
    _seg_t -= delta
    if _seg_t <= 0.0 and _bh_t < _bh_dur - 1.2:
        _reshuffle()

    # ── коробка «дышит» к целевому размеру ──
    box.position = box.position.lerp(box_target.position, 4.0 * delta)
    box.size = box.size.lerp(box_target.size, 4.0 * delta)

    # ── движение души (+ ветер сносит; физика зависит от биома) ──
    var dir := Vector2(
        Input.get_axis("ui_left", "ui_right"),
        Input.get_axis("ui_up", "ui_down"))
    match _biome_kind():
        "ice":     # лёд: душа скользит по инерции
            soul_vel = soul_vel.lerp(dir * SOUL_SPEED, 3.6 * delta)
        "goo":     # трясина: движение вязкое
            soul_vel = dir * SOUL_SPEED * 0.78
        _:
            soul_vel = dir * SOUL_SPEED
    soul += soul_vel * delta + wind * delta
    soul.x = clampf(soul.x, box.position.x + SOUL_SIZE, box.position.x + box.size.x - SOUL_SIZE)
    soul.y = clampf(soul.y, box.position.y + SOUL_SIZE, box.position.y + box.size.y - SOUL_SIZE)
    # вулкан/пекло: стенки коробки раскалены — касание жжёт
    if _biome_kind() == "hot" and _iframe <= 0.0:
        var eps := 0.6
        if soul.x <= box.position.x + SOUL_SIZE + eps or soul.x >= box.end.x - SOUL_SIZE - eps \
                or soul.y <= box.position.y + SOUL_SIZE + eps or soul.y >= box.end.y - SOUL_SIZE - eps:
            Sfx.play("hurt")
            player.damage(2)
            _shake = 4.0
            _iframe = 0.45
            _refresh_stats()

    # ветер меняет направление порывами
    if _has_pat("wind"):
        _wind_t -= delta
        if _wind_t <= 0.0:
            _wind_t = randf_range(0.9, 1.5)
            wind = Vector2([-1.0, 1.0][randi() % 2] * randf_range(55.0, 85.0),
                           randf_range(-20.0, 20.0))

    # ── спавн: каждый активный паттерн со своим кулдауном ──
    if _bh_t < _bh_dur - 0.5:
        for e in active:
            e.cd -= delta
            if e.cd <= 0.0:
                _spawn_pat(e)

    var soul_r := Rect2(soul.x - SOUL_SIZE * 0.5, soul.y - SOUL_SIZE * 0.5, SOUL_SIZE, SOUL_SIZE)

    # ── лазеры: телеграф → удар ──
    var zalive: Array = []
    for z in zones:
        z.t += delta
        if z.t < LASER_WARN + LASER_ACTIVE:
            if z.t >= LASER_WARN and _iframe <= 0.0 and z.rect.intersects(soul_r):
                _bullet_hit()
            zalive.append(z)
    zones = zalive

    # ── снаряды ──
    var alive: Array = []
    for b in bullets:
        if b.kind == "homing":     # плавно доворачивает к душе
            var want: Vector2 = (soul - b.pos).normalized() * 62.0
            b.vel = b.vel.lerp(want, 1.6 * delta).limit_length(70.0)
        b.pos += b.vel * delta
        if box.grow(44).has_point(b.pos):
            var hit := false
            if _iframe <= 0.0 and not b.get("safe", false):
                if b.kind == "bone":
                    hit = Rect2(b.pos.x - 3, b.pos.y - 8, 6, 16).intersects(soul_r)
                else:
                    hit = soul_r.has_point(b.pos)
            if hit:
                _bullet_hit()
            else:
                alive.append(b)
    bullets = alive

    if _bh_t >= _bh_dur or not player.is_alive():
        _end_bullets()
    queue_redraw()


# ─────────────── спавнеры паттернов ───────────────
func _rate() -> float:
    ## Кулдауны: во 2-й фазе босса чаще; при комбо из 2 паттернов — реже каждый.
    var r := 1.0
    if battle.phase2:
        r *= 0.8
    if active.size() > 1:
        r *= 1.35
    return r


func _mk(kind: String, pos: Vector2, vel: Vector2) -> void:
    ## Создать снаряд: класс скорости (цвет = скорость) + шанс БЕЗВРЕДНОЙ
    ## обманки (зелёная, пролетает сквозь). Кости/лучи/орбы всегда настоящие.
    var fast_ch := 0.14 + danger * 0.02 + (0.15 if battle.phase2 else 0.0)
    var cls := 1
    var roll := randf()
    if roll < fast_ch:
        cls = 2
        vel *= 1.38
    elif roll < fast_ch + 0.22:
        cls = 0
        vel *= 0.68
    var safe := randf() < 0.16 + (0.06 if battle.phase2 else 0.0)
    bullets.append({"kind": kind, "pos": pos, "vel": vel, "cls": cls, "safe": safe})


func _spawn_pat(e: Dictionary) -> void:
    match e.pat:
        "aimed", "wind":
            _spawn_aimed()
            e.cd = randf_range(0.16, 0.32) * _rate()
        "rain":
            for _i in range(2):
                _mk("rain",
                    Vector2(randf_range(box.position.x, box.end.x), box.position.y - 16),
                    Vector2(randf_range(-14, 14), randf_range(85, 130)))
            e.cd = randf_range(0.18, 0.3) * _rate()
        "walls":
            _spawn_bone_wall()
            e.cd = randf_range(0.85, 1.15) * _rate()
        "spiral":
            var c := box.get_center()
            for k in [0.0, PI]:
                _mk("spiral", c, Vector2.from_angle(_emit_a + k) * 72.0)
            _emit_a += 0.55
            e.cd = 0.11 * _rate()
        "homing":
            bullets.append({"kind": "homing", "cls": 1,
                "pos": Vector2(randf_range(box.position.x, box.end.x),
                               [box.position.y - 14, box.end.y + 14][randi() % 2]),
                "vel": Vector2(0, 40)})
            e.cd = randf_range(0.55, 0.85) * _rate()
        "laser":
            _spawn_laser()
            e.cd = randf_range(1.1, 1.5) * _rate()


func _spawn_aimed() -> void:
    # с краёв коробки в сторону души
    var side := randi() % 4
    var p := Vector2.ZERO
    match side:
        0: p = Vector2(randf_range(box.position.x, box.end.x), box.position.y - 20)
        1: p = Vector2(randf_range(box.position.x, box.end.x), box.end.y + 20)
        2: p = Vector2(box.position.x - 20, randf_range(box.position.y, box.end.y))
        3: p = Vector2(box.end.x + 20, randf_range(box.position.y, box.end.y))
    var target := soul + Vector2(randf_range(-30, 30), randf_range(-30, 30))
    _mk("ball", p, (target - p).normalized() * randf_range(70, 120))


func _spawn_bone_wall() -> void:
    ## Стена костей слева/справа с ПРОХОДОМ — классика Undertale.
    var from_left := randi() % 2 == 0
    var sx := box.position.x - 14 if from_left else box.end.x + 14
    var vx := 92.0 if from_left else -92.0
    var gap_y := randf_range(box.position.y + 26, box.end.y - 26)
    var y := box.position.y + 8.0
    while y < box.end.y:
        if absf(y - gap_y) > 24.0:      # оставляем проход
            bullets.append({"kind": "bone", "cls": 1, "pos": Vector2(sx, y), "vel": Vector2(vx, 0)})
        y += 15.0


func _spawn_laser() -> void:
    ## Луч: сперва телеграф (полупрозрачный), потом бьёт по полосе.
    if randi() % 2 == 0:   # горизонтальный
        var ly := randf_range(box.position.y + 10, box.end.y - 34)
        zones.append({"rect": Rect2(box.position.x, ly, box.size.x, 24), "t": 0.0})
    else:                  # вертикальный
        var lx := randf_range(box.position.x + 10, box.end.x - 34)
        zones.append({"rect": Rect2(lx, box.position.y, 24, box.size.y), "t": 0.0})


func _bullet_hit() -> void:
    # шанс уворота: Блок% (щит/оберег) + зелье уворота → пуля проходит сквозь
    if randi() % 100 < battle.evade_chance():
        Sfx.play("select")
        _evade_t = 0.45
        _iframe = 0.25
        return
    Sfx.play("hurt")
    var reduce := int(battle.eq.get("def", 0))
    var dmg: int = max(1, int(round(battle.edmg * 0.6)) - reduce)
    player.damage(dmg)
    var th := int(battle.effects.get("thorns", 0))
    if th > 0:
        battle.enemy_hp -= th
    _shake = 7.0
    _iframe = 0.7
    _refresh_stats()


func _end_bullets() -> void:
    bullets.clear()
    zones.clear()
    wind = Vector2.ZERO
    queue_redraw()
    if not player.is_alive():
        _defeat()
    elif not battle.enemy_alive():
        _victory()
    else:
        _to_menu()


# ─────────────── исходы ───────────────
func _victory() -> void:
    Sfx.play("win")
    var lines := battle.resolve_victory()
    lines.append_array(Loot.grant(player, danger, boss_key != null))
    _refresh_stats()
    _show_lines(lines, func(): _finish("win"))


func _defeat() -> void:
    _show_lines(battle.resolve_defeat(), func(): _finish("lose"))


func _flee() -> void:
    var res := battle.flee()      # [bool, lines]
    if res[0]:
        _show_lines(res[1], func(): _finish("flee"))
    else:
        _show_lines(res[1], _enemy_phase)


func _finish(result: String) -> void:
    phase = Phase.DONE
    battle_over.emit(result)


# ─────────────── ввод ───────────────
func _unhandled_input(event: InputEvent) -> void:
    if phase == Phase.MESSAGE and event.is_action_pressed("ui_accept"):
        _advance_message()
        accept_event()


# ─────────────── отрисовка bullet-hell ───────────────
func _draw() -> void:
    draw_rect(Rect2(0, 0, 640, 480), Color("#0a0a12"), true)
    var ekey: String = boss_key if (boss_key != null and Sprites.has(boss_key)) else Sprites.mob_key(battle.ename)
    Sprites.draw_grid(self, Rect2(268, 44, 104, 96), ekey)
    if phase != Phase.BULLETS:
        return
    # рамка коробки — цвет биома (раскалённая/ледяная/болотная)
    match _biome_kind():
        "hot":
            var hp2 := 0.5 + 0.5 * sin(_bh_t * 6.0)
            draw_rect(box, Color("#ff5a2a").lightened(0.25 * hp2), false, 3.0)
        "ice":
            draw_rect(box, Color("#a8dcec"), false, 2.0)
        "goo":
            draw_rect(box, Color("#6ee66e"), false, 2.0)
        _:
            draw_rect(box, Color("#e8e8ff"), false, 2.0)
    # ветер — видимые порывы
    if _has_pat("wind") and wind.length() > 1.0:
        var wd := signf(wind.x)
        for i in range(4):
            var wy := box.position.y + 22.0 + i * 34.0
            var wx := box.position.x + fmod(_bh_t * 130.0 + i * 47.0, box.size.x - 24.0)
            if wd < 0:
                wx = box.end.x - 24.0 - (wx - box.position.x)
            draw_line(Vector2(wx, wy), Vector2(wx + 18.0 * wd, wy), Color("#8fd8e8", 0.5), 2.0)
    # лазеры: телеграф → вспышка
    for z in zones:
        if z.t < LASER_WARN:
            var a: float = 0.15 + 0.25 * (z.t / LASER_WARN) * (0.5 + 0.5 * sin(z.t * 24.0))
            draw_rect(z.rect, Color("#ff5a3a", a), true)
            draw_rect(z.rect, Color("#ff5a3a", 0.8), false, 1.0)
        else:
            draw_rect(z.rect, Color("#fff0d0", 0.95), true)
            draw_rect(z.rect.grow(2), Color("#ffb060", 0.6), false, 2.0)
    var col := Color("#ff5a5a") if _iframe > 0.0 else Color("#ff2b2b")
    Sprites.draw_heart(self, soul, SOUL_SIZE * 1.6, col)
    if _evade_t > 0.0:             # вспышка уворота: кольцо-туман вокруг души
        draw_arc(soul, 10.0 + (0.45 - _evade_t) * 26.0, 0, TAU, 16,
                 Color("#b8f0ff", _evade_t * 1.6), 2.0)
    for b in bullets:
        if b.kind == "bone":       # кость: белая палка с шляпками
            var bnc := Color("#e8e8f4")
            draw_rect(Rect2(b.pos.x - 3, b.pos.y - 8, 6, 16), bnc, true)
            draw_rect(Rect2(b.pos.x - 4, b.pos.y - 9, 8, 3), bnc, true)
            draw_rect(Rect2(b.pos.x - 4, b.pos.y + 6, 8, 3), bnc, true)
        elif b.kind == "homing":   # преследователь: крупный, с ядром
            draw_circle(b.pos, 5.5, Color("#ff8adc"))
            draw_circle(b.pos, 2.2, Color("#701848"))
        elif b.get("safe", false):  # 🟢 безвредная обманка: зелёное колечко
            draw_arc(b.pos, 4.0, 0, TAU, 10, Color("#6ee66e"), 1.6)
            draw_circle(b.pos, 1.6, Color("#6ee66e", 0.8))
        else:                      # цвет = скорость (голубая/жёлтая/красная)
            var bc: Color = SPEED_COL.get(int(b.get("cls", 1)), Color("#fff0a0"))
            draw_circle(b.pos, 4.6 if int(b.get("cls", 1)) == 2 else 4.0, bc)
