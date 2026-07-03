extends Node
## Аудит геймплея (headless): «проигрывает» мир без окна и ищет проблемы:
## недостижимые выходы/NPC/ноды, софтлоки от блуждающих NPC, незачищаемые
## комнаты шахты, невыполнимые квесты (ключи без мобов), битые опции диалогов,
## односторонние переходы. Запуск: --headless -- --audit

var issues: Array = []


func _ready() -> void:
    print("=== АУДИТ ГЕЙМПЛЕЯ ===")
    GameState.new_game("Аудитор")
    _audit_quest_keys()
    _audit_npc_options()
    _audit_exit_symmetry()
    _audit_reachability()
    _audit_dungeon()
    print("\n=== НАЙДЕНО ПРОБЛЕМ: %d ===" % issues.size())
    for i in issues:
        print("  ⚠ ", i)
    get_tree().quit()


func flag_issue(msg: String) -> void:
    if not issues.has(msg):
        issues.append(msg)


# ── квесты: у каждого kill-ключа должен быть реальный моб ──
func _audit_quest_keys() -> void:
    var names: Array = []
    for biome in DataDB.monsters:
        for m in DataDB.monsters[biome]:
            names.append(str(m[0]).to_lower())
    for m in DataDB.enemies:
        names.append(str(m[0]).to_lower())
    for extra in ["зольный жук", "уголёк-живчик", "магмовый краб", "тень шахтёра"]:
        names.append(extra)
    for qid in DataDB.quests:
        var q: Dictionary = DataDB.quests[qid]
        if q.get("type") != "kill":
            continue
        for key in q.get("keys", []):
            var hit := false
            for n in names:
                if key in n:
                    hit = true
                    break
            if not hit:
                flag_issue("КВЕСТ %s: ключ «%s» не совпадает ни с одним мобом" % [qid, key])
        # награда-предмет: либо id из БД, либо простое имя (еда/зелье) — ок
    print("  [ок] ключи kill-квестов проверены")


# ── NPC: у каждой опции валидный kind, у custom — существующий эффект ──
const KNOWN_KINDS := ["talk", "buy", "custom", "sell", "learn", "choice", "leave", "fetch"]
const KNOWN_EFFECTS := ["gain_swag", "bless_hp", "heal_full", "sell_potion", "evade_potion",
    "feast", "beef_up", "give_item", "give_food", "ladushki", "vozduhan_hint",
    "vozduhan_bet", "vozduhan_quest_take", "vozduhan_truth", "vozduhan_lie",
    "popov_ozu_take"]


func _audit_npc_options() -> void:
    for kind in DataDB.npcs:
        for opt in DataDB.npcs[kind].get("options", []):
            var k: String = opt.get("kind", "?")
            if not k in KNOWN_KINDS:
                flag_issue("NPC %s: неизвестный kind опции «%s»" % [kind, k])
            if k == "custom" and not str(opt.get("effect", "")) in KNOWN_EFFECTS:
                flag_issue("NPC %s: custom-эффект «%s» не реализован" % [kind, opt.get("effect")])
            if k == "buy" and not str(opt.get("effect", "")) in KNOWN_EFFECTS:
                flag_issue("NPC %s: buy-эффект «%s» не реализован" % [kind, opt.get("effect")])
    print("  [ок] опции NPC проверены")


# ── переходы: из каждой локации можно вернуться обратно ──
func _audit_exit_symmetry() -> void:
    for lid in DataDB.locations:
        var loc: Dictionary = DataDB.locations[lid]
        for ch in loc.get("exits", {}):
            var target: String = loc["exits"][ch]
            var back := false
            for ch2 in DataDB.locations[target].get("exits", {}):
                if DataDB.locations[target]["exits"][ch2] == lid:
                    back = true
            if not back:
                flag_issue("ПЕРЕХОД %s→%s односторонний (обратно не вернуться)" % [lid, target])
    print("  [ок] симметрия переходов проверена")


