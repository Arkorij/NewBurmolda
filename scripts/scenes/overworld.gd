extends Node2D
## Надмир: тайловая карта из data/locations, посеточная ходьба, камера,
## разговор с NPC (бампом), переходы по порталам, случайные встречи → бой.

const TILE := 16
const BLOCKED := "#TR"
const WALK := ". ,\"is"          # земля, трава, лёд, снег (вода '~' — нельзя)
const NODES := "mfhjce"

var loc: Dictionary
var loc_id := ""
var grid: Array
var ppos := Vector2i.ZERO
var busy := false
var font: Font
var cam: Camera2D
var hud: HudPanel                # верхняя панель: HP/кринж-полосы, бурмолда, свэг
var minimap: Minimap             # миникарта локации (правый нижний угол)
const CAM_ZOOM := 1.7            # приближение камеры (тайлы видимые ~27px)
var overlay: CanvasLayer
var mobs: Array = []             # видимые ходячие мобы: [{pos: Vector2i, enemy: [...]}]
var wanderers: Array = []        # блуждающие NPC: [{pos: Vector2i, kind: String}]
var _reach: Dictionary = {}      # достижимые от игрока клетки (BFS) — спавн только сюда
var fish: Array = []             # анимированные рыбы в воде: [{pos, off, spd}]
# у кого из «базовых» может отираться Зомби (спавн 5%)
const ZOMBIE_SPOTS := ["base", "forest", "meadow", "mire", "pond"]
var _anim_t := 0.0               # общее время для анимаций (вода/рыбы/порталы)
var _loc_seed := 0               # сид декораций локации
var _move_cd := 0.0
var _mob_cd := 0.0
var _slide_dir := Vector2i.ZERO  # скольжение по льду
var _slide_left := 0
const MOVE_REPEAT := 0.11        # шаг при зажатой клавише
const SLOW_MULT := 1.8           # замедление на траве/снегу
const SLIDE_CD := 0.05           # скорость проскальзывания по льду
const MOB_STEP := 0.5            # как часто мобы делают шаг


func _ready() -> void:
    font = ThemeDB.fallback_font
    cam = Camera2D.new()
    cam.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)   # ближе к земле: локация скроллится
    add_child(cam)
    cam.make_current()
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = HudPanel.new()
    layer.add_child(hud)
    minimap = Minimap.new()
    minimap.ow = self
    layer.add_child(minimap)
    overlay = CanvasLayer.new()
    overlay.layer = 10
    add_child(overlay)
    var lid = GameState.player.current_loc
    if lid == null or not DataDB.locations.has(lid):
        lid = DataDB.loc_index.get("start", "base")
    load_location(lid)
    get_viewport().size_changed.connect(_on_viewport_resized)
    set_process_unhandled_input(true)


func _on_viewport_resized() -> void:
    ## Окно растянули — пересчитать лимиты камеры под новую видимую область.
    if not grid.is_empty():
        _update_camera()
        queue_redraw()


func load_location(id: String, from_id := "") -> void:
    loc = DataDB.locations[id]
    loc_id = id
    GameState.player.current_loc = id
    grid = loc["map"]
    _loc_seed = hash(id)
    _slide_left = 0
    ppos = _spawn_pos(from_id)
    mobs = []
    _spawn_wanderers()       # первыми — чтобы мобы учли их как препятствия
    _spawn_mobs()
    _spawn_fish()
    _update_camera()
    _update_hud()
    queue_redraw()


func _spawn_wanderers() -> void:
    ## Блуждающие NPC. Тепличная: гарантированно встречает новичка на базе,
    ## дальше — 2% шанс в ЛЮБОЙ надмирной локации (в подземелье не ходит).
    ## Зомби: 5% шанс, только в локациях базовых персонажей.
    ## Спавн только в достижимую от игрока зону — Тепличную/Зомби всегда можно дойти.
    wanderers = []
    _reach = _reachable({})
    var first_meet: bool = loc_id == "base" \
            and not GameState.player.flags.get("met_teplichnaya", false)
    if first_meet or randf() < 0.02:
        var t := _wanderer_tile()
        if t.x >= 0:
            wanderers.append({"pos": t, "kind": "teplichnaya"})
    if loc_id in ZOMBIE_SPOTS and randf() < 0.05:
        var t2 := _wanderer_tile()
        if t2.x >= 0:
            wanderers.append({"pos": t2, "kind": "zombie"})


