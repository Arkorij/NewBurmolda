extends Control
## Визит к NPC: портрет, реплики (печатная машинка), опции (talk/buy/choice/sell/learn).
## Данные — DataDB.npcs[kind]; эффекты — NPCEffects; продажа — Econ.

signal closed()

var kind := ""
var cfg: Dictionary
var player: Player

var name_label: Label
var speech: Label
var menu: SoulMenu
var pcolor: Color

var mode := "options"          # "options" | "choice"
var options_data: Array = []
var quest_actions: Array = []
var answers: Array = []
var _full := ""
var _reveal := 0.0

const COLORS := {
    "PURPLE": "#9b5cff", "TOXIC": "#6ee66e", "SICK": "#9acd32", "CYAN": "#35d6d6",
    "MAGENTA": "#ff5cc8", "RED": "#e24b4a", "DEW": "#8fe1cb",
}


func _ready() -> void:
    cfg = DataDB.npcs[kind]
    player = GameState.player
    options_data = cfg.get("options", [])
    _build_ui()
    var p := player
    if not p.flags.get(cfg["flag"], false):
        p.flags[cfg["flag"]] = true
        var msgs: Array = [cfg["intro"]]
        if cfg.get("gift") != null:
            p.add_item(cfg["gift"])
            msgs.append("🎁 Получен предмет: %s" % cfg["gift"])
        _speak(msgs)
    else:
        _speak([_rand(cfg.get("lines", ["..."]))])
    Quests.refresh(player)
    _rebuild_options()
    set_process_unhandled_input(true)


func _build_ui() -> void:
    pcolor = Color(COLORS.get(cfg.get("color", ""), "#cccccc"))
    name_label = _label(cfg.get("name", "?"), 22, Vector2(24, 24), 400, HORIZONTAL_ALIGNMENT_LEFT)
    name_label.add_theme_color_override("font_color", pcolor)

    speech = _label("", 15, Vector2(164, 62), 452, HORIZONTAL_ALIGNMENT_LEFT)
    speech.size = Vector2(452, 130)
    speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    menu = SoulMenu.new()
    menu.position = Vector2(40, 230)
    menu.line_h = 22
    add_child(menu)
    menu.chosen.connect(_on_opt)
    menu.cancelled.connect(_on_cancel)


func _label(txt: String, sz: int, pos: Vector2, w: int, align: int) -> Label:
    var l := Label.new()
    l.text = txt
    l.position = pos
    l.size = Vector2(w, 24)
    l.add_theme_font_size_override("font_size", sz)
    l.horizontal_alignment = align
    add_child(l)
    return l


func _rand(arr: Array) -> String:
    if arr.is_empty():
        return "..."
    return arr[randi() % arr.size()]


func _speak(lines: Array) -> void:
    _full = "\n".join(lines)
    speech.text = _full
    speech.visible_characters = 0
    _reveal = 0.0


func _draw() -> void:
    draw_rect(Rect2(0, 0, 640, 480), Color("#0a0a12"), true)
    draw_rect(Rect2(20, 56, 128, 128), Color("#14141f"), true)
    Sprites.draw_npc(self, Rect2(24, 60, 120, 120), kind)


func _process(delta: float) -> void:
    if speech.visible_characters != -1:
        _reveal += delta * 45.0
        speech.visible_characters = int(_reveal)


func _rebuild_options() -> void:
    mode = "options"
    quest_actions = []
    var labels: Array = []
    for qid in Quests.ready(player, kind):
        quest_actions.append({"kind": "quest_turnin", "qid": qid})
        labels.append("✅ Сдать: %s" % DataDB.quests[qid]["name"])
    for qid in Quests.givable(player, kind):
        quest_actions.append({"kind": "quest_take", "qid": qid})
        labels.append("📜 Взять: %s" % DataDB.quests[qid]["name"])
    for opt in options_data:
        labels.append(opt.get("label", "..."))
    menu.setup(labels)


# ─────────────── выбор опции ───────────────
func _on_opt(i: int) -> void:
    if mode == "choice":
        _apply_answer(answers[i])
        _rebuild_options()
        return
    if i < quest_actions.size():
        var qa: Dictionary = quest_actions[i]
        if qa["kind"] == "quest_take":
            _speak(Quests.start(player, qa["qid"]))
        else:
            _speak(Quests.turn_in(player, qa["qid"]))
        _rebuild_options()
        return
    var opt: Dictionary = options_data[i - quest_actions.size()]
    match opt.get("kind", ""):
        "leave":
            closed.emit()
        "talk":
            player.add_cringe(int(opt.get("cringe", 2)))
            var lines: Array = [_rand(opt.get("lines", cfg.get("lines", ["..."])))]
            if opt.get("swag_burst", false):
                lines.append(_rand(DataDB.phrase("SWAG_BURSTS")))
            _speak(lines)
        "buy":
            _speak(NPCEffects.buy(player, int(opt["cost"]), opt["effect"], opt.get("arg")))
        "custom":
            _speak(NPCEffects.apply(player, opt["effect"], opt.get("arg")))
        "sell":
            var res := Econ.sell_all(player)
            _speak(res[2])
        "learn":
            _speak(_do_learn(opt))
        "choice":
            mode = "choice"
            answers = opt["answers"]
            var texts: Array = []
            for a in answers:
                texts.append(a["text"])
            menu.setup(texts)
            _speak([opt["prompt"]])


func _on_cancel() -> void:
    if mode == "choice":
        _rebuild_options()
    else:
        closed.emit()


func _do_learn(opt: Dictionary) -> Array:
    var flag: String = opt["flag"]
    var cost := int(opt["cost"])
    if player.flags.get(flag, false):
        return ["Ты уже владеешь приёмом «%s»." % opt["move"]]
    if player.burmolda >= cost:
        player.burmolda -= cost
        player.flags[flag] = true
        return ["✦ Ты выучил приём «%s»!" % opt["move"], "Теперь он доступен в меню БОЯ."]
    return ["Нужно %d бурмолды, чтобы выучить приём." % cost]


func _apply_answer(ans: Dictionary) -> void:
    var lines: Array = [ans["line"]]
    var cr := int(ans.get("cringe", 0))
    if cr > 0:
        player.add_cringe(cr)
        lines.append("  (+%d кринж)" % cr)
    var rep := int(ans.get("rep", 0))
    if rep != 0:
        player.reputation += rep
        lines.append("  (репутация %s%d)" % ["+" if rep > 0 else "", rep])
    var money := int(ans.get("money", 0))
    if money < 0:
        var lost: int = min(player.burmolda, -money)
        player.burmolda -= lost
        lines.append("  (-%d бурмолды 💸)" % lost)
    elif money > 0:
        player.burmolda += money
        lines.append("  (+%d бурмолды 💰)" % money)
    _speak(lines)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept") and speech.visible_characters != -1 \
            and speech.visible_characters < _full.length():
        speech.visible_characters = -1
        accept_event()
