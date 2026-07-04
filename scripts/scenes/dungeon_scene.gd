extends Control
## 🔥 АДСКАЯ ШАХТА — бесконечное подземелье про Пекло и «ТМ».
##
## Правила: перебей всех в комнате → правая дверь откроется. Назад — свободно.
## Выход из шахты сбрасывает этажи, но добытый лут остаётся при тебе.
##
## Расписание (20-этажный цикл): этаж 5 — стражник (Надзиратель), 10 — мини-босс
## (Магистр Пекла), 11/13/17/19 — снова стражник (бьёт больно, файт короткий),
## 15 — мини-босс, 20 — «ТМ». После ТМ цикл повторяется (40, 60…), но шахта
## переходит в «ПЕКЛО II/III…»: все твари «Пепельные» (жирнее и злее), их больше,
## лава жжёт сильнее, рыбы плюются чаще — зато сундуков больше и редкий лут чаще.
## Сложность заметно растёт к ТМ (danger доходит до потолка к ~18 этажу).
##
## Комнаты: обычные / завалы / лавовые реки и озёра / ВОДЯНЫЕ озёра с рыбами /
## кристальные пещеры / грибные гроты / костяные залы / пепельные зоны (после ТМ).
## Палитра стен/пола меняется по глубине — ярусы выглядят по-разному.
## Сундуки: с 10 этажа шанс на два сразу; 5% — золотой (заметно жирнее лут).

signal closed()

const TILE := 16
const MOVE_REPEAT := 0.11

# палитры ярусов [стена, шов стены, пол, пол-вариация] — глубина выглядит по-разному
const PAL_BANDS := [
    ["#1b1622", "#262030", "#141019", "#1c1622"],   # 1-4: старая шахта (фиолет)
    ["#241318", "#332028", "#170f12", "#1f1418"],   # 5-9: ржавые глубины
    ["#1c1428", "#2a2040", "#120e1c", "#1a1428"],   # 10-14: аметистовый ярус
    ["#101422", "#1a2234", "#0a0e18", "#121824"],   # 15-19: предтемье
]
const PAL_TM := ["#0a080e", "#161020", "#060409", "#0c0810"]      # 20: тьма ТМ
const PAL_ASH := ["#251d1d", "#362a28", "#161010", "#201616"]     # 21+: пепелище
const COL_ROCK := Color("#3a3542")
const COL_ROCK_HI := Color("#4c4658")


func _pal() -> Array:
    ## Палитра текущего этажа: до ТМ — по ярусам, этаж ТМ — почти чернота,
    ## после ТМ — пепелище (визуально сразу видно «сезон 2»).
    if _cycle_of(depth) >= 1:
        return PAL_ASH
    var l := ((depth - 1) % 20) + 1
    if l == 20:
        return PAL_TM
    return PAL_BANDS[clampi(int((l - 1) / 5.0), 0, PAL_BANDS.size() - 1)]

# ─── лор: кринж про Пекло и «ТМ» ───
const LORE_INTRO := [
    "Шахтёры копали бурмолду слишком глубоко — и докопались до ПЕКЛА.",
    "Внизу живёт «ТМ». Расшифровки не знает никто. Спросить боятся все.",
]
# лор-этажи (только там, где нет стражника/босса: те заняты своими репликами)
const LORE_FLOORS := {
    2: "На стене выцарапано: «ТМ видит тебя. тм.»",
    4: "Чей-то дневник: «день 40. кирка сгорела. зато свэг цел.»",
    6: "Кости шахтёра сложены в слово «БЕГИ». Педантично.",
    9: "Табличка: «Этаж 10. Дальше — administración Пекла.»",
    12: "«ТМ — это Тёмный Мастер? Тотальный Мрак? Твоя Мамка?» — надписи спорят.",
    14: "Плакат: «Стражники ходят через этаж. Жалобы — в лаву.»",
    16: "Стало тихо. Даже лава течёт шёпотом.",
    18: "Пол дрожит. Что-то внизу ставит басы. За следующими дверями — ОНО. «тм.»",
    21: "Ты прошёл ТМ… а шахта не кончилась. Пекло открывает СЕЗОН 2. Всё пепельное.",
    23: "Здесь даже кринж горит. Пепельные твари смотрят голодно.",
    26: "Дневник новичка: «сезон 2 говорили они. весело говорили они.»",
}
const MINIBOSS_QUIP := "Надзиратель щёлкает плетью: «Смена не окончена, головастик!»"
const BOSS_QUIP := "Магистр Пекла поправляет огненную корону: «По записи?»"
const TM_QUIP := "…свет гаснет. Из тьмы смотрят четыре глаза. «тм», — говорит ТМ."
const TM_WIN := ["ТМ растворяется во тьме: «тм… (это значило „та мы ещё встретимся“)»",
                 "🏆 Ты победил НЕЧТО. Пекло аплодирует копытами."]

