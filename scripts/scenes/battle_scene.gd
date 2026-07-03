extends Control
## Бой в стиле Undertale: меню БОЙ/ДЕЙСТВИЕ/ПРЕДМЕТ/МИЛОСТЬ, ход врага = bullet-hell.
## Модель боя — Battle (core/battle.gd). Приёмы игрока — Attacks.
##
## ЭТА СЦЕНА — «АРЕНА-ХОСТ»: держит состояние поля (bullets/zones/forces/box/soul),
## гоняет жизненный цикл фазы уворота и предоставляет фабрики примитивов
## (spawn_shape/add_force/add_hazard_zone/…) — но НЕ знает про конкретные атаки.
## Конкретные угрозы описывают авторские киты боссов (scripts/battle/boss_*.gd,
## каждый уникален) и лёгкая моб-система (scripts/core/mob_threats.gd), собирая
## их из тулкита примитивов BulletKit (scripts/core/bullet_kit.gd).
##
## Задать до add_child: enemy=[имя,hp,dmg] ИЛИ boss_key, и danger/biome.

signal battle_over(result: String)     # "win" | "lose" | "flee"

var enemy = null
var boss_key = null
var danger := 1
var biome := ""      # биом локации — влияет на физику уворота ("" = без эффекта)

enum Phase { MESSAGE, MENU, SUB, BULLETS, DONE }
var phase: int = Phase.MESSAGE

var battle: Battle
var player: Player

# реестр авторских китов боссов (boss_key → файл кита)
const BOSS_KIT_PATHS := {
    "kalitin": "res://scripts/battle/boss_kalitin.gd",
    "tsizi": "res://scripts/battle/boss_tsizi.gd",
    "zhizha": "res://scripts/battle/boss_zhizha.gd",
    "overseer": "res://scripts/battle/boss_overseer.gd",
    "pekl_master": "res://scripts/battle/boss_pekl_master.gd",
    "tm": "res://scripts/battle/boss_tm.gd",
}

# UI
var enemy_label: Label
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

# ─── состояние арены (читается/пишется примитивами BulletKit и атаками) ───
var box := Rect2(222, 178, 196, 150)
var box_target := Rect2(222, 178, 196, 150)   # коробка «дышит» — плавно меняет форму
var _box_lerp := 9.0
var soul := Vector2.ZERO
var soul_vel := Vector2.ZERO
var soul_mode := "free"           # "free" | "blue" (гравитация и прыжки)
var bullets: Array = []           # фигурные угрозы (см. BulletKit.spawn_shape)
var zones: Array = []             # тайминговые зоны (опасные/безопасные)
var forces: Array = []            # силовые поля (ветер/вакуум/турбулентность/конвейер)
var corridor := Rect2()           # коридор ограниченного движения
var has_corridor := false
var _force_seq := 0

# драматургия хода/боя
var turn_no := 0                  # номер хода врага — боссы разгоняются от хода к ходу
var bh_t := 0.0                   # секунды с начала текущей фазы уворота
var _bh_dur := 4.6
var _stray_cd := 0.0              # таймер случайных «стрей»-пуль (только боссы, динамика)

# бой ведут АТАКИ (авторские) — до 2 одновременно (соло/комбо)
var _active_attacks: Array = []
var _kit = null                   # BossKit или null (тогда бой ведёт _mob_seq)
var _opening: Array = []          # срежиссированные первые биты босса
var _beat_i := 0
var _mob_seq: Array = []          # очередь простых угроз моба
var _mob_key := "mob"

# джус / хит-детект
var _iframe := 0.0
var _shake := 0.0
var _evade_t := 0.0
var _graze_t := 0.0
var _hitstop := 0.0
var _hitflash := 0.0
var _box_flash := 0.0
var sparks: Array = []
var _hit_r := 6.8                 # ДИНАМИЧЕСКИЙ хитбокс: плотнее шквал — меньше сердце

const SOUL_SPEED := 150.0
const SOUL_SIZE := 10.0
const GRAV := 560.0
const JUMP_V := 245.0
const HIT_R_MIN := 4.4
const HIT_R_MAX := 6.8
const GRAZE_R := 13.0


# ─────────────── свойства-контракт для атак (read-only снаружи) ───────────────
var phase2: bool:
    get:
        return battle != null and battle.phase2

var stage: int:
    get:
        return _compute_stage()