# ── проходимость: BFS от точки спавна; блуждающие NPC — препятствия ──
func _audit_reachability() -> void:
    var ow = load("res://scenes/Overworld.tscn").instantiate()
    add_child(ow)
    ow.set_process(false)
    for lid in DataDB.locations:
        for seed_i in range(4):        # 4 раскладки спавнов на локацию
            ow.load_location(lid)
            var blocked: Dictionary = {}
            for w in ow.wanderers:
                blocked[w.pos] = true
            var visited := _bfs(ow, ow.ppos, blocked)
            var loc: Dictionary = ow.loc
            for y in ow.grid.size():
                var row: String = ow.grid[y]
                for x in row.length():
                    var ch := row[x]
                    var p := Vector2i(x, y)
                    var interesting: bool = loc.get("exits", {}).has(ch) \
                            or loc.get("npcs", {}).has(ch) \
                            or (loc.get("boss") != null and (ch == "K" or ch == "Z")) \
                            or ch in "mfhjce"
                    if interesting and not _adjacent_or_in(visited, p):
                        flag_issue("ЛОКАЦИЯ %s: «%s» (%d,%d) недостижим (спавн-раскладка %d)"
                                   % [lid, ch, x, y, seed_i])
            # мобы: до каждого можно дойти? (иначе не набить квест)
            for m in ow.mobs:
                if not _adjacent_or_in(visited, m.pos):
                    flag_issue("ЛОКАЦИЯ %s: моб %s заспавнился в недостижимой зоне"
                               % [lid, m.enemy[0]])
    ow.free()
    print("  [ок] проходимость 35 локаций x4 раскладки проверена")


func _bfs(ow, start: Vector2i, blocked: Dictionary) -> Dictionary:
    var visited: Dictionary = {start: true}
    var queue: Array = [start]
    while not queue.is_empty():
        var p: Vector2i = queue.pop_front()
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var n: Vector2i = p + d
            if visited.has(n) or blocked.has(n):
                continue
            var ch: String = ow._char_at(n.x, n.y)
            if ow._walkable(ch):
                visited[n] = true
                queue.append(n)
    return visited


func _adjacent_or_in(visited: Dictionary, p: Vector2i) -> bool:
    if visited.has(p):
        return true
    for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        if visited.has(p + d):
            return true
    return false


# ── шахта: каждая комната зачищаема и проходима ──
func _audit_dungeon() -> void:
    var dg = load("res://scenes/Dungeon.tscn").instantiate()
    add_child(dg)
    dg.set_process(false)
    for d in range(1, 61):
        dg._enter_room(d, false)
        var st: Dictionary = dg.st
        var blocked: Dictionary = {}
        var visited := _bfs_dungeon(dg, Vector2i(1, dg._midy()))
        # правая дверь достижима?
        if not _adjacent_or_in(visited, Vector2i(int(st.w) - 1, dg._midy())):
            flag_issue("ШАХТА этаж %d: правая дверь недостижима" % d)
        # каждый моб достижим? (иначе комнату не зачистить = СОФТЛОК)
        for m in st.mobs:
            if not _adjacent_or_in(visited, m.pos):
                flag_issue("ШАХТА этаж %d (%s): моб %s недостижим — комнату не зачистить!"
                           % [d, st.kind, m.enemy[0]])
        for c in st.chests:
            if not visited.has(c.pos) and not _adjacent_or_in(visited, c.pos):
                flag_issue("ШАХТА этаж %d: сундук недостижим" % d)
    dg.free()
    print("  [ок] шахта: 60 этажей проверены на зачищаемость")


func _bfs_dungeon(dg, start: Vector2i) -> Dictionary:
    var visited: Dictionary = {start: true}
    var queue: Array = [start]
    while not queue.is_empty():
        var p: Vector2i = queue.pop_front()
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var n: Vector2i = p + d
            if visited.has(n):
                continue
            if dg._cell(n) == ".":
                visited[n] = true
                queue.append(n)
    return visited
