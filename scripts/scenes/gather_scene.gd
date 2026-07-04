extends Control
## Мини-игра добычи: качающийся маркер — останови в зелёной зоне (центр = жила).
## node_type задать до add_child. 3 попытки → ресурсы в сумку. Emit done.

signal done()

var node_type := "mine"
var info: Dictionary
var res_list: Array
var phase := "swing"          # swing | result | summary
var marker := 0.0
var dir := 1.0
var rounds_left := 3
var got: Array = []
var title_lbl: Label
var info_lbl: Label

const BAR := Rect2(120, 236, 400, 28)
const SPEED := 1.5


func _ready() -> void:
    ScreenFit.attach(self)
    info = DataDB.node_info.get(node_type, {})
    res_list = info.get("resources", [])
    title_lbl = _lbl("%s  %s" % [info.get("emoji", ""), info.get("title", "ДОБЫЧА")], 26, 90, Color("#f0c040"))
    _lbl("ENTER — останови маркер. Центр = жила (лучший ресурс).", 14, 150, Color("#b0b0c0"))
    info_lbl = _lbl("Попыток осталось: 3", 15, 300, Color("#9090a8"))
    set_process(true)
    set_process_unhandled_input(true)
    if res_list.is_empty():
        _finalize()


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


func _process(delta: float) -> void:
    if phase == "swing":
        marker += dir * SPEED * delta
        if marker >= 1.0:
            marker = 1.0
            dir = -1.0
        elif marker <= 0.0:
            marker = 0.0
            dir = 1.0
        queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed("ui_accept"):
        return
    accept_event()
    match phase:
        "swing": _stop()
        "result": _next()
        "summary": done.emit()


func _stop() -> void:
    var d := absf(marker - 0.5)
    var m := ""
    if d < 0.06 and not res_list.is_empty():
        var r = res_list[res_list.size() - 1]
        got.append(r)
        m = "★ ЖИЛА! Добыто: %s" % r
    elif d < 0.20 and not res_list.is_empty():
        var r = res_list[randi() % res_list.size()]
        got.append(r)
        m = "Добыто: %s" % r
    else:
        m = "Мимо. Пустая порода."
    phase = "result"
    info_lbl.text = m + "   (ENTER)"
    queue_redraw()


func _next() -> void:
    rounds_left -= 1
    if rounds_left > 0:
        phase = "swing"
        info_lbl.text = "Попыток осталось: %d" % rounds_left
    else:
        _finalize()


func _finalize() -> void:
    for r in got:
        GameState.player.add_item(r)
    GameState.player.add_cringe(2 + got.size() * 2)
    phase = "summary"
    title_lbl.text = "ДОБЫЧА ОКОНЧЕНА"
    var summary := "Ничего не добыл." if got.is_empty() else "В сумку: %s" % ", ".join(PackedStringArray(got))
    info_lbl.text = summary + "   —   ENTER"
    queue_redraw()


func _draw() -> void:
    ScreenFit.backdrop(self, Color("#0a0a12"))
    if phase == "summary":
        return
    draw_rect(BAR, Color("#222232"), true)
    var gx := BAR.position.x + BAR.size.x * 0.30
    draw_rect(Rect2(gx, BAR.position.y, BAR.size.x * 0.40, BAR.size.y), Color("#1d6e3a"), true)
    var yx := BAR.position.x + BAR.size.x * 0.44
    draw_rect(Rect2(yx, BAR.position.y, BAR.size.x * 0.12, BAR.size.y), Color("#c8a020"), true)
    draw_rect(BAR, Color("#e0e0f0"), false, 2.0)
    var mx := BAR.position.x + BAR.size.x * marker
    draw_rect(Rect2(mx - 2, BAR.position.y - 6, 4, BAR.size.y + 12), Color("#ff3030"), true)
