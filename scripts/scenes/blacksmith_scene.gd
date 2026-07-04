extends Control
## Кузнец: продаёт дорого (item.buy), покупает дёшево (item.sell).

signal closed()

var player: Player
var menu: SoulMenu
var speech: Label
var mode := "root"            # root | buy | sell
var cur_list: Array = []

const STOCK := ["weapon_0_2", "weapon_2_3", "armor_0_2", "armor_1_3", "shield_0_2",
                "trinket_0_2", "ring_lifesteal_3", "ring_power_3", "ring_crit_3"]


func _ready() -> void:
    player = GameState.player
    ScreenFit.attach(self, Color("#120c0a"))
    _lbl("🔨 КУЗНЕЦ", 24, Vector2(24, 20), 400, HORIZONTAL_ALIGNMENT_LEFT, Color("#f0997b"))
    speech = _lbl("«Гляди, што выковал. Дорого. Куёт — не гладит.»", 15,
                  Vector2(24, 60), 592, HORIZONTAL_ALIGNMENT_LEFT, Color("#f5c4b3"))
    speech.size = Vector2(592, 48)
    speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    menu = SoulMenu.new()
    menu.position = Vector2(40, 140)
    menu.line_h = 22
    menu.max_visible = 13      # большая сумка — список скроллится, не утекает за экран
    add_child(menu)
    menu.chosen.connect(_on_choose)
    menu.cancelled.connect(_on_cancel)
    _root()


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


func _root() -> void:
    mode = "root"
    menu.setup(["Купить снаряжение (дорого)", "Продать своё (дёшево)", "Уйти"])


func _on_cancel() -> void:
    if mode == "root":
        closed.emit()
    else:
        _root()


func _on_choose(i: int) -> void:
    match mode:
        "root":
            match i:
                0: _buy_list()
                1: _sell_list()
                2: closed.emit()
        "buy": _do_buy(i)
        "sell": _do_sell(i)


func _buy_list() -> void:
    mode = "buy"
    cur_list = STOCK.duplicate()
    var labels: Array = []
    for id in STOCK:
        var it = Items.get_item(id)
        labels.append("%s — %d ⛃ (%s)" % [it["name"], int(it["buy"]), Items.buffs_str(id)])
    labels.append("← назад")
    menu.setup(labels)


func _do_buy(i: int) -> void:
    if i >= cur_list.size():
        _root()
        return
    var id = cur_list[i]
    var it = Items.get_item(id)
    var cost := int(it["buy"])
    if player.burmolda >= cost:
        player.burmolda -= cost
        player.add_item(id)
        speech.text = "Куплено: %s.  -%d ⛃  (осталось %d)" % [it["name"], cost, player.burmolda]
    else:
        speech.text = "Нет %d бурмолды. Иди намой руды." % cost


func _sell_list() -> void:
    mode = "sell"
    cur_list = []
    var labels: Array = []
    for pair in Items.owned_gear(player):
        var it = Items.get_item(pair[0])
        if it.get("no_sell", false):     # квестовые вещи кузнец не берёт
            continue
        cur_list.append(pair[0])
        labels.append("%s — за %d ⛃" % [it["name"], int(it["sell"])])
    if cur_list.is_empty():
        labels.append("(нечего продавать)")
    labels.append("← назад")
    menu.setup(labels)


func _do_sell(i: int) -> void:
    if i >= cur_list.size():
        _root()
        return
    var id = cur_list[i]
    var it = Items.get_item(id)
    if player.remove_item(id):
        player.burmolda += int(it["sell"])
        speech.text = "Продано: %s.  +%d ⛃" % [it["name"], int(it["sell"])]
        _sell_list()