func _wanderer_tile() -> Vector2i:
    ## Клетка для статичного NPC: минимум 3 свободных соседа И проверка BFS,
    ## что NPC не отрежет от игрока ни один портал/NPC/ноду/босса (клетка с
    ## 3 соседями всё равно может быть точкой сочленения в узком месте —
    ## аудит ловил такой софтлок на burmine).
    for _t in range(40):
        var t := _random_empty_tile()
        if t.x < 0:
            continue
        var free := 0
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            if _walkable(_char_at(t.x + d.x, t.y + d.y)):
                free += 1
        if free >= 3 and not _cuts_key_tiles(t):
            return t
    return Vector2i(-1, -1)


func _cuts_key_tiles(t: Vector2i) -> bool:
    ## true, если вставший на t NPC отрезает игрока от чего-то важного.
    var block := _wanderer_block()      # уже стоящие блуждающие — тоже стены
    block[t] = true
    var reach := _reachable(block)
    for y in grid.size():
        var row: String = grid[y]
        for x in row.length():
            var ch := row[x]
            var key: bool = loc.get("exits", {}).has(ch) \
                    or loc.get("npcs", {}).has(ch) \
                    or (loc.get("boss") != null and (ch == "K" or ch == "Z")) \
                    or ch in NODES
            if not key:
                continue
            var p := Vector2i(x, y)
            var ok := reach.has(p)
            for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                if reach.has(p + d):
                    ok = true
            if not ok:
                return true
    return false


func _spawn_pos(from_id: String) -> Vector2i:
    ## Появиться у портала, который ведёт ОБРАТНО в локацию, откуда пришли.
    if from_id != "":
        var exits: Dictionary = loc.get("exits", {})
        for y in grid.size():
            var row: String = grid[y]
            for x in row.length():
                if exits.has(row[x]) and str(exits[row[x]]) == from_id:
                    var t := _adjacent_walkable(Vector2i(x, y))
                    if t.x >= 0:
                        return t
    var entry = loc.get("entry", [1, 1])
    var p := Vector2i(int(entry[0]), int(entry[1]))
    if not _walkable(_char_at(p.x, p.y)):
        p = _first_walkable()
    return p


func _adjacent_walkable(t: Vector2i) -> Vector2i:
    ## Свободная клетка рядом с порталом (предпочитаем сторону к центру карты).
    var center := Vector2(grid[0].length() * 0.5, grid.size() * 0.5)
    var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    dirs.sort_custom(func(a, b):
        return Vector2(t + a).distance_to(center) < Vector2(t + b).distance_to(center))
    for d in dirs:
        var n: Vector2i = t + d
        if _walkable(_char_at(n.x, n.y)):
            return n
    return Vector2i(-1, -1)


func _char_at(x: int, y: int) -> String:
    if y < 0 or y >= grid.size():
        return "#"
    var row: String = grid[y]
    if x < 0 or x >= row.length():
        return "#"
    return row[x]


func _walkable(ch: String) -> bool:
    return ch in WALK or ch in NODES


func _first_walkable() -> Vector2i:
    for y in grid.size():
        var row: String = grid[y]
        for x in row.length():
            if _walkable(row[x]):
                return Vector2i(x, y)
    return Vector2i(1, 1)


# ─────────────── ввод / движение ───────────────
func _unhandled_input(event: InputEvent) -> void:
    if busy:
        return
    if event.is_action_pressed("ui_accept"):
        _open_menu()
    elif event.is_action_pressed("ui_cancel"):
        GameState.save_game()
        _flash("💾 сохранено")
    elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
        # секретная клавиша: читы работают всегда, но HUD о них не рассказывает
        OverworldDebug.open_cheats(self)
    elif event is InputEventKey and event.pressed and event.keycode == KEY_F2:
        # секретная клавиша: дебаг-меню вызова любого боя
        OverworldDebug.open_debug_battles(self)


func _process(delta: float) -> void:
    if busy:
        return
    _anim_t += delta                # анимации: вода, рыбы, пульс порталов
    _move_cd -= delta
    if _slide_left > 0:             # скольжение по льду — само тащит
        if _move_cd <= 0.0:
            _slide_step()
    elif _move_cd <= 0.0:
        # ходьба зажатием клавиш (посеточно, без диагоналей)
        var dx := int(Input.get_axis("ui_left", "ui_right"))
        var dy := int(Input.get_axis("ui_up", "ui_down"))
        if dx != 0:
            dy = 0
        if dx != 0 or dy != 0:
            _try_move(dx, dy)
    if busy:                       # шаг мог открыть бой/NPC
        return
    # мобы бродят
    _mob_cd -= delta
    if _mob_cd <= 0.0:
        _mob_cd = MOB_STEP
        _step_mobs()
    queue_redraw()                  # непрерывная перерисовка ради анимаций


