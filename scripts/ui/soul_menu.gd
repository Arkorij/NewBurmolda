extends Control
class_name SoulMenu
## Меню в стиле Undertale: список опций, «душа»-курсор, стрелки + ENTER/ESC.

signal chosen(index: int)
signal cancelled()

var options: Array = []
var index := 0
var enabled := true
var horizontal := false
var line_h := 24
var col_w := 150
var font_size := 16
var font: Font


func _ready() -> void:
    font = ThemeDB.fallback_font
    set_process_unhandled_input(true)


func setup(opts: Array, horiz := false) -> void:
    options = opts
    horizontal = horiz
    index = 0
    visible = true
    enabled = true
    queue_redraw()


func hide_menu() -> void:
    enabled = false
    visible = false


func _unhandled_input(event: InputEvent) -> void:
    if not enabled or not visible or options.is_empty():
        return
    var prev := index
    if horizontal:
        if event.is_action_pressed("ui_right"):
            index = (index + 1) % options.size()
        elif event.is_action_pressed("ui_left"):
            index = (index - 1 + options.size()) % options.size()
    else:
        if event.is_action_pressed("ui_down"):
            index = (index + 1) % options.size()
        elif event.is_action_pressed("ui_up"):
            index = (index - 1 + options.size()) % options.size()
    if event.is_action_pressed("ui_accept"):
        Sfx.play("select")
        chosen.emit(index)
        accept_event()
        return
    if event.is_action_pressed("ui_cancel"):
        cancelled.emit()
        accept_event()
        return
    if index != prev:
        queue_redraw()
        accept_event()


func _draw() -> void:
    for i in options.size():
        var sel := i == index
        var p := Vector2(i * col_w, 0) if horizontal else Vector2(0, i * line_h)
        var col := Color("#f0f0ff") if sel else Color("#9090a8")
        if sel:
            Sprites.draw_heart(self, Vector2(p.x + 7, p.y + line_h * 0.5 - 1),
                               float(font_size) - 1.0, Color("#ff2b2b"))
        draw_string(font, Vector2(p.x + 18, p.y + line_h - 7), str(options[i]),
                    HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