var depth := 1
var rooms: Dictionary = {}       # этаж -> состояние комнаты (на время визита)
var st: Dictionary               # текущая комната
var ppos := Vector2i.ZERO
var busy := false
var projectiles: Array = []      # плевки лавовых рыб: {pos: Vector2, vel: Vector2}
var _anim_t := 0.0
var _move_cd := 0.0
var _lava_cd := 0.0              # неуязвимость между ожогами лавы (i-frame)
var info: Label
var lore_lbl: Label
var overlay: CanvasLayer
var font: Font


func _ready() -> void:
    font = ThemeDB.fallback_font
    info = Label.new()
    info.position = Vector2(12, 6)
    info.size = Vector2(616, 40)
    info.add_theme_font_size_override("font_size", 13)
    add_child(info)
    lore_lbl = Label.new()
    lore_lbl.position = Vector2(12, 440)
    lore_lbl.size = Vector2(616, 36)
    lore_lbl.add_theme_font_size_override("font_size", 13)
    lore_lbl.add_theme_color_override("font_color", Color("#b09ac0"))
    lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(lore_lbl)
    overlay = CanvasLayer.new()
    overlay.layer = 10
    add_child(overlay)
    _enter_room(1, false)
    lore_lbl.text = LORE_INTRO[0] + "\n" + LORE_INTRO[1]


# ─────────────── этажи и генерация ───────────────
func _danger() -> int:
    # заметный рост к ТМ: потолок 10 достигается уже к ~18 этажу
    return clampi(3 + int(depth / 2.5), 3, 10)


static func _cycle_of(d: int) -> int:
    ## Сколько ТМ уже пройдено на пути к этажу d (0 до первого ТМ на 20-м).
    ## cycle >= 1 — режим «ПЕКЛО II/III…»: жёстче враги, жирнее сундуки.
    return int((d - 1) / 20.0)


static func _schedule_kind(d: int) -> String:
    ## Расписание боссов в 20-этажном цикле (повторяется после каждого ТМ):
    ## 5 — стражник · 10, 15 — мини-босс · 11/13/17/19 — стражник · 20 — ТМ.
    var l := ((d - 1) % 20) + 1
    if l == 20:
        return "tm"
    if l == 10 or l == 15:
        return "boss"
    if l == 5 or (l >= 11 and l % 2 == 1):
        return "mini"
    return ""


func _midy() -> int:
    return int(st.h / 2.0)


func _enter_room(d: int, from_back: bool) -> void:
    depth = d
    if rooms.has(d):
        st = rooms[d]
    else:
        st = _gen_room(d)
        rooms[d] = st
    projectiles.clear()
    ppos = Vector2i(int(st.w) - 2, _midy()) if from_back else Vector2i(1, _midy())
    _update_info()
    if LORE_FLOORS.has(d):
        lore_lbl.text = "📜 " + LORE_FLOORS[d]
    elif st.kind == "tm":
        lore_lbl.text = "📜 " + TM_QUIP
    elif st.kind == "boss":
        lore_lbl.text = "📜 " + BOSS_QUIP
    elif st.kind == "mini":
        lore_lbl.text = "📜 " + MINIBOSS_QUIP
    if st.kind == "tm" and not st.get("announced", false):
        st["announced"] = true
        _tm_poster()
    queue_redraw()