func _try_move(dx: int, dy: int) -> void:
    var nx := ppos.x + dx
    var ny := ppos.y + dy
    var ch := _char_at(nx, ny)
    if loc.get("npcs", {}).has(ch):
        _open_npc(loc["npcs"][ch])
        return
    if loc.get("boss") != null and (ch == "K" or ch == "Z"):
        _open_boss(loc["boss"])
        return
    if loc.get("exits", {}).has(ch):
        _travel(loc["exits"][ch])
        return
    for w in wanderers:
        if w.pos == Vector2i(nx, ny):     # бамп в блуждающего NPC = диалог
            _open_npc(w.kind)
            return
    for m in mobs:
        if m.pos == Vector2i(nx, ny):     # войти в моба = начать бой
            _start_map_battle(m)
            return
    if not _walkable(ch):
        _move_cd = 0.06                   # упёрся — не долбить каждый кадр
        return
    ppos = Vector2i(nx, ny)
    # скорость зависит от поверхности: трава/снег медленнее, лёд скользит
    if ch == "," or ch == "\"" or ch == "s":
        _move_cd = MOVE_REPEAT * SLOW_MULT
    elif ch == "i":
        _slide_dir = Vector2i(dx, dy)
        _slide_left = 2                   # небольшое скольжение (до 2 клеток)
        _move_cd = SLIDE_CD
    else:
        _move_cd = MOVE_REPEAT
    _update_camera()
    _update_hud()
    queue_redraw()
    _on_step(ch)


func _slide_step() -> void:
    ## Проскользнуть на 1 клетку по льду, пока лёд и путь свободен.
    var nt := ppos + _slide_dir
    var ch := _char_at(nt.x, nt.y)
    var blocked_entity: bool = loc.get("npcs", {}).has(ch) or loc.get("exits", {}).has(ch) \
            or (loc.get("boss") != null and (ch == "K" or ch == "Z"))
    for m in mobs:
        if m.pos == nt:
            blocked_entity = true
            break
    if ch != "i" or not _walkable(ch) or blocked_entity:
        _slide_left = 0
        _move_cd = MOVE_REPEAT * 0.5      # чуть «очнуться» после льда
        return
    ppos = nt
    _slide_left -= 1
    _move_cd = SLIDE_CD if _slide_left > 0 else MOVE_REPEAT * 0.5
    _update_camera()
    _update_hud()
    queue_redraw()


func _on_step(ch: String) -> void:
    if ch in NODES:
        _open_node(ch)
        return
    # редкое случайное событие — 0.1% за шаг (основной бой — через видимых мобов)
    var monsters: Array = loc.get("monsters", [])
    if int(loc.get("danger", 0)) > 0 and not monsters.is_empty() and randf() < 0.001:
        var m = monsters[randi() % monsters.size()]
        _open_battle([m[0], int(m[1]), int(m[2])], null)


func _travel(target: String) -> void:
    if not DataDB.locations.has(target):
        return
    # гейт по уровню: в сложные локации пускаем только прокачанных
    var tl: Dictionary = DataDB.locations[target]
    var need := int(tl.get("min_level", 1))
    if GameState.player.level < need:
        _flash("🚫 «%s»: нужен уровень %d (у тебя %d). Качайся, головастик!" % [
            tl.get("name", target), need, GameState.player.level])
        return
    load_location(target, loc_id)


# ─────────────── рыбы в воде ───────────────
func _spawn_fish() -> void:
    fish = []
    var waters: Array = []
    for y in grid.size():
        var row: String = grid[y]
        for x in row.length():
            if row[x] == "~":
                waters.append(Vector2i(x, y))
    if waters.is_empty():
        return
    var want := 0
    if loc.get("fish", false):
        want = 4
    elif waters.size() >= 12:
        want = 3
    elif waters.size() >= 4:
        want = 1
    for _i in range(mini(want, waters.size())):
        fish.append({"pos": waters[randi() % waters.size()],
                     "off": randf() * 6.0, "spd": randf_range(0.7, 1.2)})


