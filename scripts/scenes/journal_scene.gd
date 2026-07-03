extends Control
## Журнал болота: факты-подсказки о мире (листаются стрелками).

signal closed()

var facts: Array
var page := 0
var body: Label


func _ready() -> void:
    facts = DataDB.phrase("SWAMP_FACTS")
    var bg := ColorRect.new()
    bg.color = Color("#07100a")
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    _lbl("📖 ЖУРНАЛ БОЛОТА", 24, Vector2(0, 40), Color("#8fe1cb"))
    body = _lbl("", 17, Vector2(0, 170), Color("#dfe7ef"))
    body.size = Vector2(560, 200)
    body.position = Vector2(40, 170)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _lbl("← → листать · ESC — назад", 13, Vector2(0, 442), Color("#50506a"))
    _show()
    set_process_unhandled_input(true)


func _lbl(txt: String, sz: int, pos: Vector2, col: Color) -> Label:
    var l := Label.new()
    l.text = txt
    l.position = pos
    l.size = Vector2(640, 40)
    l.add_theme_font_size_override("font_size", sz)
    l.add_theme_color_override("font_color", col)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(l)
    return l


func _show() -> void:
    if facts.is_empty():
        body.text = "Пока пусто. Броди по болоту — узнаешь больше."
        return
    body.text = "Факт %d/%d\n\n%s" % [page + 1, facts.size(), facts[page]]


func _unhandled_input(event: InputEvent) -> void:
    if facts.is_empty():
        if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
            closed.emit()
        return
    if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
        page = (page + 1) % facts.size()
        _show()
        accept_event()
    elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
        page = (page - 1 + facts.size()) % facts.size()
        _show()
        accept_event()
    elif event.is_action_pressed("ui_cancel"):
        closed.emit()
        accept_event()