func _gen_room(d: int, force_kind := "") -> Dictionary:
    var s := {"w": 0, "h": 0, "grid": [], "mobs": [], "chests": [],
              "fish": [], "torches": [], "kind": "plain"}
    var cycle := _cycle_of(d)
    # тип комнаты: боссы по расписанию, иначе — разнообразие (глубже — больше видов)
    if force_kind != "":
        s.kind = force_kind
    else:
        s.kind = _schedule_kind(d)
        if s.kind == "":
            var pool := ["plain", "rocky", "lava_river", "lava_lake",
                         "water_lake", "bones"]
            if d >= 6:
                pool.append_array(["crystal", "mushroom"])
            if cycle >= 1:
                pool.append_array(["ash", "ash"])   # после ТМ — пепельные зоны
            s.kind = pool[randi() % pool.size()]

    var w := 24 if s.kind in ["boss", "mini", "tm"] else randi_range(22, 30)
    var h := 13 if s.kind in ["boss", "mini", "tm"] else randi_range(11, 14)
    s.w = w
    s.h = h
    var midy := int(h / 2.0)
    for y in h:
        var row := ""
        for x in w:
            row += "#" if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else "."
        s.grid.append(row)

    # факелы на верхней/нижней стене (анимируются при отрисовке)
    var tx := 3
    while tx < w - 2:
        s.torches.append(Vector2i(tx, 0))
        s.torches.append(Vector2i(mini(tx + 2, w - 3), h - 1))
        tx += 5

    match s.kind:
        "rocky":
            for _i in range(randi_range(9, 15)):
                _scatter(s, "R", midy)
        "plain", "ash":
            for _i in range(randi_range(3, 7)):
                _scatter(s, "R", midy)
        "crystal":
            # кристальная пещера: светящиеся кристаллы (непроходимы)
            for _i in range(randi_range(6, 11)):
                _scatter(s, "C", midy)
        "mushroom":
            # грибной грот: светящиеся грибы (ПРОХОДИМЫ — просто красиво)
            for _i in range(randi_range(9, 15)):
                _scatter(s, "M", midy)
            for _i in range(randi_range(2, 4)):
                _scatter(s, "R", midy)
        "bones":
            # костяной зал: завалы костей (непроходимы)
            for _i in range(randi_range(6, 10)):
                _scatter(s, "K", midy)
        "lava_river":
            # вертикальная река лавы с мостом на уровне дверей
            var rx := randi_range(int(w * 0.35), int(w * 0.6))
            for y in range(1, h - 1):
                if absi(y - midy) > 1:
                    _put(s, Vector2i(rx, y), "L")
                    if randf() < 0.5 and rx + 1 < w - 1:
                        _put(s, Vector2i(rx + 1, y), "L")
        "lava_lake", "water_lake":
            # озеро строго в верхней или нижней половине (ряд дверей не трогаем);
            # water_lake — обычная вода с безобидными рыбами (анимация из надмира)
            var tile_ch := "L" if s.kind == "lava_lake" else "~"
            var cy: int
            if randf() < 0.5 or midy + 3 > h - 4:
                cy = randi_range(2, maxi(2, midy - 3))
            else:
                cy = randi_range(midy + 3, h - 4)
            var cx := randi_range(5, w - 6)
            for y in range(1, h - 1):
                for x in range(1, w - 1):
                    if Vector2(x - cx, (y - cy) * 1.4).length() < 2.9:
                        _put(s, Vector2i(x, y), tile_ch)
            var nfish := 2 if s.kind == "lava_lake" else 3
            for _i in range(nfish):
                s.fish.append({"pos": Vector2i(clampi(cx + randi_range(-1, 1), 1, w - 2),
                                               clampi(cy + randi_range(-1, 1), 1, h - 2)),
                               "off": randf() * 6.0, "spd": randf_range(0.7, 1.1),
                               "water": s.kind == "water_lake"})

    # мобы: у боссов — один; у обычных комнат пачка из пула Пекла
    # (после ТМ тварей заметно больше)
    if s.kind in ["boss", "mini", "tm"]:
        s.mobs.append({"pos": Vector2i(int(w / 2.0), midy), "enemy": _boss_enemy(d, s.kind),
                       "alive": true, "boss": true})
        s.chests.append({"pos": Vector2i(w - 3, midy - 2), "opened": false,
                         "gold": s.kind == "tm" or randf() < 0.05 + 0.04 * cycle})
    else:
        var nmobs := randi_range(2, mini(4, 2 + int(d / 4.0)))
        if cycle >= 1:
            nmobs = randi_range(3, 6)
        for _m in range(nmobs):
            var t := _free_tile(s, midy)
            if t.x > 0:
                s.mobs.append({"pos": t, "enemy": _mob_enemy(d), "alive": true, "boss": false})
        # сундуки: базовый шанс; с 10 этажа — шанс на ДВА сразу;
        # после ТМ — на локации их стабильно больше
        var want := 1 if randf() < 0.45 else 0
        if cycle >= 1:
            want += 1
        if d >= 10 and want >= 1 and randf() < 0.35:
            want += 1
        for _c in range(want):
            var ct := _free_tile(s, -1)
            if ct.x > 0:
                s.chests.append({"pos": ct, "opened": false,
                                 "gold": randf() < 0.05 + 0.04 * cycle})
    return s


func _scatter(s: Dictionary, ch: String, keep_row: int) -> void:
    for _t in range(40):
        var p := Vector2i(randi_range(2, int(s.w) - 3), randi_range(2, int(s.h) - 3))
        if p.y != keep_row and _cell_of(s, p) == ".":
            _put(s, p, ch)
            return


func _free_tile(s: Dictionary, avoid_row: int) -> Vector2i:
    for _t in range(60):
        var p := Vector2i(randi_range(2, int(s.w) - 3), randi_range(1, int(s.h) - 2))
        if p.y == avoid_row or _cell_of(s, p) != ".":
            continue
        var taken := false
        for m in s.mobs:
            if m.pos == p:
                taken = true
        for c in s.chests:
            if c.pos == p:
                taken = true
        if not taken:
            return p
    return Vector2i(-1, -1)