# ─────────────── видимые мобы ───────────────
func _spawn_mobs() -> void:
    mobs = []
    _reach = _reachable(_wanderer_block())   # достижимо С УЧЁТОМ бродяг-препятствий
    var monsters: Array = loc.get("monsters", [])
    var danger := int(loc.get("danger", 0))
    if danger <= 0 or monsters.is_empty():
        return
    for _i in range(clampi(danger + 1, 2, 7)):
        var t := _random_empty_tile()
        if t.x < 0:
            continue
        var mm = monsters[randi() % monsters.size()]
        mobs.append({"pos": t, "enemy": [mm[0], int(mm[1]), int(mm[2])]})


func _random_empty_tile() -> Vector2i:
    for _t in range(60):
        var t := Vector2i(randi_range(1, int(grid[0].length()) - 2), randi_range(1, grid.size() - 2))
        if t != ppos and _mob_can_stand(t):
            return t
    return Vector2i(-1, -1)


func _mob_can_stand(t: Vector2i) -> bool:
    var ch := _char_at(t.x, t.y)
    if not (ch in WALK):              # мобы — только по земле/траве (не ноды/порталы)
        return false
    if not _reach.is_empty() and not _reach.has(t):
        return false                  # только клетки, достижимые от игрока
    if loc.get("npcs", {}).has(ch) or loc.get("exits", {}).has(ch):
        return false
    for w in wanderers:               # не топтаться по Тепличной/Зомби
        if w.pos == t:
            return false
    for m in mobs:
        if m.pos == t:
            return false
    return true


func _reachable(blocked: Dictionary) -> Dictionary:
    ## BFS достижимых от игрока (ppos) проходимых клеток, минуя blocked.
    var vis: Dictionary = {ppos: true}
    var q: Array = [ppos]
    while not q.is_empty():
        var p: Vector2i = q.pop_front()
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var n: Vector2i = p + d
            if vis.has(n) or blocked.has(n):
                continue
            if _walkable(_char_at(n.x, n.y)):
                vis[n] = true
                q.append(n)
    return vis


func _wanderer_block() -> Dictionary:
    var b: Dictionary = {}
    for w in wanderers:
        b[w.pos] = true
    return b


func _step_mobs() -> void:
    if mobs.is_empty():
        return
    var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
                 Vector2i.ZERO, Vector2i.ZERO]
    for m in mobs:
        var d: Vector2i = dirs[randi() % dirs.size()]
        if d == Vector2i.ZERO:
            continue
        var nt: Vector2i = m.pos + d
        if nt == ppos:                # моб врезался в игрока — тоже бой
            _start_map_battle(m)
            return
        if _mob_can_stand(nt):
            m.pos = nt
    queue_redraw()


func _start_map_battle(m: Dictionary) -> void:
    busy = true
    var b = load("res://scenes/Battle.tscn").instantiate()
    b.enemy = m.enemy
    b.danger = int(loc.get("danger", 1))
    b.biome = str(loc.get("biome", ""))
    b.battle_over.connect(_after_map_battle.bind(b, m))
    overlay.add_child(b)


func _after_map_battle(result: String, node: Node, m: Dictionary) -> void:
    node.queue_free()
    busy = false
    if result == "win":
        mobs.erase(m)             # побеждённый моб исчезает с карты
    _update_hud()
    queue_redraw()


# ─────────────── оверлеи (бой / NPC) ───────────────
func _open_battle(enemy_arr, bkey) -> void:
    busy = true
    var b = load("res://scenes/Battle.tscn").instantiate()
    b.enemy = enemy_arr
    b.boss_key = bkey
    b.danger = int(loc.get("danger", 1))
    b.biome = str(loc.get("biome", ""))
    b.battle_over.connect(_close_battle.bind(b))
    overlay.add_child(b)


func _close_battle(_result: String, node: Node) -> void:
    node.queue_free()
    busy = false
    _update_hud()
    queue_redraw()


const BOSS_POSTER := {
    "kalitin": {"color": Color("#c0293a"), "sub": "★ КОСТЯНОЙ БАРАБАНЩИК ★",
                "flavor": "Гремит костями в такт. Боится замены ОЗУ в макбуках."},
    "tsizi": {"color": Color("#35b6d6"), "sub": "★ ДУХ СКВОЗНЯКА ★",
              "flavor": "Дует и лжёт. Лжёт и дует. Иногда одновременно."},
    "zhizha": {"color": Color("#4ac04a"), "sub": "★ ВЕЛИКАЯ ЖИЖА ★",
               "flavor": "Финальная форма болота. Не имеет формы."},
}


