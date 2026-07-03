extends Control
## 🔥 АДСКАЯ ШАХТА — бесконечное подземелье про Пекло и «ТМ».
##
## Правила: перебей всех в комнате → правая дверь откроется. Назад — свободно.
## Выход из шахты сбрасывает этажи, но добытый лут остаётся при тебе.
## Каждые 5 этажей — мини-босс, каждые 10 — босс, каждые 25 — сам «ТМ».
## Комнаты: обычные / завалы / лавовые реки (жгут рядом) / лавовые озёра
## с рыбами, плюющимися медленными шарами.

signal closed()

const TILE := 16
const MOVE_REPEAT := 0.11

# тёмная палитра шахты (лава — единственный тёплый акцент)
const COL_WALL := Color("#1b1622")
const COL_WALL2 := Color("#262030")
const COL_FLOOR := Color("#141019")
const COL_FLOOR2 := Color("#1c1622")
const COL_ROCK := Color("#3a3542")
const COL_ROCK_HI := Color("#4c4658")

# ─── лор: кринж про Пекло и «ТМ» ───
const LORE_INTRO := [
    "Шахтёры копали бурмолду слишком глубоко — и докопались до ПЕКЛА.",
    "Внизу живёт «ТМ». Расшифровки не знает никто. Спросить боятся все.",
]
const LORE_FLOORS := {
    2: "На стене выцарапано: «ТМ видит тебя. тм.»",
    4: "Чей-то дневник: «день 40. кирка сгорела. зато свэг цел.»",
    6: "Кости шахтёра сложены в слово «БЕГИ». Педантично.",
    9: "Табличка: «Этаж 10. Дальше — administración Пекла.»",
    13: "«ТМ — это Тёмный Мастер? Тотальный Мрак? Твоя Мамка?» — надписи спорят.",
    17: "Стало тихо. Даже лава течёт шёпотом.",
    19: "Плакат: «Магистр Пекла принимает по записи. Запись сгорела.»",
    23: "Пол дрожит. Что-то внизу ставит басы.",
    24: "За следующими дверями — ОНО. «тм.»",
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
    return clampi(3 + int(depth / 3.0), 3, 10)


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
    # тип комнаты: боссы по расписанию, иначе — разнообразие
    if force_kind != "":
        s.kind = force_kind
    elif d % 25 == 0:
        s.kind = "tm"
    elif d % 10 == 0:
        s.kind = "boss"
    elif d % 5 == 0:
        s.kind = "mini"
    else:
        s.kind = ["plain", "rocky", "lava_river", "lava_lake"][randi() % 4]

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
        "plain":
            for _i in range(randi_range(3, 7)):
                _scatter(s, "R", midy)
        "lava_river":
            # вертикальная река лавы с мостом на уровне дверей
            var rx := randi_range(int(w * 0.35), int(w * 0.6))
            for y in range(1, h - 1):
                if absi(y - midy) > 1:
                    _put(s, Vector2i(rx, y), "L")
                    if randf() < 0.5 and rx + 1 < w - 1:
                        _put(s, Vector2i(rx + 1, y), "L")
        "lava_lake":
            # озеро строго в верхней или нижней половине (ряд дверей не трогаем)
            var cy: int
            if randf() < 0.5 or midy + 3 > h - 4:
                cy = randi_range(2, maxi(2, midy - 3))
            else:
                cy = randi_range(midy + 3, h - 4)
            var cx := randi_range(5, w - 6)
            for y in range(1, h - 1):
                for x in range(1, w - 1):
                    if Vector2(x - cx, (y - cy) * 1.4).length() < 2.9:
                        _put(s, Vector2i(x, y), "L")
            for _i in range(2):
                s.fish.append({"pos": Vector2i(clampi(cx + randi_range(-1, 1), 1, w - 2),
                                               clampi(cy + randi_range(-1, 1), 1, h - 2)),
                               "off": randf() * 6.0, "spd": randf_range(0.7, 1.1)})

    # мобы: у боссов — один; у обычных комнат 2-4 из пула Пекла
    if s.kind in ["boss", "mini", "tm"]:
        s.mobs.append({"pos": Vector2i(int(w / 2.0), midy), "enemy": _boss_enemy(d, s.kind),
                       "alive": true, "boss": true})
        s.chests.append({"pos": Vector2i(w - 3, midy - 2), "opened": false})
    else:
        for _m in range(randi_range(2, mini(4, 2 + int(d / 4.0)))):
            var t := _free_tile(s, midy)
            if t.x > 0:
                s.mobs.append({"pos": t, "enemy": _mob_enemy(d), "alive": true, "boss": false})
        if randf() < 0.4:
            var ct := _free_tile(s, -1)
            if ct.x > 0:
                s.chests.append({"pos": ct, "opened": false})
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
    var pool := [
        ["Зольный Жук", 16 + d * 3, 4 + int(d / 2.0)],
        ["Уголёк-Живчик", 12 + d * 3, 5 + int(d / 2.0)],
        ["Магмовый Краб", 22 + d * 3, 4 + int(d / 2.0)],
        ["Тень Шахтёра", 18 + d * 3, 5 + int(d / 2.0)],
    ]
    return pool[randi() % pool.size()]


func _boss_enemy(d: int, kind: String) -> Array:
    match kind:
        "tm":
            return ["ТМ", 260 + d * 10, 14 + int(d / 2.0)]
        "boss":
            return ["Магистр Пекла", 120 + d * 8, 10 + int(d / 2.0)]
    return ["Надзиратель Пекла", 65 + d * 6, 8 + int(d / 2.0)]


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
    if ch != ".":
        return
    ppos = t
    # сундук — открывается наступанием
    for c in st.chests:
        if not c.opened and c.pos == ppos:
            _open_chest(c)
    # лава жжёт, если прошёл ВПЛОТНУЮ
    for d4 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        if _cell(ppos + d4) == "L":
            var dmg := 2 + int(depth / 4.0)
            GameState.player.damage(dmg)
            Sfx.play("hurt")
            _flash("🔥 Жар лавы: -%d HP!" % dmg)
            if not GameState.player.is_alive():
                GameState.player.hp = 1
                closed.emit()
                return
            break
    _update_info()
    queue_redraw()


# ─────────────── лавовые рыбы: анимация + плевки ───────────────
func _fish_step(delta: float) -> void:
    for f in st.fish:
        if randf() < delta * 0.30:     # небольшой шанс плюнуть
            var dir := Vector2.from_angle(randf() * TAU)
            projectiles.append({"pos": Vector2(f.pos * TILE) + _off() + Vector2(8, 8),
                                "vel": dir * 34.0})
    var alive: Array = []
    var prect := Rect2(Vector2(ppos * TILE) + _off() + Vector2(3, 3), Vector2(10, 10))
    for pr in projectiles:
        pr.pos += pr.vel * delta
        var tile := Vector2i((pr.pos - _off()) / TILE)
        var ch := _cell(tile)
        if ch == "#" or ch == "R":
            continue                    # разбился о стену
        if prect.has_point(pr.pos):
            var dmg := 2 + int(depth / 5.0)
            GameState.player.damage(dmg)
            Sfx.play("hurt")
            _flash("💥 Лавовый плевок: -%d HP!" % dmg)
            if not GameState.player.is_alive():
                GameState.player.hp = 1
                closed.emit()
                return
            continue
        alive.append(pr)
    projectiles = alive


# ─────────────── бой / лут ───────────────
func _fight(m: Dictionary) -> void:
    busy = true
    var b = load("res://scenes/Battle.tscn").instantiate()
    b.enemy = m.enemy
    b.danger = _danger()
    b.battle_over.connect(_after_fight.bind(b, m))
    overlay.add_child(b)


func _after_fight(result: String, node: Node, m: Dictionary) -> void:
    node.queue_free()
    busy = false
    if result == "lose":
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
    var lines := Loot.grant(p, _danger() + 1, false)
    if randf() < 0.5:
        p.add_item("пепел ТМ")
        lines.append("🎒 добыто: пепел ТМ")
    if randf() < 0.3:
        p.add_item("зольный слиток")
        lines.append("🎒 добыто: зольный слиток")
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


func _update_info() -> void:
    var p := GameState.player
    var left := 0
    for m in st.mobs:
        if m.alive:
            left += 1
    info.text = "🔥 АДСКАЯ ШАХТА · этаж %d · врагов: %d · ♥ %d/%d · ⛃ %d\n← дверь назад · → дверь дальше (после зачистки) · ESC — выйти (сброс этажей)" % [
        depth, left, p.hp, p.max_hp, p.burmolda]


# ─────────────── отрисовка ───────────────
func _off() -> Vector2:
    return Vector2((640 - int(st.w) * TILE) * 0.5, 52 + (380 - int(st.h) * TILE) * 0.5)


func _draw() -> void:
    draw_rect(Rect2(0, 0, 640, 480), Color("#0b0810"), true)
    if st.is_empty():
        return
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
                    draw_rect(r, COL_WALL, true)
                    if h % 3 == 0:
                        draw_rect(Rect2(r.position.x, r.position.y + 7, TILE, 1), COL_WALL2, true)
                    if h % 4 == 1:
                        draw_rect(Rect2(r.position.x + 7, r.position.y, 1, 8), COL_WALL2, true)
                "R":
                    draw_rect(r, COL_FLOOR, true)
                    draw_circle(r.get_center() + Vector2(0, 2), 6.0, COL_ROCK)
                    draw_circle(r.get_center() + Vector2(-2, 0), 4.5, COL_ROCK_HI)
                "L":
                    # лава: тёмное ядро + бегущие светлые прожилки
                    draw_rect(r, Color("#8a2c10"), true)
                    var wo := int(float(h) + _anim_t * 4.0) % 8
                    draw_rect(Rect2(r.position.x + wo, r.position.y + 4, 6, 2), Color("#e05a1a"), true)
                    draw_rect(Rect2(r.position.x + (wo + 4) % 8, r.position.y + 10, 5, 2), Color("#ff8a3a"), true)
                    if h % 6 == 0:
                        var bub := 0.5 + 0.5 * sin(_anim_t * 3.0 + float(h))
                        draw_circle(r.get_center(), 1.5 + bub, Color("#ffb060", 0.6))
                _:
                    draw_rect(r, COL_FLOOR2 if h % 7 == 0 else COL_FLOOR, true)
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
    # сундуки
    for c in st.chests:
        var cr := Rect2(off.x + c.pos.x * TILE, off.y + c.pos.y * TILE, TILE, TILE)
        if c.opened:
            draw_rect(Rect2(cr.position.x + 3, cr.position.y + 6, 10, 7), Color("#2c2418"), true)
        else:
            Sprites.draw_grid(self, cr, "chest")
    # лавовые рыбы (прыгают из лавы) + их плевки
    for f in st.fish:
        var ph: float = fmod(_anim_t * float(f.spd) + float(f.off), 5.0)
        var base := off + Vector2(f.pos.x * TILE, f.pos.y * TILE)
        if ph < 1.0:
            var dy := -sin(ph * PI) * 9.0
            Sprites.draw_grid(self, Rect2(base.x, base.y + dy - 2.0, TILE, TILE), "lava_fish")
        elif ph < 1.4:
            draw_arc(base + Vector2(8, 9), (ph - 1.0) * 14.0, 0, TAU, 10, Color("#ff8a3a", 0.5), 1.0)
    for pr in projectiles:
        draw_circle(pr.pos, 3.5, Color("#ff9a4a"))
        draw_circle(pr.pos, 1.6, Color("#ffe0a0"))
    # мобы и герой
    for m in st.mobs:
        if m.alive:
            var mr := Rect2(off.x + m.pos.x * TILE, off.y + m.pos.y * TILE, TILE, TILE)
            if m.get("boss", false):
                mr = mr.grow(6)      # боссы крупнее
            Sprites.draw_mob(self, mr, m.enemy[0])
    Sprites.draw_grid(self, Rect2(off.x + ppos.x * TILE, off.y + ppos.y * TILE, TILE, TILE), "player")