func _mob_enemy(d: int) -> Array:
    ## Пул растёт с глубиной: свои твари Пекла + гости из надмира + новые
    ## кринж-виды. После ТМ все получают приставку «Пепельный» и жир по статам.
    var cycle := _cycle_of(d)
    var pool := [
        ["Зольный Жук", 16, 4], ["Уголёк-Живчик", 12, 5],
        ["Шахтная Крыса-Кринж", 14, 4], ["Шлаковый Паук", 15, 4],
    ]
    if d >= 5:
        pool.append_array([
            ["Магмовый Краб", 22, 4], ["Тень Шахтёра", 18, 5],
            ["Лавовый Слизень", 20, 4], ["Летучая Кринж-Мышь", 13, 6],
        ])
    if d >= 11:
        pool.append_array([
            ["Магмовый Голем", 30, 6], ["Горелый Сигма-Бес", 20, 7],
            ["Призрак Забоя", 22, 6],
        ])
    var e: Array = pool[randi() % pool.size()]
    var nm: String = e[0]
    var hp := int((int(e[1]) + d * 3) * (1.0 + 0.8 * cycle))
    var dm := int((int(e[2]) + int(d / 2.0)) * (1.0 + 0.5 * cycle))
    if cycle >= 1:
        nm = "Пепельный " + nm
    return [nm, hp, dm]


func _boss_enemy(d: int, kind: String) -> Array:
    var cycle := _cycle_of(d)
    var mh := 1.0 + 0.8 * cycle       # после каждого ТМ боссы жиреют
    var md := 1.0 + 0.5 * cycle
    match kind:
        "tm":
            return ["ТМ", int((260 + d * 10) * mh), int((14 + d / 2.0) * md)]
        "boss":
            return ["Магистр Пекла", int((120 + d * 8) * mh), int((10 + d / 2.0) * md)]
    # стражник: бьёт ЗАМЕТНО больнее, но сам тоньше — короткая жёсткая стычка
    # (короткую фазу уворота даёт battle_scene: overseer's _bh_dur x0.7)
    return ["Надзиратель Пекла", int((50 + d * 5) * mh), int((12 + d * 0.8) * md)]


# ─────────────── доступ к клеткам ───────────────
func _cell_of(s: Dictionary, p: Vector2i) -> String:
    if p.y < 0 or p.y >= s.grid.size():
        return "#"
    var row: String = s.grid[p.y]
    if p.x < 0 or p.x >= row.length():
        return "#"
    return row[p.x]


func _cell(p: Vector2i) -> String:
    return _cell_of(st, p)


func _put(s: Dictionary, p: Vector2i, ch: String) -> void:
    s.grid[p.y] = String(s.grid[p.y]).substr(0, p.x) + ch + String(s.grid[p.y]).substr(p.x + 1)


func _all_dead() -> bool:
    for m in st.mobs:
        if m.alive:
            return false
    return true


# ─────────────── движение / процесс ───────────────
func _process(delta: float) -> void:
    if busy:
        return
    _anim_t += delta
    _move_cd -= delta
    _lava_cd = maxf(0.0, _lava_cd - delta)
    if _move_cd <= 0.0:
        var dx := int(Input.get_axis("ui_left", "ui_right"))
        var dy := int(Input.get_axis("ui_up", "ui_down"))
        if dx != 0:
            dy = 0
        if dx != 0 or dy != 0:
            _try_move(dx, dy)
            _move_cd = MOVE_REPEAT
    if busy:
        return
    _fish_step(delta)
    queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
    if busy:
        return
    if event.is_action_pressed("ui_cancel"):
        lore_lbl.text = "Ты выбираешься из шахты. Пекло всё запомнит. «тм.»"
        closed.emit()


func _try_move(dx: int, dy: int) -> void:
    var t := ppos + Vector2i(dx, dy)
    var midy := _midy()
    # левая дверь: назад свободно (с 1-го этажа — наружу)
    if t == Vector2i(0, midy):
        if depth == 1:
            closed.emit()
        else:
            _enter_room(depth - 1, true)
        return
    # правая дверь: вперёд, только если все мертвы
    if t == Vector2i(int(st.w) - 1, midy):
        if _all_dead():
            _enter_room(depth + 1, false)
        else:
            _flash("🚪 Дверь заперта: перебей всех тварей в комнате!")
        return
    for m in st.mobs:
        if m.alive and m.pos == t:
            _fight(m)
            return
    var ch := _cell(t)
    if ch != "." and ch != "M":       # грибы проходимы (просто декор под ногами)
        return
    ppos = t
    # сундук — открывается наступанием
    for c in st.chests:
        if not c.opened and c.pos == ppos:
            _open_chest(c)
    # лава жжёт, если прошёл ВПЛОТНУЮ (с неуязвимостью между ожогами);
    # после ТМ жар злее: больнее и чаще
    for d4 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        if _cell(ppos + d4) == "L" and _lava_cd <= 0.0:
            _lava_cd = 0.6 if _cycle_of(depth) == 0 else 0.45
            var dmg := 2 + int(depth / 4.0) + 2 * _cycle_of(depth)
            GameState.player.damage(dmg)
            Sfx.play("hurt")
            _flash("🔥 Жар лавы: -%d HP!" % dmg)
            if not GameState.player.is_alive():
                GameState.player.hp = 1
                GameState.player.flags["_hell_spit"] = true
                closed.emit()
                return
            break
    _update_info()
    queue_redraw()


