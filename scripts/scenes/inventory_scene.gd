extends Control
## Инвентарь: слева — ячейки надетого (6 слотов), справа — вкладки по категориям
## (оружие/броня/щиты/обереги/кольца/припасы/добыча/квестовое) со скроллом.
## ←/→ — вкладки, ↑/↓ — по списку, ENTER — надеть/снять, ESC — выход.
## Всё рисуется в _draw (пиксель-стиль игры), спрайты предметов — Sprites.item_key.

signal closed()

var player: Player

const TABS := [
    {"id": "weapon", "name": "ОРУЖИЕ"},
    {"id": "armor", "name": "БРОНЯ"},
    {"id": "shield", "name": "ЩИТЫ"},
    {"id": "trinket", "name": "ОБЕРЕГИ"},
    {"id": "ring", "name": "КОЛЬЦА"},
    {"id": "supplies", "name": "ПРИПАСЫ"},
    {"id": "loot", "name": "ДОБЫЧА"},
    {"id": "quest", "name": "КВЕСТ"},
]
const GEAR_SLOTS := ["weapon", "armor", "shield", "trinket", "ring"]
const EQUIP_CELLS := ["weapon", "armor", "shield", "trinket", "ring1", "ring2"]
const TIER_COLORS := {
    0: Color("#9a6a4a"), 1: Color("#a8a8b4"), 2: Color("#8fd0e8"),
    3: Color("#9acd32"), 4: Color("#f0c040"), 5: Color("#9b5cff"),
}
const ROWS_VISIBLE := 8          # строк списка на экране
const ROW_H := 42
const LIST_X := 220.0
const LIST_W := 404.0
const LIST_Y := 84.0

var tab_i := 0
var sel_i := 0
var scroll := 0
var entries: Array = []          # текущая вкладка: [{key,label,sub,action,slot,qty}]
var font: Font


func _ready() -> void:
    ScreenFit.attach(self)
    player = GameState.player
    font = ThemeDB.fallback_font
    set_process_unhandled_input(true)
    _rebuild()


# ─────────────── данные вкладок ───────────────
func _rebuild() -> void:
    entries = _build_tab(TABS[tab_i]["id"])
    sel_i = clampi(sel_i, 0, maxi(0, entries.size() - 1))
    _clamp_scroll()
    queue_redraw()


func _build_tab(tid: String) -> Array:
    var out: Array = []
    if tid in GEAR_SLOTS:
        # надетое в этот слот — первым (у колец два слота)
        var eq := Items.equipment(player)
        var slots := ["ring1", "ring2"] if tid == "ring" else [tid]
        for s in slots:
            var id = eq.get(s)
            if id != null:
                var it = Items.get_item(id)
                out.append({"key": id, "label": "● " + str(it["name"]),
                    "sub": Items.buffs_str(id), "action": "unequip", "slot": s, "qty": 1})
        for pair in Items.owned_gear(player):
            var it2 = Items.get_item(pair[0])
            if str(it2.get("slot", "")) != tid:
                continue
            out.append({"key": pair[0], "label": str(it2["name"]),
                "sub": Items.buffs_str(pair[0]), "action": "equip", "slot": tid,
                "qty": int(pair[1])})
        return out
    # вещи под активную квестовую сдачу (например ОЗУ для Попова) лежат в
    # КВЕСТ и не продаются; сдал квест — резерв снят, вещь снова в ДОБЫЧЕ
    var reserved := Quests.fetch_reserved(player)
    for key in player.inventory:
        if DataDB.items.has(key):
            continue                       # снаряжение — в своих вкладках
        var qty := int(player.inventory[key])
        var is_supply: bool = str(key).begins_with("зелье") or _is_food(str(key))
        var is_loot: bool = DataDB.resources.has(key)
        var is_reserved: bool = reserved.has(key)
        match tid:
            "supplies":
                if is_supply:
                    out.append({"key": key, "label": str(key),
                        "sub": "используется в БОЮ (меню ПРЕДМЕТ)",
                        "action": "", "slot": "", "qty": qty})
            "loot":
                if is_loot and not is_supply and not is_reserved:
                    out.append({"key": key, "label": str(key),
                        "sub": "цена продажи: %d ⛃ (Зав Воздуха/скупка)" % int(DataDB.resources[key]),
                        "action": "", "slot": "", "qty": qty})
            "quest":
                if is_reserved:
                    out.append({"key": key, "label": str(key),
                        "sub": "🔒 нужно отдать по квесту — пока не продаётся",
                        "action": "", "slot": "", "qty": qty})
                elif not is_loot and not is_supply:
                    out.append({"key": key, "label": str(key),
                        "sub": "особая вещь — пригодится по сюжету",
                        "action": "", "slot": "", "qty": qty})
    out.sort_custom(func(a, b): return str(a["label"]) < str(b["label"]))
    return out


