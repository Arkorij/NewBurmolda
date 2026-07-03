extends Control
## Журнал квестов: главная цель + список взятых заданий с прогрессом.

signal closed()


func _ready() -> void:
    var p := GameState.player
    var bg := ColorRect.new()
    bg.color = Color("#0a0a12")
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    _lbl("📜 КВЕСТЫ", 24, Vector2(24, 20), 400, HORIZONTAL_ALIGNMENT_LEFT, Color("#f0c040"))
    var lines: Array = [Quests.main_goal(p), ""]
    if p.quests.is_empty():
        lines.append("Активных заданий нет.")
        lines.append("Поговори с болотными: Ямполь, Шестухина, Туша, Дед, Баба...")
    else:
        for qid in p.quests:
            var qq: Dictionary = DataDB.quests[qid]
            lines.append("• %s  —  %s" % [qq["name"], Quests.progress_str(p, qid)])
            lines.append("    %s" % qq["desc"])
    var body := _lbl("\n".join(PackedStringArray(lines)), 15, Vector2(24, 70), 592,
                     HORIZONTAL_ALIGNMENT_LEFT, Color("#dfe7ef"))
    body.size = Vector2(592, 360)
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _lbl("ESC — назад", 13, Vector2(24, 452), 400, HORIZONTAL_ALIGNMENT_LEFT, Color("#6a6a80"))
    set_process_unhandled_input(true)


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


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
        closed.emit()
        accept_event()