# ─────────────── рыбы: лавовые плюются, водяные — просто красота ───────────────
func _fish_step(delta: float) -> void:
    var spit_rate := 0.30 if _cycle_of(depth) == 0 else 0.55   # после ТМ — чаще
    for f in st.fish:
        if f.get("water", false):
            continue                   # водяная рыба безобидна (декор из надмира)
        if randf() < delta * spit_rate:
            var dir := Vector2.from_angle(randf() * TAU)
            projectiles.append({"pos": Vector2(f.pos * TILE) + _off() + Vector2(8, 8),
                                "vel": dir * (34.0 + 10.0 * _cycle_of(depth))})
    var alive: Array = []
    var prect := Rect2(Vector2(ppos * TILE) + _off() + Vector2(3, 3), Vector2(10, 10))
    for pr in projectiles:
        pr.pos += pr.vel * delta
        var tile := Vector2i((pr.pos - _off()) / TILE)
        var ch := _cell(tile)
        if ch == "#" or ch == "R" or ch == "C" or ch == "K":
            continue                    # разбился о стену/кристалл/кости
        if prect.has_point(pr.pos):
            var dmg := 2 + int(depth / 5.0)
            GameState.player.damage(dmg)
            Sfx.play("hurt")
            _flash("💥 Лавовый плевок: -%d HP!" % dmg)
            if not GameState.player.is_alive():
                GameState.player.hp = 1
                GameState.player.flags["_hell_spit"] = true
                closed.emit()
                return
            continue
        alive.append(pr)
    projectiles = alive


# ─────────────── бой / лут ───────────────
const HELL_BOSS_KEY := {"mini": "overseer", "boss": "pekl_master", "tm": "tm"}

func _fight(m: Dictionary) -> void:
    busy = true
    var b = load("res://scenes/Battle.tscn").instantiate()
    b.enemy = m.enemy
    b.danger = _danger()
    b.biome = "hell"    # Пекло — рамка теснее + стены жгут (тот же эффект, что вулкан/ад в надмире)
    # боссы Пекла ведут бой авторскими китами (мувсет по типу комнаты); HP/урон
    # по-прежнему считаются формулой шахты (_boss_enemy) — boss_key НЕ тянет
    # мировой BOSS_HP_MULT, т.к. этих ключей нет в DataDB.bosses.
    if m.get("boss", false) and HELL_BOSS_KEY.has(st.kind):
        b.boss_key = HELL_BOSS_KEY[st.kind]
    b.battle_over.connect(_after_fight.bind(b, m))
    overlay.add_child(b)


func _after_fight(result: String, node: Node, m: Dictionary) -> void:
    node.queue_free()
    busy = false
    if result == "lose":
        GameState.player.flags["_hell_spit"] = true
        closed.emit()
        return
    if result == "win":
        m.alive = false
        if m.get("boss", false):
            _boss_drop(m)
        if _all_dead():
            _flash("✅ Комната зачищена — правая дверь открыта!")
    _update_info()
    queue_redraw()


func _boss_drop(m: Dictionary) -> void:
    ## Боссы Пекла: гарантированный лут + шанс кольца + лор.
    var p := GameState.player
    var lines := Loot.grant(p, _danger() + 2, true)
    p.add_item("сердце пекла")
    lines.append("🎁 Трофей: сердце пекла")
    if randf() < 0.35:
        var rid = Items.random_item(5, "ring")
        if rid != null:
            p.add_item(rid)
            lines.append("💍 Редкий дроп: %s!" % Items.get_item(rid)["name"])
    if str(m.enemy[0]) == "ТМ":
        p.flags["tm_defeated"] = true
        p.burmolda += 400
        p.add_cringe(120)
        lines.append_array(TM_WIN)
    lore_lbl.text = "\n".join(lines)