func _open_boss(bkey: String) -> void:
    busy = true
    var cfg: Dictionary = BOSS_POSTER.get(bkey, {})
    var poster = load("res://scenes/Poster.tscn").instantiate()
    poster.title_text = DataDB.bosses.get(bkey, [bkey.to_upper()])[0]
    poster.subtitle_text = cfg.get("sub", "★ БОСС БОЛОТА ★")
    poster.color = cfg.get("color", Color("#c0293a"))
    poster.sprite_key = bkey
    poster.flavor = cfg.get("flavor", "")
    poster.done.connect(_after_boss_poster.bind(poster, bkey))
    overlay.add_child(poster)


func _after_boss_poster(node: Node, bkey: String) -> void:
    node.queue_free()
    var b = load("res://scenes/Battle.tscn").instantiate()
    b.boss_key = bkey
    b.danger = int(loc.get("danger", 1))
    b.biome = str(loc.get("biome", ""))
    b.battle_over.connect(_close_battle.bind(b))
    overlay.add_child(b)


func _open_npc(kind: String) -> void:
    busy = true
    if kind == "smith":
        _open_scene("res://scenes/Blacksmith.tscn")
        return
    if kind == "dungeon":
        _open_scene("res://scenes/Dungeon.tscn")
        return
    if not DataDB.npcs.has(kind):
        busy = false
        _flash("«%s» — этот экран будет позже." % kind)
        return
    var n = load("res://scenes/NPC.tscn").instantiate()
    n.kind = kind
    n.closed.connect(_close_npc.bind(n))
    overlay.add_child(n)


# ─────────────── меню паузы ───────────────
func _open_menu() -> void:
    busy = true
    var panel := Control.new()
    ScreenFit.attach(panel, Color(0, 0, 0, 0.66))   # затемнение на всё окно
    var title := Label.new()
    title.text = "☰ МЕНЮ"
    title.position = Vector2(252, 120)
    title.add_theme_font_size_override("font_size", 22)
    panel.add_child(title)
    var m := SoulMenu.new()
    m.position = Vector2(252, 168)
    panel.add_child(m)
    m.setup(["⚔ Экипировка", "📊 Профиль", "📜 Квесты", "📖 Журнал", "💾 Сохранить", "✖ Закрыть"])
    m.chosen.connect(_on_menu.bind(panel))
    m.cancelled.connect(_close_overlay.bind(panel))
    overlay.add_child(panel)


func _on_menu(i: int, panel: Node) -> void:
    panel.queue_free()
    match i:
        0: _open_scene("res://scenes/Inventory.tscn")
        1: _profile_flash()
        2: _open_scene("res://scenes/QuestLog.tscn")
        3: _open_scene("res://scenes/Journal.tscn")
        4:
            GameState.save_game()
            _flash_close("💾 сохранено")
        5: _flash_close("")


func _open_scene(path: String) -> void:
    var s = load(path).instantiate()
    s.closed.connect(_close_overlay.bind(s))
    overlay.add_child(s)


func _flash_close(msg: String) -> void:
    busy = false
    if msg != "":
        _flash(msg)
    else:
        _update_hud()


func _profile_flash() -> void:
    var p := GameState.player
    _flash_close("%s · %s · ур.%d · свэг %d · кринж %d · реп %d" % [
        p.pname, p.rank(), p.level, p.swag, p.cringe, p.reputation])


# ─────────────── чит-меню (F1) и дебаг-бой (F2) ───────────────
# Вынесены в scripts/scenes/overworld_debug.gd (OverworldDebug) — F1/F2 это
# самодостаточный отладочный инструмент, не часть основного цикла надмира.


func _close_npc(node: Node) -> void:
    node.queue_free()
    busy = false
    _update_hud()
    queue_redraw()


func _open_node(ch: String) -> void:
    busy = true
    var ntype: String = DataDB.node_char_type.get(ch, "mine")
    var path := "res://scenes/Echo.tscn" if ntype == "echo" else "res://scenes/Gather.tscn"
    var n = load(path).instantiate()
    if ntype != "echo":
        n.node_type = ntype
    n.done.connect(_close_overlay.bind(n))
    overlay.add_child(n)


