extends Control
## Инвентарь/экипировка: надеть/снять снаряжение (6 слотов, 2 кольца), сводка баффов.

signal closed()

var player: Player
var menu: SoulMenu
var summary: Label
var entries: Array = []


func _ready() -> void:
    player = GameState.player
    var bg := ColorRect.new()
    bg.color = Color("#0a0a12")
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    _lbl("⚔ ЭКИПИРОВКА", 24, Vector2(24, 20), 400, HORIZONTAL_ALIGNMENT_LEFT, Color("#f0c040"))
    summary = _lbl("", 14, Vector2(24, 60), 592, HORIZONTAL_ALIGNMENT_LEFT, Color("#9fe1cb"))
    summary.size = Vector2(592, 64)
    summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    menu = SoulMenu.new()
    menu.position = Vector2(40, 158)
    menu.line_h = 22
    add_child(menu)
    menu.chosen.connect(_on_choose)
    menu.cancelled.connect(func(): closed.emit())
    _rebuild()


func _lbl(txt: String, sz: int, pos: Vector2, w: int, align: int, col: Color) -> Label:
    var l := Label.new()
    l.text = txt
    l.position = pos
    l.size = Vector2(w, 24)
    l.add_theme_font_size_override("font_size", sz)
    l.add_theme_color_override("font_color", col)
    l.horizontal_alignment = align
    add_child(l)
    return l


func _rebuild() -> void:
    entries = []
    var labels: Array = []
    for slot in Items.EQUIP_SLOTS:
        var id = player.equipment.get(slot)
        if id != null:
            entries.append({"a": "unequip", "slot": slot})
            labels.append("● [%s] %s — снять" % [DataDB.slot_names.get(slot, slot), Items.get_item(id)["name"]])
    for pair in Items.owned_gear(player):
        entries.append({"a": "equip", "id": pair[0]})
        labels.append("   %s — надеть (%s)" % [Items.get_item(pair[0])["name"], Items.buffs_str(pair[0])])
    if labels.is_empty():
        labels.append("(нет снаряжения — добудь в бою или у кузнеца)")
        entries.append({"a": "none"})
    labels.append("← выйти (ESC)")
    entries.append({"a": "leave"})
    menu.setup(labels)
    _update_summary()


func _update_summary() -> void:
    var b := Items.total_buffs(player)
    var parts: Array = []
    for k in ["atk", "def", "hp", "swag", "crit", "block"]:
        if int(b.get(k, 0)) > 0:
            parts.append("%s+%d" % [DataDB.stat_names.get(k, k), int(b[k])])
    var effs: Array = []
    for e in Items.ring_effects(player):
        effs.append(DataDB.ring_effects.get(e, {}).get("name", e))
    var pstr := ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "—"
    var estr := ", ".join(PackedStringArray(effs)) if not effs.is_empty() else "—"
    summary.text = "Бонусы: %s\nКольца: %s        ♥ %d/%d   ⛃ %d" % [
        pstr, estr, player.hp, player.max_hp, player.burmolda]


func _on_choose(i: int) -> void:
    match entries[i].get("a"):
        "unequip":
            Items.unequip(player, entries[i]["slot"])
            _rebuild()
        "equip":
            Items.equip(player, entries[i]["id"])
            _rebuild()
        "leave":
            closed.emit()