func _open_chest(c: Dictionary) -> void:
    c.opened = true
    Sfx.play("win")
    var p := GameState.player
    var cycle := _cycle_of(depth)
    var gold: bool = c.get("gold", false)
    # золотой сундук — жирнее лут (как босс-дроп); после ТМ всё чуть щедрее
    var lines := Loot.grant(p, _danger() + 1 + 2 * cycle + (2 if gold else 0), gold)
    if gold:
        lines.push_front("✨ ЗОЛОТОЙ СУНДУК!")
    if randf() < 0.5:
        p.add_item("пепел ТМ")
        lines.append("🎒 добыто: пепел ТМ")
    if randf() < 0.3 + (0.25 if gold else 0.0) + 0.1 * cycle:
        p.add_item("зольный слиток")
        lines.append("🎒 добыто: зольный слиток")
    # редкий лут: у золотого шанс кольца, после ТМ он есть и у обычного
    var ring_chance := 0.30 if gold else 0.06 * cycle
    if randf() < ring_chance:
        var rid = Items.random_item(5, "ring")
        if rid != null:
            p.add_item(rid)
            lines.append("💍 РЕДКОЕ: %s!" % Items.get_item(rid)["name"])
    var ozu_chance := 0.07 + (0.11 if gold else 0.0) + 0.03 * cycle
    if randf() < ozu_chance:      # редчайший дроп — планка ОЗУ (квест Зава Воздуха)
        p.add_item("ОЗУ")
        lines.append("💾 РЕДЧАЙШЕЕ: планка ОЗУ! (Зав Воздуха отдаст за неё что угодно)")
    lore_lbl.text = "📦 " + " · ".join(lines)


func _tm_poster() -> void:
    busy = true
    var poster = load("res://scenes/Poster.tscn").instantiate()
    poster.title_text = "ТМ"
    poster.subtitle_text = "★ НЕЧТО ИЗ ГЛУБИН ★"
    poster.color = Color("#5a2a9a")
    poster.sprite_key = "tm"
    poster.flavor = "Никто не знает расшифровки. «тм», — говорит ТМ."
    poster.done.connect(func():
        poster.queue_free()
        busy = false)
    overlay.add_child(poster)


# ─────────────── HUD ───────────────
func _flash(msg: String) -> void:
    _update_info()
    info.text += "\n" + msg


const ROMAN := ["II", "III", "IV", "V", "VI"]

func _update_info() -> void:
    var p := GameState.player
    var left := 0
    for m in st.mobs:
        if m.alive:
            left += 1
    var season := ""
    var cyc := _cycle_of(depth)
    if cyc >= 1:
        season = " · 💀 ПЕКЛО %s" % ROMAN[mini(cyc - 1, ROMAN.size() - 1)]
    info.text = "🔥 АДСКАЯ ШАХТА · этаж %d%s · врагов: %d · ♥ %d/%d · ⛃ %d\n← дверь назад · → дверь дальше (после зачистки) · ESC — выйти (сброс этажей)" % [
        depth, season, left, p.hp, p.max_hp, p.burmolda]


# ─────────────── отрисовка ───────────────
func _off() -> Vector2:
    return Vector2((640 - int(st.w) * TILE) * 0.5, 52 + (380 - int(st.h) * TILE) * 0.5)