var warn_mult: float:
    get:
        match _compute_stage():
            2: return 0.85
            3: return 0.72
        return 1.0

var speed_mult: float:
    get:
        var st := _compute_stage()
        var base: float
        if st < 0:
            base = minf(1.05 + danger * 0.02, 1.3)      # мобы теперь шустрые (буллетхелл)
        else:
            base = [1.05, 1.12, 1.22, 1.34][st]
        return base * minf(1.0 + bh_t * 0.025, 1.15)


func _compute_stage() -> int:
    ## Драматургия босса: -1 мобы · 0 интро · 1 разгон · 2 фаза ярости · 3 финал.
    if boss_key == null:
        return -1
    var s := 0
    if turn_no >= 3:
        s = 1
    if battle != null and battle.phase2:
        s = 2
        if turn_no >= 8:
            s = 3
    return s


# ─────────────── фабрики примитивов (обёртки над BulletKit) ───────────────
func spawn_shape(shape: StringName, pos: Vector2, vel: Vector2, opts: Dictionary = {}) -> Dictionary:
    return BulletKit.spawn_shape(self, shape, pos, vel, opts)

func add_force(kind: StringName, opts: Dictionary = {}) -> int:
    return BulletKit.add_force(self, kind, opts)

func remove_force(id: int) -> void:
    BulletKit.remove_force(self, id)

func add_hazard_zone(rect: Rect2, opts: Dictionary = {}) -> Dictionary:
    return BulletKit.add_hazard_zone(self, rect, opts)

func add_safe_zone(rect: Rect2, opts: Dictionary = {}) -> Dictionary:
    return BulletKit.add_safe_zone(self, rect, opts)

func set_corridor(rect: Rect2, opts: Dictionary = {}) -> void:
    BulletKit.set_corridor(self, rect, opts)

func set_blue_mode(on: bool) -> void:
    BulletKit.set_blue_mode(self, on)

func move_box(target: Rect2, opts: Dictionary = {}) -> void:
    BulletKit.move_box(self, target, opts)


func _ready() -> void:
    player = GameState.player
    battle = Battle.new(player, boss_key, enemy, danger)
    _init_fight_ai()
    _build_ui()
    _refresh_stats()
    set_process_unhandled_input(true)
    _show_lines(["Тебе преградил путь %s!" % battle.ename], _to_menu)


func _init_fight_ai() -> void:
    ## Создаётся ОДИН раз на бой: кит босса и его opening живут через все ходы,
    ## `_beat_i` копится сквозь ходы — поэтому opening проигрывается ОДИН раз за
    ## бой, а дальше идёт pick(stage, phase2) с настоящей эскалацией 2-й фазы.
    if boss_key != null and BOSS_KIT_PATHS.has(boss_key):
        var scr = load(BOSS_KIT_PATHS[boss_key])
        if scr != null:
            _kit = scr.new()
            _opening = _kit.opening()
    if _kit == null:
        _mob_key = Sprites.mob_key(str(battle.ename))
    _beat_i = 0


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


# ─────────────── спецэффекты биома ───────────────
func _biome_kind() -> String:
    ## Биом влияет ТОЛЬКО на рамку/душу (не на выбор паттерна атаки — тот у
    ## мобов случаен и независим от биома/вида, см. MobThreats):
    ## "ice" — скольжение · "hot" — рамка меньше + стенки жгут (адские/данж) ·
    ## "goo" — вязко · "wind" — ветер сносит душу (пустоши/пустыня) · "" — обычный.
    if biome in ["ice", "opera_ice"]:
        return "ice"
    if biome in ["volcano", "hell"]:
        return "hot"
    if biome in ["swamp", "water", "jungle", "acidfield"]:
        return "goo"
    if biome in ["wastes", "waste2"]:
        return "wind"
    return ""


func _biome_tag() -> String:
    match _biome_kind():
        "ice": return " · ❄ СКОЛЬЗКО"
        "hot": return " · 🔥 ТЕСНО, СТЕНЫ ЖГУТ"
        "goo": return " · 🟢 ВЯЗКО"
        "wind": return " · 🌬 ВЕТЕР СНОСИТ"
    return ""


