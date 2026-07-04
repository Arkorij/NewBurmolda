extends Control
class_name Minimap
## Миникарта текущей локации (правый нижний угол): стены/вода/порталы/NPC/
## ноды точками, мобы и блуждающие NPC цветом, игрок — мигающая красная точка.
## Появилась вместе с зумом камеры (обзор всей локации больше не влезает в кадр).

var ow = null                    # ссылка на Overworld (читаем grid/ppos/mobs)

const MAX_W := 126.0             # максимум пикселей под карту (без рамки)
const MAX_H := 88.0
const PAD := 4.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
    if visible and ow != null:
        queue_redraw()           # дёшево: карта крошечная, зато мобы живут


func _tile_color(ch: String) -> Color:
    if ch in "#TR":
        return Color("#4a4a62")
    if ch == "~":
        return Color("#2a5a9a")
    if ch in "is":
        return Color("#8fb8c8")
    if ch in "mfhjce":
        return Color("#b06ad0")
    return Color("#20202e")      # земля/трава — тёмный фон


func _draw() -> void:
    if ow == null or ow.grid.is_empty():
        return
    var gw: int = ow.grid[0].length()
    var gh: int = ow.grid.size()
    var cell := clampf(minf(MAX_W / float(gw), MAX_H / float(gh)), 1.0, 3.0)
    var pw := float(gw) * cell
    var ph := float(gh) * cell
    var vs := get_viewport_rect().size
    var origin := Vector2(vs.x - pw - PAD - 10.0, vs.y - ph - PAD - 10.0)
    # подложка + рамка
    draw_rect(Rect2(origin - Vector2(PAD, PAD), Vector2(pw + PAD * 2, ph + PAD * 2)),
              Color(0.02, 0.02, 0.06, 0.78), true)
    draw_rect(Rect2(origin - Vector2(PAD, PAD), Vector2(pw + PAD * 2, ph + PAD * 2)),
              Color("#3a3a55"), false, 1.0)
    var t := float(Time.get_ticks_msec()) / 1000.0
    for y in gh:
        var row: String = ow.grid[y]
        for x in gw:
            var ch := row[x]
            var r := Rect2(origin.x + x * cell, origin.y + y * cell, cell, cell)
            if ch >= "1" and ch <= "9":      # портал — пульсирует жёлтым
                draw_rect(r, Color("#ffd24a", 0.6 + 0.4 * sin(t * 4.0)), true)
            elif ow.loc.get("npcs", {}).has(ch) or ch == "K" or ch == "Z":
                draw_rect(r, Color("#35d6d6"), true)
            else:
                draw_rect(r, _tile_color(ch), true)
    for m in ow.mobs:
        draw_rect(Rect2(origin.x + m.pos.x * cell, origin.y + m.pos.y * cell, cell, cell),
                  Color("#ff8a4a"), true)
    for w in ow.wanderers:
        draw_rect(Rect2(origin.x + w.pos.x * cell, origin.y + w.pos.y * cell, cell, cell),
                  Color("#6ee66e"), true)
    # игрок — мигающая точка чуть крупнее клетки
    var pp := Vector2(origin.x + ow.ppos.x * cell, origin.y + ow.ppos.y * cell)
    var blink := 0.65 + 0.35 * sin(t * 6.0)
    draw_rect(Rect2(pp - Vector2(0.5, 0.5), Vector2(cell + 1.0, cell + 1.0)),
              Color(1.0, 0.17, 0.17, blink), true)