func _draw() -> void:
    draw_rect(Rect2(0, 0, 640, 480), Color("#0b0810"), true)
    if st.is_empty():
        return
    var pal := _pal()
    var c_wall := Color(pal[0])
    var c_wall2 := Color(pal[1])
    var c_floor := Color(pal[2])
    var c_floor2 := Color(pal[3])
    var off := _off()
    var midy := _midy()
    for y in st.grid.size():
        var row: String = st.grid[y]
        for x in row.length():
            var ch := row[x]
            var r := Rect2(off.x + x * TILE, off.y + y * TILE, TILE, TILE)
            var h: int = (x * 7 + y * 13 + depth * 31) % 97
            match ch:
                "#":
                    draw_rect(r, c_wall, true)
                    if h % 3 == 0:
                        draw_rect(Rect2(r.position.x, r.position.y + 7, TILE, 1), c_wall2, true)
                    if h % 4 == 1:
                        draw_rect(Rect2(r.position.x + 7, r.position.y, 1, 8), c_wall2, true)
                "R":
                    draw_rect(r, c_floor, true)
                    draw_circle(r.get_center() + Vector2(0, 2), 6.0, COL_ROCK)
                    draw_circle(r.get_center() + Vector2(-2, 0), 4.5, COL_ROCK_HI)
                "L":
                    # лава: тёмное ядро + бегущие прожилки + взлетающие искры
                    draw_rect(r, Color("#8a2c10"), true)
                    var wo := int(float(h) + _anim_t * 4.0) % 8
                    draw_rect(Rect2(r.position.x + wo, r.position.y + 4, 6, 2), Color("#e05a1a"), true)
                    draw_rect(Rect2(r.position.x + (wo + 4) % 8, r.position.y + 10, 5, 2), Color("#ff8a3a"), true)
                    if h % 6 == 0:
                        var bub := 0.5 + 0.5 * sin(_anim_t * 3.0 + float(h))
                        draw_circle(r.get_center(), 1.5 + bub, Color("#ffb060", 0.6))
                    if h % 9 == 0:      # искра поднимается и гаснет
                        var e := fmod(_anim_t * 9.0 + float(h), 14.0)
                        if e < 11.0:
                            draw_rect(Rect2(r.position.x + 4 + h % 8, r.position.y + 2 - e, 2, 2),
                                      Color("#ffcf7a", clampf(1.1 - e / 11.0, 0.0, 1.0)), true)
                "~":
                    # вода — те же бегущие блики, что в надмире
                    draw_rect(r, Color("#0e3260"), true)
                    var wv := int(float(h) + _anim_t * 5.0) % 8
                    draw_rect(Rect2(r.position.x + wv, r.position.y + 4, 7, 1), Color("#185088"), true)
                    draw_rect(Rect2(r.position.x + (wv + 4) % 8, r.position.y + 10, 6, 1), Color("#185088"), true)
                "C":
                    # кристалл: ромб с пульсирующим свечением (цвет от позиции)
                    draw_rect(r, c_floor, true)
                    var pulse := 0.5 + 0.5 * sin(_anim_t * 2.2 + float(h))
                    var ccol := Color("#8f6ee6") if h % 2 == 0 else Color("#5ac8e0")
                    draw_circle(r.get_center(), 7.0 + pulse * 2.0, Color(ccol, 0.10 + 0.08 * pulse))
                    var cx2 := r.get_center()
                    draw_colored_polygon(PackedVector2Array([
                        cx2 + Vector2(0, -7), cx2 + Vector2(5, 0),
                        cx2 + Vector2(0, 7), cx2 + Vector2(-5, 0)]), ccol.lightened(0.15 * pulse))
                    draw_line(cx2 + Vector2(0, -7), cx2 + Vector2(0, 7), ccol.lightened(0.45), 1.0)
                "M":
                    # светящийся гриб (проходимый): ножка + шляпка + мигающее свечение
                    draw_rect(r, c_floor, true)
                    var mg := 0.5 + 0.5 * sin(_anim_t * 3.0 + float(h) * 1.7)
                    draw_circle(r.get_center() + Vector2(0, 1), 6.0 + mg * 1.5, Color("#58e07a", 0.08 + 0.07 * mg))
                    draw_rect(Rect2(r.position.x + 7, r.position.y + 8, 2, 5), Color("#c8c0a8"), true)
                    draw_circle(r.get_center() + Vector2(0, -2), 4.0, Color("#3aa050"))
                    draw_circle(r.get_center() + Vector2(-1, -3), 1.2, Color("#a8ffc0", 0.6 + 0.4 * mg))
                "K":
                    # костяной завал: скрещённые кости + черепок
                    draw_rect(r, c_floor, true)
                    draw_line(r.position + Vector2(3, 12), r.position + Vector2(13, 5), Color("#c8c4b8"), 2.0)
                    draw_line(r.position + Vector2(3, 5), r.position + Vector2(13, 12), Color("#a8a498"), 2.0)
                    if h % 3 == 0:
                        draw_circle(r.position + Vector2(8, 4), 3.0, Color("#d8d4c8"))
                        draw_rect(Rect2(r.position.x + 6, r.position.y + 3, 1, 1), Color("#1a1616"), true)
                        draw_rect(Rect2(r.position.x + 9, r.position.y + 3, 1, 1), Color("#1a1616"), true)
                _:
                    draw_rect(r, c_floor2 if h % 7 == 0 else c_floor, true)
                    if h % 23 == 0:     # зола/косточки
                        draw_rect(Rect2(r.position.x + 4 + h % 6, r.position.y + 8, 3, 1),
                                  Color("#3a3444"), true)
                    elif h % 23 == 1:
                        draw_rect(Rect2(r.position.x + 6, r.position.y + 5 + h % 5, 2, 2),
                                  Color("#4a4456"), true)
    # двери
    var back_r := Rect2(off.x, off.y + midy * TILE, TILE, TILE)
    draw_rect(back_r, Color("#241c14"), true)
    draw_rect(Rect2(back_r.position.x + 4, back_r.position.y + 2, 8, 12), Color("#5a4428"), true)
    var exit_r := Rect2(off.x + (int(st.w) - 1) * TILE, off.y + midy * TILE, TILE, TILE)
    if _all_dead():
        var pulse := 0.5 + 0.5 * sin(_anim_t * 3.0)
        draw_rect(exit_r, Color("#153a1a"), true)
        draw_rect(Rect2(exit_r.position.x + 4, exit_r.position.y + 2, 8, 12),
                  Color("#3ad24a").lightened(0.3 * pulse), true)
    else:
        draw_rect(exit_r, Color("#2a1216"), true)
        for i in range(3):
            draw_rect(Rect2(exit_r.position.x + 3 + i * 4, exit_r.position.y + 2, 2, 12),
                      Color("#6a2a2a"), true)
    # факелы: кронштейн + пляшущее пламя + ореол
    for t in st.torches:
        var tp := off + Vector2(t.x * TILE + 8, t.y * TILE + (12 if t.y == 0 else 4))
        var fl := sin(_anim_t * 8.0 + float(t.x)) * 1.5
        draw_circle(tp, 7.0 + fl * 0.5, Color("#ff8a3a", 0.10))
        draw_rect(Rect2(tp.x - 1, tp.y, 2, 4), Color("#5a4428"), true)
        draw_circle(tp + Vector2(fl * 0.4, -3.0 - absf(fl)), 3.0, Color("#e05a1a"))
        draw_circle(tp + Vector2(fl * 0.3, -4.0 - absf(fl)), 1.6, Color("#ffd07a"))
    # сундуки (золотой — мерцает)
    for c in st.chests:
        var cr := Rect2(off.x + c.pos.x * TILE, off.y + c.pos.y * TILE, TILE, TILE)
        if c.opened:
            draw_rect(Rect2(cr.position.x + 3, cr.position.y + 6, 10, 7), Color("#2c2418"), true)
        elif c.get("gold", false):
            var gp := 0.5 + 0.5 * sin(_anim_t * 4.0 + float(c.pos.x))
            draw_circle(cr.get_center(), 9.0 + gp * 2.0, Color("#ffd24a", 0.10 + 0.08 * gp))
            Sprites.draw_grid(self, cr, "chest_gold")
        else:
            Sprites.draw_grid(self, cr, "chest")
    # рыбы: лавовые прыгают из лавы (и плюются), водяные — как в надмире
    for f in st.fish:
        var water: bool = f.get("water", false)
        var ph: float = fmod(_anim_t * float(f.spd) + float(f.off), 6.0 if water else 5.0)
        var base := off + Vector2(f.pos.x * TILE, f.pos.y * TILE)
        var skey := "fish" if water else "lava_fish"
        var splash := Color("#7ab0e0", 0.6) if water else Color("#ff8a3a", 0.5)
        if ph < 1.0:
            var dy := -sin(ph * PI) * (10.0 if water else 9.0)
            Sprites.draw_grid(self, Rect2(base.x, base.y + dy - 2.0, TILE, TILE), skey)
            if water and (ph < 0.25 or ph > 0.75):
                draw_circle(base + Vector2(TILE * 0.5, TILE * 0.8), 2.5, splash)
        elif ph < 1.4:
            draw_arc(base + Vector2(8, 9), (ph - 1.0) * 14.0, 0, TAU, 10, splash, 1.0)
        elif water and ph > 3.0 and ph < 3.4:
            draw_circle(base + Vector2(TILE * 0.5, TILE * 0.55), 2.0, Color("#d05a2a", 0.8))
    for pr in projectiles:
        draw_circle(pr.pos, 3.5, Color("#ff9a4a"))
        draw_circle(pr.pos, 1.6, Color("#ffe0a0"))
    # падающий пепел: в пепельных зонах и везде после ТМ (хлопья без состояния)
    if st.kind == "ash" or _cycle_of(depth) >= 1:
        var aw := float(int(st.w) * TILE)
        var ah := float(int(st.h) * TILE)
        for i in range(30):
            var seed_f := float(i) * 37.7 + float(depth) * 5.3
            var fy := fmod(seed_f * 13.7 + _anim_t * (7.0 + float(i % 5) * 2.5), ah)
            var fx := fmod(seed_f * 7.9, aw) + sin(_anim_t * 1.4 + seed_f) * 5.0
            draw_rect(Rect2(off.x + fx, off.y + fy, 2, 2),
                      Color("#b8a8a0", 0.16 + 0.10 * float(i % 3)), true)
    # мобы и герой
    for m in st.mobs:
        if m.alive:
            var mr := Rect2(off.x + m.pos.x * TILE, off.y + m.pos.y * TILE, TILE, TILE)
            if m.get("boss", false):
                mr = mr.grow(6)      # боссы крупнее
            Sprites.draw_mob(self, mr, m.enemy[0])
    Sprites.draw_grid(self, Rect2(off.x + ppos.x * TILE, off.y + ppos.y * TILE, TILE, TILE), "player")