func _begin_bullets() -> void:
    phase = Phase.BULLETS
    turn_no += 1
    main_menu.hide_menu()
    sub_menu.hide_menu()
    log_label.text = ""
    box = Rect2(222, 178, 196, 150)
    # биом влияет только на рамку/душу — НЕ на выбор паттерна атаки (тот у мобов
    # случаен, см. MobThreats). Только для рядовых мобов (у боссов рамкой уже
    # управляет их авторский кит — не мешаем его собственной хореографии).
    if boss_key == null and _biome_kind() == "hot":
        var c := box.get_center()
        var sz := box.size * 0.72          # адское/данж пекло — теснее рамка
        box = Rect2(c - sz * 0.5, sz)
    box_target = box
    _box_lerp = 9.0
    soul = box.position + box.size * 0.5
    soul_vel = Vector2.ZERO
    soul_mode = "free"
    bullets.clear()
    zones.clear()
    forces.clear()
    sparks.clear()
    has_corridor = false
    corridor = Rect2()
    _force_seq = 0
    if boss_key == null and _biome_kind() == "wind":
        var wsign := 1.0 if randf() < 0.5 else -1.0   # пустоши/пустыня — сносит ветром
        add_force(&"wind", {"dir": Vector2(wsign * 44.0, 0.0), "gust": Vector2(wsign * 16.0, 6.0)})
    # мобы — короткий резкий буллет-хелл (выжить ~3-5с); боссы — ДЛИННАЯ фаза
    # уворота (ещё дольше в ярости и к финалу боя)
    if boss_key != null:
        _bh_dur = 14.0 + danger * 0.24 + (3.2 if battle.phase2 else 0.0) \
                + 0.9 * maxi(_compute_stage(), 0)
    else:
        _bh_dur = 3.4 + danger * 0.1
    bh_t = 0.0
    _iframe = 0.0
    _hitstop = 0.0
    _stray_cd = 0.7
    _hit_r = HIT_R_MAX
    # у мобов очередь угроз перегенерируется каждый ход; у босса кит/opening
    # ЖИВУТ через все ходы (создан в _init_fight_ai) — не сбрасываем _beat_i!
    if _kit == null:
        _mob_seq = MobThreats.sequence(_mob_key)
    _active_attacks = []
    _next_beat()
    queue_redraw()


func _next_beat() -> void:
    ## Взять следующий «бит»: у босса — сначала opening по порядку, затем pick();
    ## у моба — по одной простой угрозе из очереди (регенерируется, если кончилась).
    # сброс временных контролей арены перед новым битом (атака сама включит нужное)
    set_corridor(Rect2())
    soul_mode = "free"
    var beat: Array = []
    if _kit != null:
        if _beat_i < _opening.size():
            beat = _opening[_beat_i]
            _beat_i += 1
        else:
            beat = _kit.pick(stage, phase2)
    else:
        if _mob_seq.is_empty():
            _mob_seq = MobThreats.sequence(_mob_key)
        if not _mob_seq.is_empty():
            beat = [_mob_seq.pop_front()]
    _active_attacks = beat
    for a in _active_attacks:
        a.start(self)
    _update_hint()


func _update_hint() -> void:
    if _active_attacks.is_empty():
        hint_label.text = ""
        return
    var a = _active_attacks[0]
    if soul_mode == "blue":
        hint_label.text = "⚠ %s! Прыгай: ↑ или SPACE%s" % [a.name, _biome_tag()]
    else:
        var names: Array = []
        for x in _active_attacks:
            names.append(x.name)
        hint_label.text = "⚠ %s — %s%s" % [" + ".join(names), a.rule, _biome_tag()]


