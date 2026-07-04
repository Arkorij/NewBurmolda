extends Control
## Визит к NPC: портрет, реплики (печатная машинка), опции (talk/buy/choice/sell/learn).
## Данные — DataDB.npcs[kind]; эффекты — NPCEffects; продажа — Econ.

signal closed()

var kind := ""
var cfg: Dictionary
var player: Player

var name_label: Label
var speech: Label
var more_label: Label          # «▼ ENTER» при многостраничной речи
var menu: SoulMenu
var pcolor: Color

var mode := "options"          # "options" | "choice"
var options_data: Array = []
var visible_options: Array = []   # options_data после фильтра req_flag/req_not_flag
var used_once: Dictionary = {}    # опции с "once": true — раз за визит (анти-фарм)
var quest_actions: Array = []
var answers: Array = []
var current_choice: Dictionary = {}   # активная choice-опция (для one-time once_flag)
var _full := ""
var _reveal := 0.0
var _pages: Array = []                # длинная речь бьётся на страницы (▼ ENTER),
var _page_i := 0                      # чтобы не налезать на меню опций снизу
const SPEECH_CHARS_PER_LINE := 50     # ширина 452px, шрифт 15 — оценка переноса
const SPEECH_MAX_ROWS := 7            # речь 62..~218, меню с 230 — не залезаем

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
    speech.size = Vector2(452, 156)
    speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    more_label = _label("", 12, Vector2(164, 210), 452, HORIZONTAL_ALIGNMENT_RIGHT)
    more_label.add_theme_color_override("font_color", Color("#7a7a94"))

    menu = SoulMenu.new()
    menu.position = Vector2(40, 230)
    menu.line_h = 22
    menu.max_visible = 10          # у торговцев много опций — скролл, не за экран
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
    ## Длинная речь бьётся на страницы: пока листаем — меню спрятано,
    ## текст никогда не налезает на опции (фикс наложения у торговцев).
    _pages = UiText.paginate(lines, SPEECH_CHARS_PER_LINE, SPEECH_MAX_ROWS)
    _page_i = 0
    _show_page()


func _show_page() -> void:
    _full = _pages[_page_i]
    speech.text = _full
    speech.visible_characters = 0
    _reveal = 0.0
    if _page_i < _pages.size() - 1:
        more_label.text = "▼ ENTER (ещё %d)" % (_pages.size() - _page_i - 1)
        menu.hide_menu()
    else:
        more_label.text = ""
        if not menu.options.is_empty():
            menu.show_menu()


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
    # фильтр опций по флагам (req_flag должен стоять, req_not_flag — нет)
    visible_options = []
    for opt in options_data:
        if opt.has("req_flag") and not player.flags.get(opt["req_flag"], false):
            continue
        if opt.has("req_not_flag") and player.flags.get(opt["req_not_flag"], false):
            continue
        if opt.has("req_level") and player.level < int(opt["req_level"]):
            continue          # кнопка открывается по прокачке
        if opt.has("once_flag") and player.flags.get(opt["once_flag"], false):
            continue          # реплика с выбором одноразовая (навсегда)
        if opt.get("once", false) and used_once.has(opt.get("label", "")):
            continue          # сыграно в этот визит — спама по ENTER не будет
        visible_options.append(opt)
        labels.append(opt.get("label", "..."))
    menu.setup(labels)
    if _page_i < _pages.size() - 1:
        menu.hide_menu()       # речь ещё листается — меню появится на последней странице


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
    var opt: Dictionary = visible_options[i - quest_actions.size()]
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
            if opt.get("once", false):
                used_once[opt.get("label", "")] = true
            _speak(NPCEffects.apply(player, opt["effect"], opt.get("arg")))
            _rebuild_options()      # флаги могли открыть/закрыть опции
        "fetch":
            _speak(_do_fetch(opt))
        "sell":
            var res := Econ.sell_all(player, float(opt.get("premium", 1.0)))
            _speak(res[2])
        "learn":
            _speak(_do_learn(opt))
        "choice":
            mode = "choice"
            current_choice = opt
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


func _do_fetch(opt: Dictionary) -> Array:
    ## «Принеси предметы»: проверяем наличие, забираем, платим.
    var need: Dictionary = opt.get("items", {})
    for item in need:
        if int(player.inventory.get(item, 0)) < int(need[item]):
            return ["«Нету у тебя. Ни округлого, ни продолговатого. Пздц.»",
                    "(нужно: %s)" % ", ".join(need.keys())]
    for item in need:
        player.remove_item(item, int(need[item]))
    var lines: Array = [opt.get("line", "«Уважил».")]
    var money := int(opt.get("money", 0))
    if money > 0:
        player.burmolda += money
        lines.append("  (+%d бурмолды 💰)" % money)
    var cr := int(opt.get("cringe", 0))
    if cr > 0:
        player.add_cringe(cr)
        lines.append("  (+%d кринж)" % cr)
    if opt.has("give_item"):
        player.add_item(opt["give_item"])
        lines.append("  🎁 Получено: %s" % opt["give_item"])
    if opt.has("set_flag"):
        player.flags[opt["set_flag"]] = true
        _rebuild_options()      # флаг мог открыть/закрыть опции
    return lines


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
    # эффекты покруче (у «дальних»/странных персонажей выбор весомее)
    var sw := int(ans.get("swag", 0))
    if sw != 0:
        player.swag = max(0, player.swag + sw)
        lines.append("  (свэг %s%d)" % ["+" if sw > 0 else "", sw])
    var mhp := int(ans.get("maxhp", 0))
    if mhp != 0:
        player.max_hp += mhp
        player.hp += mhp
        lines.append("  (макс. HP +%d ♥)" % mhp)
    if ans.has("item"):
        player.add_item(ans["item"])
        lines.append("  🎁 Получено: %s" % ans["item"])
    if ans.has("set_flag"):                 # ответ может открыть следующую реплику
        player.flags[ans["set_flag"]] = true
    if current_choice.has("once_flag"):     # реплика с выбором — одноразовая навсегда
        player.flags[current_choice["once_flag"]] = true
    _speak(lines)


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed("ui_accept"):
        return
    if speech.visible_characters != -1 and speech.visible_characters < _full.length():
        speech.visible_characters = -1       # дописать страницу мгновенно
        accept_event()
    elif _page_i < _pages.size() - 1:        # листнуть длинную речь дальше
        _page_i += 1
        _show_page()
        accept_event()