func _close_overlay(node: Node) -> void:
    node.queue_free()
    busy = false
    _update_hud()
    # шахта выкинула героя при смерти — объяснить, что произошло
    if GameState.player.flags.get("_hell_spit", false):
        GameState.player.flags.erase("_hell_spit")
        _flash("🔥 Пекло пожевало тебя и выплюнуло наружу. «тм». (1 HP — подлечись!)")
    queue_redraw()


# ─────────────── камера / HUD ───────────────
func _update_camera() -> void:
    cam.position = Vector2(ppos.x * TILE + TILE * 0.5, ppos.y * TILE + TILE * 0.5)
    # карта меньше видимой области (зум/широкое окно) — центрируем, а не липнем к углу;
    # размер видимой области берём из окна (stretch=expand, любое соотношение сторон)
    var vs := get_viewport_rect().size
    var vw := vs.x / CAM_ZOOM
    var vh := vs.y / CAM_ZOOM
    var mw := float(int(grid[0].length()) * TILE)
    var mh := float(grid.size() * TILE)
    if mw < vw:
        cam.limit_left = int(mw * 0.5 - vw * 0.5)
        cam.limit_right = int(mw * 0.5 + vw * 0.5)
    else:
        cam.limit_left = 0
        cam.limit_right = int(mw)
    if mh < vh:
        cam.limit_top = int(mh * 0.5 - vh * 0.5)
        cam.limit_bottom = int(mh * 0.5 + vh * 0.5)
    else:
        cam.limit_top = 0
        cam.limit_bottom = int(mh)


func _flash(msg: String) -> void:
    hud.refresh(loc.get("name", "?"), msg)


func _update_hud() -> void:
    hud.refresh(loc.get("name", "?"))


# ─────────────── отрисовка ───────────────
const NODE_COLORS := {"m": Color("#8a8a9a"), "f": Color("#4488cc"),
    "h": Color("#55aa44"), "j": Color("#aa7733"), "c": Color("#aa44cc"), "e": Color("#44aacc")}

# цвета по биомам: [земля, крапинка, стена, шов стены, акцент-декор]
const BIOME_COL := {
    "swamp":      ["#231e17", "#2d261e", "#15151f", "#1c1c28", "#7fae4a"],
    "forest":     ["#1d2415", "#272e1c", "#0f1a0c", "#162412", "#c96f3a"],
    "grass":      ["#28361b", "#324223", "#17220f", "#1e2c15", "#e0c04a"],
    "water":      ["#1e2c2a", "#263634", "#101c1e", "#162628", "#5ac8c8"],
    "ice":        ["#8fa3b0", "#9db1be", "#3c4854", "#4c5a66", "#e8f4fc"],
    "opera_ice":  ["#66788e", "#728498", "#2c3648", "#364256", "#a8d0f0"],
    "wastes":     ["#2f2717", "#39301e", "#1c160d", "#241d12", "#8a7a50"],
    "waste2":     ["#332517", "#3d2e1e", "#1e150d", "#281c12", "#a08048"],
    "bone":       ["#282430", "#322e3a", "#171420", "#201c2a", "#d8d8e0"],
    "hell":       ["#301610", "#3a1e16", "#1c0c08", "#26120c", "#e05a24"],
    "volcano":    ["#33140c", "#3f1c12", "#200a06", "#2c100a", "#ff7a30"],
    "cave":       ["#1f1c26", "#282430", "#100e16", "#181420", "#7a6ad0"],
    "acidfield":  ["#25300f", "#2f3c15", "#141c08", "#1c260c", "#a8e030"],
    "jungle":     ["#182a10", "#213618", "#0c1a08", "#12240e", "#e05aa0"],
    "deadlands":  ["#271c23", "#31242d", "#170f14", "#20161c", "#a04a70"],
    "abyss":      ["#131022", "#1b172e", "#0a0816", "#120e20", "#6a4ae0"],
    "crossroads": ["#292214", "#332c1c", "#17130c", "#1f1a10", "#d0a040"],
}


func _bcol(i: int, fallback: String) -> Color:
    var arr: Array = BIOME_COL.get(loc.get("biome", ""), [])
    if i < arr.size():
        return Color(arr[i])
    return Color(fallback)