func _process(delta: float) -> void:
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
    # стоп-кадр при ударе: короткая заморозка продаёт импакт
    if _hitstop > 0.0:
        _hitstop -= delta
        queue_redraw()
        return
    bh_t += delta
    _iframe = max(0.0, _iframe - delta)

    # коробка «дышит» к целевой форме (переезд быстрый, с телеграф-вспышкой)
    box.position = box.position.lerp(box_target.position, _box_lerp * delta)
    box.size = box.size.lerp(box_target.size, _box_lerp * delta)

    # ── движение души: ввод + физика биома / синий режим ──
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
            "ice":
                soul_vel = soul_vel.lerp(dir * SOUL_SPEED, 3.6 * delta)
            "goo":
                soul_vel = dir * SOUL_SPEED * 0.78
            _:
                soul_vel = dir * SOUL_SPEED
    soul += soul_vel * delta

    # ── силовые поля двигают само сердце (между вводом и клампом) ──
    BulletKit.step_forces(self, delta)

    # ── кламп в коробку (и коридор, если задан) ──
    soul.x = clampf(soul.x, box.position.x + SOUL_SIZE, box.position.x + box.size.x - SOUL_SIZE)
    soul.y = clampf(soul.y, box.position.y + SOUL_SIZE, box.position.y + box.size.y - SOUL_SIZE)
    if has_corridor:
        soul.x = clampf(soul.x, corridor.position.x + SOUL_SIZE, corridor.end.x - SOUL_SIZE)
        soul.y = clampf(soul.y, corridor.position.y + SOUL_SIZE, corridor.end.y - SOUL_SIZE)
    if soul_mode == "blue":
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
        if soul_mode != "blue":
            burn = burn or soul.y >= box.end.y - SOUL_SIZE - eps
        if burn:
            Sfx.play("hurt")
            player.damage(2)
            _shake = 4.0
            _iframe = 0.45
            _refresh_stats()

    # ── динамика боссов: случайные «стрей»-пули там-сям (резче + разнообразнее) ──
    # чисто арена-уровневый слой поверх авторских атак; у мобов и в синем режиме нет
    if boss_key != null and soul_mode != "blue" and bh_t < _bh_dur - 0.6:
        _stray_cd -= delta
        if _stray_cd <= 0.0:
            var st := _compute_stage()
            _stray_cd = maxf(0.26, randf_range(0.55, 0.95) - 0.06 * st)
            _spawn_stray(st)

    # ── динамический хитбокс: плотнее шквал — меньше сердце ──
    var dens := 0
    for b in bullets:
        if not b.get("safe", false) and float(b.get("warn", 0.0)) <= 0.0:
            dens += 1
    dens += zones.size()
    _hit_r = lerpf(_hit_r, clampf(HIT_R_MAX - float(dens) * 0.1, HIT_R_MIN, HIT_R_MAX),
                   6.0 * delta)

    # ── угрозы: движение/зоны/столкновения (централизованный урон) ──
    BulletKit.step_hazards(self, delta)

    # ── искры-частицы ──
    var salive: Array = []
    for s in sparks:
        s.t = float(s.t) - delta
        if float(s.t) > 0.0:
            s.pos += s.vel * delta
            salive.append(s)
    sparks = salive

    # ── прогон авторских атак + смена бита ──
    var all_done := true
    for a in _active_attacks:
        if not a.done:
            a.tick(self, delta)
        if not a.done:
            all_done = false
    if all_done and bh_t < _bh_dur - 0.3:
        _next_beat()

    if bh_t >= _bh_dur or not player.is_alive():
        _end_bullets()
    queue_redraw()


func _bullet_hit() -> void:
    # шанс уворота: Блок% (щит/оберег) + зелье уворота → угроза проходит сквозь
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
    _hitstop = 0.08
    _hitflash = 0.14
    _spark_burst(soul, 7, Color("#ff8a7a"))
    _iframe = 0.7
    _refresh_stats()


func _spawn_stray(st: int) -> void:
    ## Случайная одиночная угроза с края арены — «оживляет» бой босса и добавляет
    ## разнообразия. Всегда телеграфирована и одиночна → честно уворачиваемо.
    var b := box
    var edge := randi() % 4
    var p: Vector2
    match edge:
        0: p = Vector2(randf_range(b.position.x, b.end.x), b.position.y - 16.0)
        1: p = Vector2(randf_range(b.position.x, b.end.x), b.end.y + 16.0)
        2: p = Vector2(b.position.x - 16.0, randf_range(b.position.y, b.end.y))
        _: p = Vector2(b.end.x + 16.0, randf_range(b.position.y, b.end.y))
    var spd := 84.0 + float(st) * 10.0
    var roll := randf()
    if roll < 0.5:                       # наводится в текущую позицию души
        var v := (soul - p).normalized() * spd
        spawn_shape(&"rect", p, v, {"size": Vector2(11, 8), "angle": v.angle(),
            "warn": 0.28, "tint": Color("#ffd08a")})
    elif roll < 0.8:                     # мелкое лезвие наискось через арену
        var v2 := (b.get_center() - p).normalized().rotated(randf_range(-0.5, 0.5)) * spd
        spawn_shape(&"blade", p, v2, {"size": Vector2(16, 6), "angle": v2.angle(),
            "warn": 0.26, "tint": Color("#e0a0ff")})
    else:                                # парная мелочь веером
        var v3 := (soul - p).normalized() * (spd * 0.9)
        spawn_shape(&"rect", p, v3, {"size": Vector2(9, 7), "angle": v3.angle(),
            "warn": 0.3, "tint": Color("#ffd08a")})
        var v3b := v3.rotated(0.32)
        spawn_shape(&"rect", p, v3b, {"size": Vector2(9, 7), "angle": v3b.angle(),
            "warn": 0.3, "tint": Color("#ffd08a")})