func _is_food(key: String) -> bool:
    for f in DataDB.food:
        if str(f[0]) == key:
            return true
    return false


# ─────────────── управление ───────────────
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        closed.emit()
        accept_event()
        return
    if event.is_action_pressed("ui_right"):
        tab_i = (tab_i + 1) % TABS.size()
        sel_i = 0
        scroll = 0
        Sfx.play("select")
        _rebuild()
        accept_event()
    elif event.is_action_pressed("ui_left"):
        tab_i = (tab_i - 1 + TABS.size()) % TABS.size()
        sel_i = 0
        scroll = 0
        Sfx.play("select")
        _rebuild()
        accept_event()
    elif event.is_action_pressed("ui_down") and not entries.is_empty():
        sel_i = (sel_i + 1) % entries.size()
        _clamp_scroll()
        queue_redraw()
        accept_event()
    elif event.is_action_pressed("ui_up") and not entries.is_empty():
        sel_i = (sel_i - 1 + entries.size()) % entries.size()
        _clamp_scroll()
        queue_redraw()
        accept_event()
    elif event.is_action_pressed("ui_accept") and not entries.is_empty():
        _activate(entries[sel_i])
        accept_event()


func _clamp_scroll() -> void:
    if sel_i < scroll:
        scroll = sel_i
    elif sel_i >= scroll + ROWS_VISIBLE:
        scroll = sel_i - ROWS_VISIBLE + 1
    scroll = clampi(scroll, 0, maxi(0, entries.size() - ROWS_VISIBLE))


func _activate(e: Dictionary) -> void:
    match str(e["action"]):
        "equip":
            Sfx.play("select")
            Items.equip(player, e["key"])
            _rebuild()
        "unequip":
            Sfx.play("select")
            Items.unequip(player, str(e["slot"]))
            _rebuild()


# ─────────────── отрисовка ───────────────
func _tier_color(key: String) -> Color:
    var it = Items.get_item(key)
    if it == null:
        return Color("#5a5a72")
    return TIER_COLORS.get(int(it.get("tier", 0)), Color("#a8a8b4"))


