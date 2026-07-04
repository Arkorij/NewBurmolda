extends Control
## Пиксель-арт плакат перед боссом: огромный портрет (пиксель-сетка босса),
## вращающиеся лучи, пиксельная рамка, титул + строка-лор.
## Задать до add_child: title_text, subtitle_text, color, sprite_key, flavor.

signal done()

var title_text := ""
var subtitle_text := "★ БОСС ★"
var color := Color("#c0293a")
var sprite_key := ""             # ключ пиксель-сетки босса (kalitin/tsizi/...)
var flavor := ""                 # строка-лор под титулом
var _t := 0.0


func _ready() -> void:
    ScreenFit.attach(self)
    set_process(true)
    set_process_unhandled_input(true)


func _process(delta: float) -> void:
    _t += delta
    queue_redraw()


func _draw() -> void:
    # ── фон: почти чёрный с тёмным градиентом цвета босса (на всё окно) ──
    ScreenFit.backdrop(self, Color("#050308"))
    var vs := get_viewport_rect().size
    for i in range(6):
        var a := 0.05 - i * 0.007
        draw_rect(Rect2(-position.x, 90 + i * 40, vs.x, 40),
                  Color(color.r, color.g, color.b, maxf(a, 0.0)), true)

    # ── вращающиеся лучи из центра (длина — до краёв любого окна) ──
    var c := Vector2(320, 208)
    var ray := maxf(vs.x, vs.y) * 0.72
    for k in range(10):
        var a0 := _t * 0.35 + k * TAU / 10.0
        var pts := PackedVector2Array([
            c,
            c + Vector2.from_angle(a0) * ray,
            c + Vector2.from_angle(a0 + 0.14) * ray])
        draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.05))

    # ── пульсирующий ореол + тень-постамент ──
    var pulse := 0.5 + 0.5 * sin(_t * 2.2)
    for i in range(4, 0, -1):
        draw_circle(c, 92.0 + i * 14.0 + pulse * 6.0,
                    Color(color.r, color.g, color.b, 0.045 * i))
    draw_rect(Rect2(230, 316, 180, 10), Color("#000000", 0.55), true)

    # ── сам босс: огромный пиксель-портрет (лёгкое парение) ──
    var bob := sin(_t * 1.8) * 4.0
    if sprite_key != "" and Sprites.has(sprite_key):
        Sprites.draw_grid(self, Rect2(216, 104 + bob, 208, 208), sprite_key)
    else:
        var d := 72.0
        draw_colored_polygon(PackedVector2Array([
            c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), color)

    # ── пиксельная рамка по краю экрана ──
    var fc1 := color
    var fc2 := color.darkened(0.45)
    var s := 8
    var x := 12
    while x < 628:
        draw_rect(Rect2(x, 12, s, s), fc1 if (x / s) % 2 == 0 else fc2, true)
        draw_rect(Rect2(x, 460, s, s), fc2 if (x / s) % 2 == 0 else fc1, true)
        x += s
    var y := 12
    while y < 468:
        draw_rect(Rect2(12, y, s, s), fc2 if (y / s) % 2 == 0 else fc1, true)
        draw_rect(Rect2(620, y, s, s), fc1 if (y / s) % 2 == 0 else fc2, true)
        y += s

    # ── тексты ──
    var f := ThemeDB.fallback_font
    draw_string(f, Vector2(0, 72), subtitle_text, HORIZONTAL_ALIGNMENT_CENTER, 640, 20,
                color.lightened(0.35))
    # титул с пиксель-тенью
    draw_string(f, Vector2(3, 385), title_text, HORIZONTAL_ALIGNMENT_CENTER, 640, 46, Color("#000000"))
    draw_string(f, Vector2(0, 382), title_text, HORIZONTAL_ALIGNMENT_CENTER, 640, 46, Color("#ffffff"))
    if flavor != "":
        draw_string(f, Vector2(0, 415), flavor, HORIZONTAL_ALIGNMENT_CENTER, 640, 15, Color("#9a90a8"))
    draw_string(f, Vector2(0, 448), "▼ ENTER", HORIZONTAL_ALIGNMENT_CENTER, 640, 13, Color("#6a6a80"))


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
        done.emit()
        accept_event()