func _spark_burst(p: Vector2, n: int, col: Color) -> void:
    if sparks.size() > 90:
        return
    for _i in range(n):
        sparks.append({"pos": p, "t": randf_range(0.18, 0.32), "col": col,
            "vel": Vector2.from_angle(randf() * TAU) * randf_range(40.0, 110.0)})


func _end_bullets() -> void:
    bullets.clear()
    zones.clear()
    forces.clear()
    sparks.clear()
    _active_attacks.clear()
    soul_mode = "free"
    has_corridor = false
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


# ─────────────── отрисовка ───────────────
func _draw() -> void:
    draw_rect(Rect2(0, 0, 640, 480), Color("#0a0a12"), true)
    var ekey: String = boss_key if (boss_key != null and Sprites.has(boss_key)) else Sprites.mob_key(battle.ename)
    Sprites.draw_grid(self, Rect2(268, 44, 104, 96), ekey)
    if phase != Phase.BULLETS:
        _draw_flash()
        return
    # рамка коробки — цвет биома
    match _biome_kind():
        "hot":
            var hp2 := 0.5 + 0.5 * sin(bh_t * 6.0)
            draw_rect(box, Color("#ff5a2a").lightened(0.25 * hp2), false, 3.0)
        "ice":
            draw_rect(box, Color("#a8dcec"), false, 2.0)
        "goo":
            draw_rect(box, Color("#6ee66e"), false, 2.0)
        "wind":
            draw_rect(box, Color("#d8c090"), false, 2.0)
        _:
            draw_rect(box, Color("#e8e8ff"), false, 2.0)
    if _box_flash > 0.0:
        draw_rect(box.grow(2.0), Color(1, 1, 1, _box_flash * 1.8), false, 2.0)
    if soul_mode == "blue":
        draw_line(Vector2(box.position.x + 2, box.end.y - 2),
                  Vector2(box.end.x - 2, box.end.y - 2), Color("#4a72ff", 0.7), 2.0)

    # поля, зоны, фигурные угрозы — рисует тулкит примитивов
    BulletKit.draw_all(self)

    # душа-сердечко (динамический размер + свечение при сжатом хитбоксе)
    var col := Color("#ff5a5a") if _iframe > 0.0 else Color("#ff2b2b")
    if soul_mode == "blue":
        col = Color("#7a95ff") if _iframe > 0.0 else Color("#3a5aff")
    var hsz: float = SOUL_SIZE * 1.6 * (0.72 + 0.28 * _hit_r / HIT_R_MAX)
    Sprites.draw_heart(self, soul, hsz, col)
    if _hit_r < 5.4:
        draw_arc(soul, hsz * 0.5 + 2.5, 0, TAU, 12, Color(1, 1, 1, 0.35), 1.0)
    if _evade_t > 0.0:
        draw_arc(soul, 10.0 + (0.45 - _evade_t) * 26.0, 0, TAU, 16,
                 Color("#b8f0ff", _evade_t * 1.6), 2.0)
    if _graze_t > 0.0:
        draw_arc(soul, 9.0, 0, TAU, 12, Color("#b8f0ff", _graze_t * 1.2), 1.5)

    # искры
    for s in sparks:
        var sa: float = clampf(float(s.t) * 4.0, 0.0, 1.0)
        draw_rect(Rect2(s.pos.x - 1.0, s.pos.y - 1.0, 2.0, 2.0), Color(s.col, sa), true)
    _draw_flash()


func _draw_flash() -> void:
    if _hitflash > 0.0:
        draw_rect(Rect2(0, 0, 640, 480), Color(1, 1, 1, _hitflash * 2.2), true)