func _draw() -> void:
    ScreenFit.backdrop(self, Color("#0a0a12"))
    draw_string(font, Vector2(16, 30), "🎒 ИНВЕНТАРЬ",
                HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#f0c040"))
    _draw_summary()
    _draw_equipment()
    _draw_tabs()
    _draw_list()
    draw_string(font, Vector2(0, 470),
                "← → вкладки · ↑ ↓ выбор · ENTER надеть/снять · ESC выход",
                HORIZONTAL_ALIGNMENT_CENTER, 640, 12, Color("#6a6a80"))


func _draw_summary() -> void:
    var b := Items.total_buffs(player)
    var parts: Array = []
    for k in ["atk", "def", "hp", "swag", "crit", "block"]:
        if int(b.get(k, 0)) > 0:
            parts.append("%s+%d" % [DataDB.stat_names.get(k, k), int(b[k])])
    var txt := "Бонусы: " + (", ".join(PackedStringArray(parts)) if not parts.is_empty() else "—")
    draw_string(font, Vector2(220, 22), txt,
                HORIZONTAL_ALIGNMENT_LEFT, 404, 11, Color("#9fe1cb"))
    draw_string(font, Vector2(220, 38), "♥ %d/%d   ⛃ %d   ★ свэг %d" % [
                player.hp, player.max_hp, player.burmolda, player.swag],
                HORIZONTAL_ALIGNMENT_LEFT, 404, 11, Color("#8f8fa8"))


func _draw_equipment() -> void:
    draw_string(font, Vector2(16, 62), "НАДЕТО",
                HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8f8fa8"))
    var eq := Items.equipment(player)
    for i in EQUIP_CELLS.size():
        var slot: String = EQUIP_CELLS[i]
        var r := Rect2(14, 70 + i * 62, 194, 56)
        var id = eq.get(slot)
        draw_rect(r, Color("#12121c"), true)
        var border := _tier_color(id) if id != null else Color("#2e2e44")
        draw_rect(r, border, false, 2.0)
        var cell := Rect2(r.position + Vector2(6, 8), Vector2(40, 40))
        draw_rect(cell, Color("#0c0c14"), true)
        draw_string(font, r.position + Vector2(54, 16),
                    DataDB.slot_names.get(slot, slot),
                    HORIZONTAL_ALIGNMENT_LEFT, 134, 10, Color("#8f8fa8"))
        if id != null:
            Sprites.draw_item(self, cell, str(id))
            var nm := str(Items.get_item(id)["name"])
            draw_string(font, r.position + Vector2(54, 33), nm,
                        HORIZONTAL_ALIGNMENT_LEFT, 134, 11, Color("#f0f0ff"))
            draw_string(font, r.position + Vector2(54, 48), Items.buffs_str(id),
                        HORIZONTAL_ALIGNMENT_LEFT, 134, 9, Color("#9fe1cb"))
        else:
            draw_string(font, r.position + Vector2(54, 36), "(пусто)",
                        HORIZONTAL_ALIGNMENT_LEFT, 134, 11, Color("#4a4a5e"))


func _draw_tabs() -> void:
    var tw := LIST_W / TABS.size()
    for i in TABS.size():
        var x := LIST_X + i * tw
        var active := i == tab_i
        var col := Color("#f0c040") if active else Color("#7a7a94")
        if active:
            draw_rect(Rect2(x, 52, tw, 22), Color("#1c1c2e"), true)
            draw_line(Vector2(x, 74), Vector2(x + tw, 74), Color("#f0c040"), 2.0)
        draw_string(font, Vector2(x, 68), TABS[i]["name"],
                    HORIZONTAL_ALIGNMENT_CENTER, tw, 9, col)


func _draw_list() -> void:
    var panel := Rect2(LIST_X - 6, LIST_Y - 4, LIST_W + 12, ROWS_VISIBLE * ROW_H + 8)
    draw_rect(panel, Color("#101018"), true)
    draw_rect(panel, Color("#2e2e44"), false, 1.0)
    if entries.is_empty():
        draw_string(font, Vector2(LIST_X, LIST_Y + 90), "(пусто — добудь в бою или на нодах)",
                    HORIZONTAL_ALIGNMENT_CENTER, LIST_W, 13, Color("#4a4a5e"))
        return
    var last := mini(scroll + ROWS_VISIBLE, entries.size())
    for vi in range(scroll, last):
        var e: Dictionary = entries[vi]
        var y := LIST_Y + (vi - scroll) * ROW_H
        var sel := vi == sel_i
        if sel:
            draw_rect(Rect2(LIST_X - 2, y, LIST_W - 8, ROW_H - 2), Color("#1c1c2e"), true)
            Sprites.draw_heart(self, Vector2(LIST_X + 8, y + ROW_H * 0.5),
                               13.0, Color("#ff2b2b"))
        var cell := Rect2(LIST_X + 18, y + 3, 36, 36)
        draw_rect(cell, Color("#0c0c14"), true)
        draw_rect(cell, _tier_color(str(e["key"])), false, 1.0)
        Sprites.draw_item(self, cell, str(e["key"]))
        var name_col := Color("#f0f0ff") if sel else Color("#c0c0d4")
        var label := str(e["label"])
        if int(e["qty"]) > 1:
            label += "  ×%d" % int(e["qty"])
        draw_string(font, Vector2(LIST_X + 64, y + 17), label,
                    HORIZONTAL_ALIGNMENT_LEFT, LIST_W - 84, 13, name_col)
        draw_string(font, Vector2(LIST_X + 64, y + 33), str(e["sub"]),
                    HORIZONTAL_ALIGNMENT_LEFT, LIST_W - 84, 10, Color("#8f8fa8"))
        if str(e["action"]) != "":
            var hint := "снять" if str(e["action"]) == "unequip" else "надеть"
            draw_string(font, Vector2(LIST_X + LIST_W - 62, y + 25), hint,
                        HORIZONTAL_ALIGNMENT_RIGHT, 44, 10, Color("#6a6a80"))
    # скроллбар + индикаторы «выше/ниже есть ещё»
    if entries.size() > ROWS_VISIBLE:
        var track := Rect2(LIST_X + LIST_W - 2, LIST_Y, 4, ROWS_VISIBLE * ROW_H)
        draw_rect(track, Color("#1c1c2e"), true)
        var frac := float(ROWS_VISIBLE) / float(entries.size())
        var pos := float(scroll) / float(entries.size() - ROWS_VISIBLE)
        var th := maxf(18.0, track.size.y * frac)
        draw_rect(Rect2(track.position.x, track.position.y + pos * (track.size.y - th),
                        4, th), Color("#5a5a72"), true)
        if scroll > 0:
            draw_string(font, Vector2(LIST_X, LIST_Y - 6), "▲ ещё %d" % scroll,
                        HORIZONTAL_ALIGNMENT_RIGHT, LIST_W - 12, 10, Color("#7a7a94"))
        if last < entries.size():
            draw_string(font, Vector2(LIST_X, LIST_Y + ROWS_VISIBLE * ROW_H + 12),
                        "▼ ещё %d" % (entries.size() - last),
                        HORIZONTAL_ALIGNMENT_RIGHT, LIST_W - 12, 10, Color("#7a7a94"))
