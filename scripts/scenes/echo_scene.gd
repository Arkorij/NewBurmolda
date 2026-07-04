extends Control
## Мини-игра «Эхо болота»: повтори растущую последовательность стрелок (Simon).
## Каждый пройденный раунд — кринж; в конце — бурмолда по числу раундов. Emit done.

signal done()

var seq: Array = []
var input_idx := 0
var phase := "show"           # show | input | over
var show_i := 0
var show_t := 0.0
var flash := -1
var completed := 0
var info_lbl: Label

const PADS := {
    0: Rect2(290, 150, 60, 50), 1: Rect2(290, 272, 60, 50),
    2: Rect2(208, 211, 60, 50), 3: Rect2(372, 211, 60, 50),
}


func _ready() -> void:
    ScreenFit.attach(self)
    _lbl("🎵 ЭХО БОЛОТА", 26, 66, Color("#35d6d6"))
    info_lbl = _lbl("Смотри и повторяй эхо стрелками.", 15, 396, Color("#9090a8"))
    set_process(true)
    set_process_unhandled_input(true)
    _next_round()


func _lbl(txt: String, sz: int, y: int, col: Color) -> Label:
    var l := Label.new()
    l.text = txt
    l.position = Vector2(0, y)
    l.size = Vector2(640, 40)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", sz)
    l.add_theme_color_override("font_color", col)
    add_child(l)
    return l


func _next_round() -> void:
    seq.append(randi() % 4)
    input_idx = 0
    phase = "show"
    show_i = 0
    show_t = 0.0
    flash = -1
    info_lbl.text = "Эхо №%d — смотри..." % seq.size()


func _process(delta: float) -> void:
    match phase:
        "show":
            show_t += delta
            if show_t >= 0.55:
                show_t = 0.0
                if show_i < seq.size():
                    flash = seq[show_i]
                    show_i += 1
                else:
                    flash = -1
                    phase = "input"
                    info_lbl.text = "Повторяй!"
                queue_redraw()
        "input":
            if flash >= 0:
                show_t += delta
                if show_t > 0.18:
                    flash = -1
                    queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
    if phase == "input":
        var d := -1
        if event.is_action_pressed("ui_up"):
            d = 0
        elif event.is_action_pressed("ui_down"):
            d = 1
        elif event.is_action_pressed("ui_left"):
            d = 2
        elif event.is_action_pressed("ui_right"):
            d = 3
        if d >= 0:
            accept_event()
            flash = d
            show_t = 0.0
            queue_redraw()
            if d == int(seq[input_idx]):
                input_idx += 1
                if input_idx == seq.size():
                    completed += 1
                    GameState.player.add_cringe(4)
                    _next_round()
            else:
                _over()
    elif phase == "over" and event.is_action_pressed("ui_accept"):
        accept_event()
        done.emit()


func _over() -> void:
    phase = "over"
    var reward := completed * 12
    GameState.player.burmolda += reward
    if completed >= 3:
        GameState.player.add_item("самоцвет свэга")
    info_lbl.text = "Эхо затихло. Раундов: %d.  +%d бурмолды.  ENTER" % [completed, reward]
    queue_redraw()


func _draw() -> void:
    ScreenFit.backdrop(self, Color("#0a1014"))
    for k in PADS:
        var col := Color("#35d6d6") if flash == k else Color("#183038")
        draw_rect(PADS[k], col, true)
        draw_rect(PADS[k], Color("#5a7a80"), false, 2.0)