func _draw() -> void:
    var npcs: Dictionary = loc.get("npcs", {})
    var exits: Dictionary = loc.get("exits", {})
    for y in grid.size():
        var row: String = grid[y]
        for x in row.length():
            var ch := row[x]
            var r := Rect2(x * TILE, y * TILE, TILE, TILE)
            _draw_tile(x, y, ch)
            if exits.has(ch):
                var cx := float(x * TILE + 8)
                var cy := float(y * TILE + 8)
                var pulse := 0.5 + 0.5 * sin(_anim_t * 3.0 + float(x + y))
                draw_circle(Vector2(cx, cy), 7.0 + pulse * 2.0, Color("#ffd23c", 0.10 + 0.12 * pulse))
                draw_rect(Rect2(cx - 4, cy - 4, 8, 8), Color("#ffd23c55"), true)
                var pts := PackedVector2Array([
                    Vector2(cx, cy - 5), Vector2(cx + 5, cy),
                    Vector2(cx, cy + 5), Vector2(cx - 5, cy)])
                draw_colored_polygon(pts, Color("#ffd23c").lightened(0.25 * pulse))
            elif npcs.has(ch):
                Sprites.draw_npc(self, r, npcs[ch])
            elif ch in NODES:
                var nc: Color = NODE_COLORS.get(ch, Color("#f0c020"))
                draw_circle(r.get_center(), 5.0, Color(nc, 0.3))
                draw_circle(r.get_center(), 3.5, nc)
            elif (ch == "K" or ch == "Z") and loc.get("boss") != null:
                Sprites.draw_mob(self, r, DataDB.bosses.get(loc["boss"], ["mob"])[0])
    # ── рыбы: плавают и выпрыгивают из воды (анимация как в pygame-версии) ──
    for f in fish:
        var ph: float = fmod(_anim_t * float(f.spd) + float(f.off), 6.0)
        var base := Vector2(f.pos.x * TILE, f.pos.y * TILE)
        if ph < 1.0:                    # прыжок по дуге
            var dy := -sin(ph * PI) * 10.0
            Sprites.draw_grid(self, Rect2(base.x, base.y + dy - 2.0, TILE, TILE), "fish")
            if ph < 0.25 or ph > 0.75:  # всплеск на входе/выходе
                draw_circle(base + Vector2(TILE * 0.5, TILE * 0.8), 2.5, Color("#7ab0e0", 0.7))
        elif ph < 1.5:                  # расходящиеся круги
            draw_arc(base + Vector2(TILE * 0.5, TILE * 0.6), (ph - 1.0) * 12.0,
                     0, TAU, 12, Color("#7ab0e0", 0.5), 1.0)
        elif ph > 3.0 and ph < 3.4:     # изредка мелькает спинка
            draw_circle(base + Vector2(TILE * 0.5, TILE * 0.55), 2.0, Color("#d05a2a", 0.8))
    for w in wanderers:
        var wr := Rect2(w.pos.x * TILE, w.pos.y * TILE, TILE, TILE)
        if w.kind == "teplichnaya":       # светящаяся голова — заметный тёплый ореол
            var glow := 0.5 + 0.5 * sin(_anim_t * 2.0)
            draw_circle(wr.get_center() + Vector2(0, -3), 11.0 + glow * 3.0,
                        Color("#f0e8a0", 0.14 + 0.10 * glow))
            draw_circle(wr.get_center() + Vector2(0, -3), 6.5 + glow * 1.5,
                        Color("#fff8c8", 0.22 + 0.14 * glow))
        elif w.kind == "zombie":          # зомби — такой же ореол, но тухло-зелёный
            var zg := 0.5 + 0.5 * sin(_anim_t * 2.0)
            draw_circle(wr.get_center() + Vector2(0, -3), 11.0 + zg * 3.0,
                        Color("#8ab04a", 0.13 + 0.09 * zg))
            draw_circle(wr.get_center() + Vector2(0, -3), 6.5 + zg * 1.5,
                        Color("#b6e07a", 0.20 + 0.13 * zg))
        Sprites.draw_npc(self, wr, w.kind)
    for m in mobs:
        Sprites.draw_mob(self, Rect2(m.pos.x * TILE, m.pos.y * TILE, TILE, TILE), m.enemy[0])
    Sprites.draw_grid(self, Rect2(ppos.x * TILE, ppos.y * TILE, TILE, TILE), "player")


