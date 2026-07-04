extends Control
## Журнал квестов: главная цель + список взятых заданий с прогрессом.

signal closed()


func _ready() -> void:
    var p := GameState.player
    ScreenFit.attach(self, Color("#0a0a12"))
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
    # задание Зава Воздуха (флаговое): найти ОЗУ
    if p.flags.get("popov_ozu_taken", false):
        if p.flags.get("popov_ozu_done", false):
            lines.append("• Найди ОЗУ — ✔ сдано (Зав теперь скупает по-царски)")
        else:
            lines.append("• Найди ОЗУ — планка в сундуках Адской Шахты (редкость!)")
    # задание Воздухана живёт на флагах (не в системе квестов) — показать
    if p.flags.get("vozduhan_quest_taken", false):
        if p.flags.get("vozduhan_quest_done", false):
            lines.append("• Задание Воздухана — ✔ «выполнено» (мы-то знаем)")
        else:
            lines.append("• Задание Воздухана — поймать эхо, взвесить туман, полрадуги")
            lines.append("    (говорят, сдаётся как-то хитро...)")
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
