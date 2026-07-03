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
var bullets: Array = []          # {kind,pos,vel,cls,safe,beh,wait,...} (cls: 0 медл/1 обыч/2 быстр)
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
var _graze_t := 0.0              # вспышка «впритирку» (грейз)
var _hitstop := 0.0              # стоп-кадр при ударе — продаёт импакт
var _hitflash := 0.0             # белая вспышка кадра при уроне
var _box_flash := 0.0            # вспышка-телеграф смены коробки
var sparks: Array = []           # искры: {pos, vel, t, col}
var soul_mode := "free"          # "free" | "blue" (гравитация и прыжки, как у Санса)
var turn_no := 0                 # номер хода врага — боссы разгоняются от хода к ходу
var _seg_i := 0                  # сквозной номер сегмента боя (для сценариев боссов)
var _pat_seen: Dictionary = {}   # сколько раз паттерн уже был — повторы мутируют
var _spin := 1.0                 # направление вихря в текущем сегменте
var _drizzle_cd := 0.4           # фоновая «морось»: паузы между волнами всегда заняты
var _spike_done := true          # разовый «спайк»-сюрприз внутри сегмента
var _spike_at := 0.0
var _last_gap_y := -1.0          # проход прошлой стены костей (связность пути)
var _gap_x := -1.0               # щель «забора»: дрейфует, но не телепортируется
var _hit_r := 6.8                # ДИНАМИЧЕСКИЙ хитбокс: плотнее шквал — меньше сердце
const SOUL_SPEED := 150.0
const SOUL_SIZE := 10.0
const LASER_WARN := 0.45         # телеграф луча — резкий, как в Undertale
const LASER_ACTIVE := 0.3        # сколько луч жжёт
const GRAV := 560.0              # синий режим: гравитация
const JUMP_V := 245.0            # синий режим: импульс прыжка
const HIT_R_MIN := 4.4           # хитбокс в плотном аду — щели проходимы честно
const HIT_R_MAX := 6.8           # хитбокс в спокойные моменты
const GRAZE_R := 13.0            # радиус «впритирку»