func _draw_tile(x: int, y: int, ch: String) -> void:
    var px := x * TILE
    var py := y * TILE
    var r := Rect2(px, py, TILE, TILE)
    var h := (x * 7 + y * 13) % 97
    match ch:
        "#":
            draw_rect(r, _bcol(2, "#15151f"), true)
            var bc := _bcol(3, "#1c1c28")
            draw_rect(Rect2(px, py + 7, TILE, 1), bc, true)
            if y % 2 == 0:
                draw_rect(Rect2(px + 7, py, 1, 8), bc, true)
            else:
                draw_rect(Rect2(px + 3, py + 7, 1, 9), bc, true)
                draw_rect(Rect2(px + 11, py + 7, 1, 9), bc, true)
        "T":
            draw_rect(r, Color("#172013"), true)
            draw_rect(Rect2(px + 6, py + 10, 3, 6), Color("#3a2818"), true)
            draw_rect(Rect2(px + 3, py + 4, 10, 7), Color("#1a5518"), true)
            draw_rect(Rect2(px + 4, py + 3, 8, 9), Color("#1a5518"), true)
            draw_rect(Rect2(px + 5, py + 4, 5, 4), Color("#247020"), true)
        "R":
            draw_rect(r, Color("#231e17"), true)
            draw_rect(Rect2(px + 3, py + 5, 10, 8), Color("#3a3a42"), true)
            draw_rect(Rect2(px + 4, py + 4, 8, 9), Color("#3a3a42"), true)
            draw_rect(Rect2(px + 4, py + 5, 5, 3), Color("#4a4a55"), true)
        "~":
            draw_rect(r, Color("#0e3260"), true)
            var wo := int(float(h) + _anim_t * 5.0) % 8   # бегущие блики
            draw_rect(Rect2(px + wo, py + 4, 7, 1), Color("#185088"), true)
            draw_rect(Rect2(px + (wo + 4) % 8, py + 10, 6, 1), Color("#185088"), true)
        "i":
            draw_rect(r, Color("#7fc6dc"), true)
            draw_rect(Rect2(px + 3 + h % 6, py + 3 + h % 5, 2, 2), Color("#aae4ff"), true)
        "s":
            draw_rect(r, Color("#cdd5dd"), true)
            if h % 3 == 0:
                draw_rect(Rect2(px + 4 + h % 7, py + 4 + h % 5, 2, 1), Color("#dde5ee"), true)
        _:
            _draw_ground_or_grass(px, py, ch, h)


func _draw_ground_or_grass(px: int, py: int, ch: String, h: int) -> void:
    if ch == ",":
        var bases := [Color("#2c5f27"), Color("#2a5825"), Color("#2e6329")]
        draw_rect(Rect2(px, py, TILE, TILE), bases[h % 3], true)
        draw_rect(Rect2(px + 3 + h % 4, py + 7 + h % 3, 1, 3), Color("#3a7a32"), true)
        draw_rect(Rect2(px + 8 + h % 3, py + 6 + h % 4, 1, 4), Color("#245420"), true)
        draw_rect(Rect2(px + 12 + h % 2, py + 8 + h % 3, 1, 3), Color("#3e8036"), true)
    elif ch == "\"":
        var bases := [Color("#1e4a1a"), Color("#1c4418"), Color("#204e1c")]
        draw_rect(Rect2(px, py, TILE, TILE), bases[h % 3], true)
        draw_rect(Rect2(px + 2 + h % 3, py + 3, 1, 7), Color("#2d6828"), true)
        draw_rect(Rect2(px + 6 + h % 2, py + 2, 1, 8), Color("#163812"), true)
        draw_rect(Rect2(px + 10 + h % 3, py + 4, 1, 6), Color("#2d6828"), true)
        draw_rect(Rect2(px + 13 + h % 2, py + 3, 1, 7), Color("#1a3e16"), true)
    else:
        draw_rect(Rect2(px, py, TILE, TILE), _bcol(0, "#231e17"), true)
        if h % 5 < 2:
            draw_rect(Rect2(px + 3 + h % 8, py + 3 + h % 7, 1, 1), _bcol(1, "#2d261e"), true)
        # редкий декор по биому: цветок / камешек / черта
        var d := h % 29
        if d == 0:
            var acc := _bcol(4, "#7fae4a")
            draw_rect(Rect2(px + 4 + h % 6, py + 6 + h % 5, 2, 2), acc, true)
            draw_rect(Rect2(px + 5 + h % 6, py + 7 + h % 5, 1, 1), acc.lightened(0.45), true)
        elif d == 1:
            draw_rect(Rect2(px + 8 + h % 4, py + 9 + h % 3, 3, 2), _bcol(3, "#1c1c28").lightened(0.2), true)
        elif d == 2:
            draw_rect(Rect2(px + 3 + h % 5, py + 11, 5, 1), _bcol(1, "#2d261e").darkened(0.15), true)
