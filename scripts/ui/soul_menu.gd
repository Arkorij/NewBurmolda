extends Control
class_name SoulMenu
## Меню в стиле Undertale: список опций, «душа»-курсор, стрелки + ENTER/ESC.
## При max_visible > 0 длинный список прокручивается окном (▲/▼ показывают,
## что выше/ниже есть ещё пункты) — опции не «утекают» за край экрана.

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
var max_visible := 0            # 0 = без ограничения (вертикальные меню)
var _scroll := 0                # первый видимый пункт


func _ready() -> void:
    font = ThemeDB.fallback_font
    set_process_unhandled_input(true)


func setup(opts: Array, horiz := false) -> void:
    options = opts
    horizontal = horiz
    index = 0
    _scroll = 0
    visible = true
    enabled = true
    queue_redraw()


func hide_menu() -> void:
    enabled = false
    visible = false


func show_menu() -> void:
    ## Вернуть спрятанное меню с тем же списком (после многостраничной речи).
    enabled = true
    visible = true
    queue_redraw()


func visible_range() -> Vector2i:
    ## [первый, последний+1) видимый пункт — с учётом окна прокрутки.
    if horizontal or max_visible <= 0 or options.size() <= max_visible:
        return Vector2i(0, options.size())
    return Vector2i(_scroll, mini(_scroll + max_visible, options.size()))


func _ensure_visible() -> void:
    if horizontal or max_visible <= 0 or options.size() <= max_visible:
        _scroll = 0
        return
    if index < _scroll:
        _scroll = index
    elif index >= _scroll + max_visible:
        _scroll = index - max_visible + 1
    _scroll = clampi(_scroll, 0, options.size() - max_visible)


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
        _ensure_visible()
        queue_redraw()
        accept_event()


func _draw() -> void:
    var vr := visible_range()
    var scrolled := not horizontal and max_visible > 0 and options.size() > max_visible
    var row := 0
    for i in range(vr.x, vr.y):
        var sel := i == index
        var p := Vector2(i * col_w, 0) if horizontal else Vector2(0, row * line_h)
        var col := Color("#f0f0ff") if sel else Color("#9090a8")
        if sel:
            Sprites.draw_heart(self, Vector2(p.x + 7, p.y + line_h * 0.5 - 1),
                               float(font_size) - 1.0, Color("#ff2b2b"))
        draw_string(font, Vector2(p.x + 18, p.y + line_h - 7), str(options[i]),
                    HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
        row += 1
    if scrolled:
        var dim := Color("#7a7a94")
        if vr.x > 0:
            draw_string(font, Vector2(2, -4), "▲ ещё %d" % vr.x,
                        HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)
        if vr.y < options.size():
            draw_string(font, Vector2(2, max_visible * line_h + 11),
                        "▼ ещё %d" % (options.size() - vr.y),
                        HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)