# имена паттернов (показываются игроку)
const PATTERN_NAMES := {
    "aimed": "РОЙ", "rain": "ЛИВЕНЬ", "walls": "КОСТИ", "spiral": "ВИХРЬ",
    "homing": "ПРЕСЛЕДОВАТЕЛИ", "wind": "ШКВАЛ", "laser": "ЛУЧИ",
    "gapwall": "ЗАБОР", "burst": "ЗАЛПЫ", "gravity": "СИНЯЯ ДУША",
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
    "overseer": ["walls", "laser", "gapwall"], "pekl_master": ["laser", "spiral", "burst"],
    "tm": ["homing", "laser", "gapwall", "burst"],
}
# срежиссированные ОТКРЫТИЯ боёв боссов: первые сегменты идут по списку
# (осознанная драматургия темпа), дальше — случайная эскалация по этапам.
const BOSS_OPENING := {
    "kalitin": [["walls"], ["rain"], ["laser"], ["walls", "rain"], ["laser", "walls"]],
    "tsizi":   [["wind"], ["spiral"], ["aimed", "wind"], ["spiral", "wind"]],
    "zhizha":  [["rain"], ["homing"], ["spiral", "rain"], ["homing", "spiral"]],
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
        _hitflash = 0.12                     # вспышка на смену фазы
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
                pool.append_array(["walls", "rain", "burst", "gravity"])
        "kalitin":
            pool = ["walls", "laser", "rain"]
            if battle.phase2:
                pool.append_array(["spiral", "homing", "gapwall", "gravity"])
        "zhizha":
            pool = ["rain", "homing", "spiral"]
            if battle.phase2:
                pool.append_array(["laser", "walls", "gapwall", "burst"])
        _:
            pool = MOB_STYLE.get(Sprites.mob_key(battle.ename), ["aimed", "rain"]).duplicate()
            if danger >= 6:      # в бездне даже комар лютует
                for extra in ["homing", "laser"]:
                    if not pool.has(extra):
                        pool.append(extra)
    return pool


func _reshuffle(announce := true) -> void:
    ## Сменить набор атак: 1 или 2 паттерна ОДНОВРЕМЕННО (комбо).
    ## Начало боя босса — по сценарию BOSS_OPENING (авторская драматургия),
    ## дальше — случайная эскалация по этапам (_stage).
    var st := _stage()
    var chosen: Array = []
    var script: Array = []
    if boss_key != null:
        script = BOSS_OPENING.get(boss_key, [])
    if _seg_i < script.size() and not battle.phase2:
        chosen = (script[_seg_i] as Array).duplicate()
    else:
        var pool := _pick_pool()
        pool.shuffle()
        var combo_chance: float
        if st < 0:
            combo_chance = 0.35 + danger * 0.03
        else:
            combo_chance = float([0.0, 0.5, 0.75, 0.95][st])
        var n := 2 if (pool.size() >= 2 and randf() < combo_chance) else 1
        for i in range(n):
            chosen.append(pool[i])
    # ГАРАНТИЯ ПРОХОДА: две «стены» одновременно могут запечатать путь — нельзя
    if chosen.has("walls") and chosen.has("gapwall"):
        chosen = [chosen[0]]
    _seg_i += 1
    active = []
    for i in range(chosen.size()):
        active.append({"pat": chosen[i], "cd": 0.15 * i})
        _pat_seen[chosen[i]] = int(_pat_seen.get(chosen[i], 0)) + 1
    _spin = 1.0 if randi() % 2 == 0 else -1.0    # вихрь крутится по-разному
    # СИНЯЯ ДУША — эксклюзив: гравитация не сочетается с другими паттернами
    soul_mode = "free"
    if _has_pat("gravity"):
        active = [{"pat": "gravity", "cd": 0.4}]
        soul_mode = "blue"
        soul_vel = Vector2.ZERO
    if not _has_pat("wind"):
        wind = Vector2.ZERO
    # коробка живёт: меняет и размер, и МЕСТО; переезд быстрый, с вспышкой-телеграфом
    if soul_mode == "blue":
        box_target = Rect2(320.0 - 132.0, 253.0 - 52.0, 264.0, 104.0)   # низкий коридор
        _box_flash = 0.35
    elif randf() < 0.45 or battle.phase2:
        var w := randf_range(150.0, 232.0)
        var h := randf_range(108.0, 166.0)
        var c := Vector2(320.0 + randf_range(-34.0, 34.0), 253.0 + randf_range(-14.0, 14.0))
        box_target = Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
        _box_flash = 0.35
    # сегменты короче — больше «битов» на бой; спайк-сюрприз в середине сегмента
    _seg_t = 3.4 if soul_mode == "blue" else randf_range(1.7, 2.4)
    _spike_done = soul_mode == "blue"
    _spike_at = _seg_t * randf_range(0.35, 0.65)
    var names: Array = []
    for e in active:
        names.append(PATTERN_NAMES.get(e.pat, "АТАКА"))
    if soul_mode == "blue":
        hint_label.text = "⚠ СИНЯЯ ДУША! Прыгай: ↑ или SPACE%s" % _biome_tag()
    else:
        hint_label.text = "⚠ %s! · 🟢 безвредны · 🔴 быстрые%s%s" % [
            " + ".join(names), _beh_tag(), _biome_tag()]
    if announce:
        Sfx.play("select")


func _has_pat(p: String) -> bool:
    for e in active:
        if e.pat == p:
            return true
    return false


# ─────────────── этапы боя и спецпули ───────────────
func _stage() -> int:
    ## Драматургия босса: -1 мобы · 0 интро · 1 разгон · 2 фаза ярости · 3 финал.
    if boss_key == null:
        return -1
    var s := 0
    if turn_no >= 3:
        s = 1
    if battle.phase2:
        s = 2
        if turn_no >= 8:
            s = 3
    return s


func _speed_mult() -> float:
    ## Множитель скорости снарядов: мобы мягче, боссы разгоняются по этапам.
    ## Плюс докрутка ВНУТРИ фазы: пока живёшь — темп подрастает (до +15%).
    var st := _stage()
    var base: float
    if st < 0:
        base = minf(0.88 + danger * 0.025, 1.12)
    else:
        base = float([1.05, 1.12, 1.22, 1.34][st])
    return base * minf(1.0 + _bh_t * 0.025, 1.15)


func _warn_mult() -> float:
    ## Телеграфы поджимаются к финалу боя босса (но остаются читаемыми).
    match _stage():
        2: return 0.85
        3: return 0.72
    return 1.0


func _beh_enabled() -> bool:
    ## Синие/оранжевые пули — у боссов и в опасных землях (новичков не путаем).
    return boss_key != null or danger >= 4


func _beh_blocks(beh: String, spd: float) -> bool:
    ## 🔵 синяя не бьёт стоящего, 🟠 оранжевая — движущегося (как в Undertale).
    if beh == "still":
        return spd < 14.0
    if beh == "move":
        return spd >= 14.0
    return false


func _beh_tag() -> String:
    return " · 🔵 замри · 🟠 беги" if _beh_enabled() else ""


func _gbone_rect(b: Dictionary) -> Rect2:
    ## Кость синего режима: столб от пола вверх или с потолка вниз (щель у пола).
    if b.get("top", false):
        return Rect2(b.pos.x - 3.0, box.position.y, 6.0, box.size.y - 30.0)
    var h: float = b.get("h", 30.0)
    return Rect2(b.pos.x - 3.0, box.end.y - h, 6.0, h)


func _spark_burst(p: Vector2, n: int, col: Color) -> void:
    if sparks.size() > 90:
        return
    for _i in range(n):
        sparks.append({"pos": p, "t": randf_range(0.18, 0.32), "col": col,
            "vel": Vector2.from_angle(randf() * TAU) * randf_range(40.0, 110.0)})


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
    turn_no += 1                 # боссы наращивают темп от хода к ходу
    main_menu.hide_menu()
    sub_menu.hide_menu()
    log_label.text = ""
    box = Rect2(222, 178, 196, 150)
    box_target = box
    soul = box.position + box.size * 0.5
    soul_vel = Vector2.ZERO
    soul_mode = "free"
    bullets.clear()
    zones.clear()
    sparks.clear()
    wind = Vector2.ZERO
    _wind_t = 0.0
    _emit_a = randf() * TAU
    # мобы — короткие стычки; у боссов фаза дольше и растёт с этапом боя
    if boss_key != null:
        _bh_dur = 6.0 + danger * 0.1 + (1.2 if battle.phase2 else 0.0) \
                + 0.35 * maxi(_stage(), 0)
    else:
        _bh_dur = 4.6 + danger * 0.12
    _bh_t = 0.0
    _iframe = 0.0
    _hitstop = 0.0
    _hit_r = HIT_R_MAX
    _drizzle_cd = 0.4
    _last_gap_y = -1.0
    _gap_x = -1.0
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
    _graze_t = maxf(0.0, _graze_t - delta)
    _hitflash = maxf(0.0, _hitflash - delta)
    _box_flash = maxf(0.0, _box_flash - delta)
    if phase == Phase.MESSAGE:
        if log_label.visible_characters != -1:
            _reveal += delta * 45.0
            log_label.visible_characters = int(_reveal)
        return
    if phase == Phase.BULLETS:
        _bullets_step(delta)


func _bullets_step(delta: float) -> void:
    # стоп-кадр при ударе: короткая заморозка (2-4 кадра) продаёт импакт
    if _hitstop > 0.0:
        _hitstop -= delta
        queue_redraw()
        return
    _bh_t += delta
    _iframe = max(0.0, _iframe - delta)

    # ── смена/комбинация атак внутри фазы ──
    _seg_t -= delta
    if _seg_t <= 0.0 and _bh_t < _bh_dur - 1.2:
        _reshuffle()

    # ── коробка резко (но с телеграфом-вспышкой) переезжает к целевой форме ──
    box.position = box.position.lerp(box_target.position, 9.0 * delta)
    box.size = box.size.lerp(box_target.size, 9.0 * delta)

    # ── движение души: свободный полёт или СИНИЙ режим (гравитация + прыжок) ──
    var dir := Vector2(
        Input.get_axis("ui_left", "ui_right"),
        Input.get_axis("ui_up", "ui_down"))
    if soul_mode == "blue":
        soul_vel.x = dir.x * SOUL_SPEED
        soul_vel.y += GRAV * delta
        var on_floor := soul.y >= box.end.y - SOUL_SIZE - 1.0
        if on_floor and (Input.is_action_just_pressed("ui_accept")
                or Input.is_action_just_pressed("ui_up")):
            soul_vel.y = -JUMP_V
            Sfx.play("select")
    else:
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
    if soul_mode == "blue":       # пол/потолок гасят вертикальную скорость
        if soul.y >= box.end.y - SOUL_SIZE:
            soul_vel.y = minf(soul_vel.y, 0.0)
        elif soul.y <= box.position.y + SOUL_SIZE:
            soul_vel.y = maxf(soul_vel.y, 0.0)
    # вулкан/пекло: стенки коробки раскалены — касание жжёт
    if _biome_kind() == "hot" and _iframe <= 0.0:
        var eps := 0.6
        var burn := soul.x <= box.position.x + SOUL_SIZE + eps \
                or soul.x >= box.end.x - SOUL_SIZE - eps \
                or soul.y <= box.position.y + SOUL_SIZE + eps
        if soul_mode != "blue":   # в синем режиме пол — опора, он не жжёт
            burn = burn or soul.y >= box.end.y - SOUL_SIZE - eps
        if burn:
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

    # ── фоновая «морось»: даже в паузах между волнами что-то летит в тебя ──
    # (медленный шар в душу — отучает стоять в углу; в синем режиме не мешаем)
    if soul_mode != "blue" and _bh_t < _bh_dur - 0.6:
        _drizzle_cd -= delta
        if _drizzle_cd <= 0.0:
            _drizzle_cd = randf_range(0.7, 1.15) * (1.35 if boss_key == null else 1.0)
            var dp := Vector2(randf_range(box.position.x, box.end.x),
                              box.position.y - 18.0)
            bullets.append({"kind": "ball", "cls": 0, "pos": dp,
                "vel": (soul - dp).normalized() * 62.0})

    # ── разовый «спайк»-сюрприз: внезапная очередь посреди сегмента ──
    if not _spike_done and _seg_t <= _spike_at:
        _spike_done = true
        _spark_burst(soul + Vector2(0, -22), 3, Color("#ffd0a0"))
        for _i in range(2 + (1 if battle.phase2 else 0)):
            _spawn_aimed()

    # ── ДИНАМИЧЕСКИЙ хитбокс: плотнее шквал — меньше сердце (щели честные) ──
    var dens := 0
    for b in bullets:
        if not b.get("safe", false):
            dens += 1
    _hit_r = lerpf(_hit_r, clampf(6.8 - float(dens) * 0.1, HIT_R_MIN, HIT_R_MAX),
                   6.0 * delta)
    var core := Rect2(soul.x - _hit_r * 0.5, soul.y - _hit_r * 0.5, _hit_r, _hit_r)

    # ── лазеры: телеграф → удар (в момент выстрела — искры и толчок) ──
    var zalive: Array = []
    for z in zones:
        var zw: float = z.get("warn", LASER_WARN)
        var was_warn: bool = z.t < zw
        z.t += delta
        if was_warn and z.t >= zw:
            _shake = maxf(_shake, 2.5)
            _spark_burst(z.rect.get_center(), 5, Color("#ffb060"))
        if z.t < zw + LASER_ACTIVE:
            if z.t >= zw and _iframe <= 0.0 and z.rect.intersects(core):
                _bullet_hit()
            zalive.append(z)
    zones = zalive

    # ── снаряды ──
    var alive: Array = []
    for b in bullets:
        var wait: float = b.get("wait", 0.0)
        if wait > 0.0:             # телеграф: снаряд «проклёвывается», ещё безвреден
            b.wait = wait - delta
            alive.append(b)
            continue
        if b.kind == "homing":     # доворачивает к душе, потом ложится на прямую
            var steer: float = b.get("steer", 0.0)
            if steer > 0.0:
                b.steer = steer - delta
                var want: Vector2 = (soul - b.pos).normalized() * 78.0
                b.vel = b.vel.lerp(want, 2.2 * delta).limit_length(88.0)
        b.pos += b.vel * delta
        if box.grow(44).has_point(b.pos):
            var hit := false
            if _iframe <= 0.0 and not b.get("safe", false) \
                    and not _beh_blocks(str(b.get("beh", "")), soul_vel.length()):
                match b.kind:
                    "bone":
                        hit = Rect2(b.pos.x - 3, b.pos.y - 8, 6, 16).intersects(core)
                    "gbone":
                        hit = _gbone_rect(b).intersects(core)
                    "homing":
                        hit = b.pos.distance_to(soul) < _hit_r + 1.5
                    _:
                        hit = b.pos.distance_to(soul) < _hit_r
            if hit:
                _bullet_hit()
            else:
                if b.kind != "bone" and b.kind != "gbone" and not b.get("grz", false) \
                        and not b.get("safe", false) and b.pos.distance_to(soul) < GRAZE_R:
                    b.grz = true       # «впритирку»: искры и лёгкая дрожь
                    _graze_t = 0.3
                    _shake = maxf(_shake, 1.4)
                    _spark_burst(b.pos, 2, Color("#b8f0ff"))
                alive.append(b)
    bullets = alive

    # ── искры-частицы ──
    var salive: Array = []
    for s in sparks:
        s.t = float(s.t) - delta
        if float(s.t) > 0.0:
            s.pos += s.vel * delta
            salive.append(s)
    sparks = salive

    if _bh_t >= _bh_dur or not player.is_alive():
        _end_bullets()
    queue_redraw()


# ─────────────── спавнеры паттернов ───────────────
func _rate() -> float:
    ## Кулдауны: боссы ускоряются по этапам боя; при комбо каждый паттерн реже.
    ## Чем дольше идёт фаза, тем плотнее спавн (до −12%) — хватка сжимается.
    var st := _stage()
    var r: float
    if st < 0:
        r = 1.05 - danger * 0.015     # мобы прощают больше
    else:
        r = float([1.05, 0.9, 0.78, 0.62][st])
    if active.size() > 1:
        r *= 1.35
    return r * (1.0 - minf(_bh_t * 0.018, 0.12))


func _mk(kind: String, pos: Vector2, vel: Vector2) -> void:
    ## Создать снаряд. Скорость масштабируется этапом боя (боссы разгоняются).
    ## Виды: класс скорости (цвет = скорость), 🟢 безвредная обманка,
    ## 🔵 синяя (не бьёт стоящего) / 🟠 оранжевая (не бьёт движущегося).
    vel *= _speed_mult()
    var safe := randf() < 0.16 + (0.06 if battle.phase2 else 0.0)
    var beh := ""
    if not safe and _beh_enabled() and randf() < 0.11 + (0.05 if battle.phase2 else 0.0):
        beh = "still" if randi() % 2 == 0 else "move"
    var cls := 1
    if beh == "":
        var fast_ch := 0.14 + danger * 0.02 + (0.15 if battle.phase2 else 0.0)
        var roll := randf()
        if roll < fast_ch:
            cls = 2
            vel *= 1.38
        elif roll < fast_ch + 0.22:
            cls = 0
            vel *= 0.68
    bullets.append({"kind": kind, "pos": pos, "vel": vel, "cls": cls, "safe": safe, "beh": beh})


func _spawn_pat(e: Dictionary) -> void:
    match e.pat:
        "aimed", "wind":
            _spawn_aimed()
            e.cd = randf_range(0.16, 0.3) * _rate()
        "rain":
            var n := 2 + (1 if _stage() >= 1 else 0)
            for _i in range(n):
                _mk("rain",
                    Vector2(randf_range(box.position.x, box.end.x), box.position.y - 16),
                    Vector2(randf_range(-14, 14), randf_range(100, 150)))
            e.cd = randf_range(0.17, 0.28) * _rate()
        "walls":
            _spawn_bone_wall()
            e.cd = randf_range(0.72, 0.98) * _rate()
        "spiral":
            var c := box.get_center()
            var arms: Array = [0.0, PI]
            if battle.phase2:               # в ярости — три рукава
                arms = [0.0, TAU / 3.0, 2.0 * TAU / 3.0]
            for k in arms:
                _mk("spiral", c, Vector2.from_angle(_emit_a + float(k)) * 85.0)
            _emit_a += 0.55 * _spin         # направление меняется от сегмента к сегменту
            e.cd = randf_range(0.09, 0.14) * _rate()
        "homing":
            bullets.append({"kind": "homing", "cls": 1, "steer": 1.15,
                "pos": Vector2(randf_range(box.position.x, box.end.x),
                               [box.position.y - 14, box.end.y + 14][randi() % 2]),
                "vel": Vector2(0, 46)})
            e.cd = randf_range(0.45, 0.7) * _rate()
        "laser":
            _spawn_laser()
            e.cd = randf_range(0.85, 1.15) * _rate()
        "gapwall":
            _spawn_gapwall()
            e.cd = randf_range(0.52, 0.72) * _rate()
        "burst":
            _spawn_burst()
            e.cd = randf_range(0.95, 1.35) * _rate()
        "gravity":
            _spawn_gbone()
            e.cd = randf_range(0.5, 0.85) * _rate()


func _spawn_aimed() -> void:
    # с краёв коробки в сторону души; иногда — веером из трёх
    var side := randi() % 4
    var p := Vector2.ZERO
    match side:
        0: p = Vector2(randf_range(box.position.x, box.end.x), box.position.y - 20)
        1: p = Vector2(randf_range(box.position.x, box.end.x), box.end.y + 20)
        2: p = Vector2(box.position.x - 20, randf_range(box.position.y, box.end.y))
        3: p = Vector2(box.end.x + 20, randf_range(box.position.y, box.end.y))
    var target := soul + Vector2(randf_range(-30, 30), randf_range(-30, 30))
    var v := (target - p).normalized() * randf_range(85, 135)
    _mk("ball", p, v)
    # шанс веера растёт с каждым повтором роя — паттерн не даёт себя выучить
    if randf() < 0.26 + (0.2 if battle.phase2 else 0.0) \
            + 0.03 * float(_pat_seen.get("aimed", 0)):
        _mk("ball", p, v.rotated(0.32) * 0.92)
        _mk("ball", p, v.rotated(-0.32) * 0.92)


func _spawn_bone_wall() -> void:
    ## Стена костей слева/справа с ПРОХОДОМ — классика Undertale.
    ## Кости «мигают» на месте (телеграф направления), потом едут.
    ## ГАРАНТИЯ ПУТИ: проход новой стены рядом с прошлым — успеваешь доплыть.
    var from_left := randi() % 2 == 0
    var sx := box.position.x - 14 if from_left else box.end.x + 14
    var vx := 108.0 if from_left else -108.0
    vx *= _speed_mult()
    var gap_lo := box.position.y + 26.0
    var gap_hi := box.end.y - 26.0
    var gap_y: float
    if _last_gap_y < 0.0:
        gap_y = randf_range(gap_lo, gap_hi)
    else:
        gap_y = clampf(_last_gap_y + randf_range(-55.0, 55.0), gap_lo, gap_hi)
    _last_gap_y = gap_y
    # с повторами паттерна проход сужается (48 → 40 пкс), но не исчезает
    var half := maxf(20.0, 26.0 - float(_pat_seen.get("walls", 0)))
    var y := box.position.y + 8.0
    while y < box.end.y:
        if absf(y - gap_y) > half:      # оставляем проход
            bullets.append({"kind": "bone", "cls": 1, "wait": 0.25 * _warn_mult(),
                "pos": Vector2(sx, y), "vel": Vector2(vx, 0)})
        y += 15.0


func _spawn_gapwall() -> void:
    ## «Забор»: сплошной ряд сверху с одной щелью; щель дрейфует от ряда к ряду.
    ## ГАРАНТИЯ ПУТИ: за ряд щель смещается не дальше, чем душа успевает доплыть.
    var lo := box.position.x + 26.0
    var hi := box.end.x - 26.0
    var target: float = lo + (0.5 + 0.5 * sin(_bh_t * 2.2 + _emit_a)) * (hi - lo)
    if _gap_x < 0.0:
        _gap_x = target
    else:
        _gap_x = clampf(_gap_x + clampf(target - _gap_x, -58.0, 58.0), lo, hi)
    var x := box.position.x + 6.0
    while x < box.end.x:
        if absf(x - _gap_x) > 24.0:
            bullets.append({"kind": "rain", "cls": 1, "pos": Vector2(x, box.position.y - 16),
                "vel": Vector2(0, 118.0 * _speed_mult())})
        x += 15.0


func _spawn_burst() -> void:
    ## Мульти-залп: 2-3 точки внутри коробки одновременно выпускают кольца.
    ## Снаряды 0.32с «проклёвываются» (телеграф) и только потом летят.
    var srcs := 2 + (1 if battle.phase2 else 0)
    for _s in range(srcs):
        var p := Vector2(randf_range(box.position.x + 22.0, box.end.x - 22.0),
                         randf_range(box.position.y + 22.0, box.end.y - 22.0))
        if p.distance_to(soul) < 42.0:   # не спавним кольцо прямо на душе
            p = box.get_center() + (p - soul).normalized() * 50.0
        var a0 := randf() * TAU
        for k in range(7):
            var v := Vector2.from_angle(a0 + TAU * float(k) / 7.0) \
                    * randf_range(72.0, 100.0) * _speed_mult()
            bullets.append({"kind": "ball", "cls": 1, "pos": p, "vel": v,
                "wait": 0.32 * _warn_mult()})


func _spawn_gbone() -> void:
    ## Синий режим: кости едут по полу (перепрыгни) или свисают с потолка
    ## почти до пола (НЕ прыгай — прижмись к полу).
    ## ГАРАНТИЯ ПУТИ: пока висит потолочная кость, низовые — только перепрыгиваемые
    ## (не выше щели у пола), и вторая потолочная не спавнится.
    var from_left := randi() % 2 == 0
    var has_top := false
    for b in bullets:
        if b.kind == "gbone" and b.get("top", false):
            has_top = true
            break
    var top: bool = (not has_top) and randf() < 0.25
    var h := randf_range(22.0, 40.0)
    if has_top:
        h = randf_range(18.0, 24.0)
    bullets.append({"kind": "gbone", "cls": 1, "top": top, "h": h,
        "pos": Vector2(box.position.x - 12.0 if from_left else box.end.x + 12.0,
                       box.get_center().y),
        "vel": Vector2((150.0 if from_left else -150.0) * _speed_mult(), 0.0)})


func _spawn_laser() -> void:
    ## Луч: сперва телеграф (полупрозрачный), потом бьёт по полосе.
    ## Телеграф поджимается к финалу боя босса (_warn_mult).
    var warn := LASER_WARN * _warn_mult()
    if randi() % 2 == 0:   # горизонтальный
        var ly := randf_range(box.position.y + 10, box.end.y - 34)
        zones.append({"rect": Rect2(box.position.x, ly, box.size.x, 24),
            "t": 0.0, "warn": warn})
    else:                  # вертикальный
        var lx := randf_range(box.position.x + 10, box.end.x - 34)
        zones.append({"rect": Rect2(lx, box.position.y, 24, box.size.y),
            "t": 0.0, "warn": warn})


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
    _hitstop = 0.08                       # стоп-кадр
    _hitflash = 0.14                      # белая вспышка
    _spark_burst(soul, 7, Color("#ff8a7a"))
    _iframe = 0.7
    _refresh_stats()


func _end_bullets() -> void:
    bullets.clear()
    zones.clear()
    sparks.clear()
    soul_mode = "free"
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
        _draw_flash()
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
    if _box_flash > 0.0:           # телеграф переезда коробки — вспышка рамки
        draw_rect(box.grow(2.0), Color(1, 1, 1, _box_flash * 1.8), false, 2.0)
    if soul_mode == "blue":        # синий режим: подсветить пол-опору
        draw_line(Vector2(box.position.x + 2, box.end.y - 2),
                  Vector2(box.end.x - 2, box.end.y - 2), Color("#4a72ff", 0.7), 2.0)
    # ветер — видимые порывы
    if _has_pat("wind") and wind.length() > 1.0:
        var wd := signf(wind.x)
        for i in range(4):
            var wy := box.position.y + 22.0 + i * 34.0
            var wx := box.position.x + fmod(_bh_t * 130.0 + i * 47.0, box.size.x - 24.0)
            if wd < 0:
                wx = box.end.x - 24.0 - (wx - box.position.x)
            draw_line(Vector2(wx, wy), Vector2(wx + 18.0 * wd, wy), Color("#8fd8e8", 0.5), 2.0)
    # лазеры: телеграф → вспышка (окно телеграфа у каждого луча своё)
    for z in zones:
        var zw: float = z.get("warn", LASER_WARN)
        if z.t < zw:
            var a: float = 0.15 + 0.25 * (z.t / zw) * (0.5 + 0.5 * sin(z.t * 24.0))
            draw_rect(z.rect, Color("#ff5a3a", a), true)
            draw_rect(z.rect, Color("#ff5a3a", 0.8), false, 1.0)
        else:
            draw_rect(z.rect, Color("#fff0d0", 0.95), true)
            draw_rect(z.rect.grow(2), Color("#ffb060", 0.6), false, 2.0)
    var col := Color("#ff5a5a") if _iframe > 0.0 else Color("#ff2b2b")
    if soul_mode == "blue":        # синяя душа (режим гравитации)
        col = Color("#7a95ff") if _iframe > 0.0 else Color("#3a5aff")
    # сердце сжимается вместе с хитбоксом (телеграф: видно, сколько места есть)
    var hsz: float = SOUL_SIZE * 1.6 * (0.72 + 0.28 * _hit_r / HIT_R_MAX)
    Sprites.draw_heart(self, soul, hsz, col)
    if _hit_r < 5.4:               # хитбокс сжат — тонкое белое свечение
        draw_arc(soul, hsz * 0.5 + 2.5, 0, TAU, 12, Color(1, 1, 1, 0.35), 1.0)
    if _evade_t > 0.0:             # вспышка уворота: кольцо-туман вокруг души
        draw_arc(soul, 10.0 + (0.45 - _evade_t) * 26.0, 0, TAU, 16,
                 Color("#b8f0ff", _evade_t * 1.6), 2.0)
    if _graze_t > 0.0:             # «впритирку» — тонкое голубое кольцо
        draw_arc(soul, 9.0, 0, TAU, 12, Color("#b8f0ff", _graze_t * 1.2), 1.5)
    for b in bullets:
        var wait: float = b.get("wait", 0.0)
        if b.kind == "bone" or b.kind == "gbone":
            # кость: белая палка; пока полупрозрачная — телеграф, ещё не бьёт
            var bnc := Color("#e8e8f4", 0.45 if wait > 0.0 else 1.0)
            if b.kind == "gbone":
                var r := _gbone_rect(b)
                var capy: float = r.position.y if b.get("top", false) else r.end.y - 3.0
                draw_rect(r, bnc, true)
                draw_rect(Rect2(r.position.x - 1.0, capy, r.size.x + 2.0, 3.0), bnc, true)
            else:
                draw_rect(Rect2(b.pos.x - 3, b.pos.y - 8, 6, 16), bnc, true)
                draw_rect(Rect2(b.pos.x - 4, b.pos.y - 9, 8, 3), bnc, true)
                draw_rect(Rect2(b.pos.x - 4, b.pos.y + 6, 8, 3), bnc, true)
        elif wait > 0.0:           # снаряд «проклёвывается» — пульсирующее колечко
            draw_arc(b.pos, 4.5, 0, TAU, 10,
                     Color("#ffd0a0", 0.4 + 0.4 * sin(_bh_t * 22.0)), 1.5)
        elif b.kind == "homing":   # преследователь: крупный, с ядром
            draw_circle(b.pos, 5.5, Color("#ff8adc"))
            draw_circle(b.pos, 2.2, Color("#701848"))
        elif b.get("safe", false):  # 🟢 безвредная обманка: зелёное колечко
            draw_arc(b.pos, 4.0, 0, TAU, 10, Color("#6ee66e"), 1.6)
            draw_circle(b.pos, 1.6, Color("#6ee66e", 0.8))
        elif str(b.get("beh", "")) == "still":   # 🔵 синяя: замри — пройдёт сквозь
            draw_circle(b.pos, 4.2, Color("#4a72ff"))
            draw_rect(Rect2(b.pos.x - 1.5, b.pos.y - 1.5, 3, 3), Color("#dce6ff"), true)
        elif str(b.get("beh", "")) == "move":    # 🟠 оранжевая: беги — пройдёт сквозь
            draw_circle(b.pos, 4.2, Color("#ff9a2a"))
            draw_line(b.pos + Vector2(-3, 0), b.pos + Vector2(3, 0), Color("#7a4010"), 1.5)
        else:                      # цвет = скорость (голубая/жёлтая/красная)
            var bc: Color = SPEED_COL.get(int(b.get("cls", 1)), Color("#fff0a0"))
            draw_circle(b.pos, 4.6 if int(b.get("cls", 1)) == 2 else 4.0, bc)
    # искры-частицы (попадание, грейз, выстрел лазера)
    for s in sparks:
        var sa: float = clampf(float(s.t) * 4.0, 0.0, 1.0)
        draw_rect(Rect2(s.pos.x - 1.0, s.pos.y - 1.0, 2.0, 2.0), Color(s.col, sa), true)
    _draw_flash()


func _draw_flash() -> void:
    ## Белая вспышка-хитстоп поверх всего кадра (удар/смена фазы босса).
    if _hitflash > 0.0:
        draw_rect(Rect2(0, 0, 640, 480), Color(1, 1, 1, _hitflash * 2.2), true)
