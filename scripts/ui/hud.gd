extends Control
class_name HudPanel
## Верхняя панель надмира: полосы HP и кринжа (опыта), бурмолда, свэг, локация.
## Рисуется в _draw (как весь UI игры). refresh() дёргается надмиром при любом
## изменении состояния; msg — строка-тост под панелью (сейв, гейт, подсказки).

const H := 52                    # высота панели
var loc_name := "?"
var msg := ""
var text := ""                   # собранная строка состояния (для headless-тестов)


func _ready() -> void:
    size = Vector2(640, H + 20)
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh(location_name: String, message := "") -> void:
    loc_name = location_name
    msg = message
    var p := GameState.player
    text = "%s · ♥ %d/%d · кринж %d/%d · ⛃ %d · свэг %d · ур.%d" % [
        loc_name, p.hp, p.max_hp, p.cringe, p.next_level_cringe(),
        p.burmolda, p.swag, p.level]
    if msg != "":
        text += "\n" + msg
    queue_redraw()


func _bar(r: Rect2, ratio: float, back: Color, front: Color, border: Color) -> void:
    draw_rect(r, back, true)
    if ratio > 0.0:
        draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)),
                  front, true)
    draw_rect(r, border, false, 1.0)


func _draw() -> void:
    var font := ThemeDB.fallback_font
    var p := GameState.player

    # подложка + нижняя каёмка
    draw_rect(Rect2(0, 0, 640, H), Color(0.03, 0.03, 0.07, 0.82), true)
    draw_line(Vector2(0, H), Vector2(640, H), Color("#3a3a55"), 2.0)

    # ── локация + ранг/уровень (слева) ──
    draw_string(font, Vector2(10, 19), loc_name,
                HORIZONTAL_ALIGNMENT_LEFT, 168, 14, Color("#ffd479"))
    draw_string(font, Vector2(10, 40), "ур.%d · %s" % [p.level, p.rank()],
                HORIZONTAL_ALIGNMENT_LEFT, 168, 11, Color("#8f8fa8"))

    # ── HP-полоса ──
    var hp_r := Rect2(196, 8, 150, 13)
    var hp_ratio := float(p.hp) / float(maxi(1, p.max_hp))
    var hp_col := Color("#58c95e") if hp_ratio > 0.5 \
            else (Color("#e0b040") if hp_ratio > 0.25 else Color("#e24b4a"))
    Sprites.draw_heart(self, Vector2(186, 15), 12.0, Color("#ff2b2b"))
    _bar(hp_r, hp_ratio, Color("#31121a"), hp_col, Color("#5a3040"))
    draw_string(font, Vector2(hp_r.position.x + 4, hp_r.position.y + 11),
                "%d/%d" % [p.hp, p.max_hp],
                HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f5f5ff"))

    # ── кринж (опыт до уровня) — полоса того же размера, что HP ──
    var xp_r := Rect2(196, 27, 150, 13)
    var xp_ratio := float(p.cringe) / float(maxi(1, p.next_level_cringe()))
    _bar(xp_r, xp_ratio, Color("#1a1230"), Color("#9b5cff"), Color("#40325f"))
    draw_string(font, Vector2(xp_r.position.x + 4, xp_r.position.y + 11),
                "кринж %d/%d" % [p.cringe, p.next_level_cringe()],
                HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e6dcf8"))

    # ── бурмолда (валюта) ──
    draw_circle(Vector2(376, 15), 7.0, Color("#c9a13c"))
    draw_circle(Vector2(376, 15), 5.0, Color("#f0c040"))
    draw_string(font, Vector2(388, 21), str(p.burmolda),
                HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f0c040"))
    draw_string(font, Vector2(388, 38), "бурмолда",
                HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#8f8fa8"))

    # ── свэг ──
    var sx := 468.0
    draw_string(font, Vector2(sx, 21), "★ %d" % p.swag,
                HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#35d6d6"))
    draw_string(font, Vector2(sx, 38), "свэг",
                HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#8f8fa8"))

    # ── подсказка управления (справа) ──
    draw_string(font, Vector2(524, 19), "стрелки — ход",
                HORIZONTAL_ALIGNMENT_LEFT, 112, 10, Color("#6a6a80"))
    draw_string(font, Vector2(524, 34), "ENTER — меню",
                HORIZONTAL_ALIGNMENT_LEFT, 112, 10, Color("#6a6a80"))

    # ── тост-сообщение под панелью ──
    if msg != "":
        var mw := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
        draw_rect(Rect2(4, H + 3, minf(mw + 14.0, 632.0), 17), Color(0, 0, 0, 0.72), true)
        draw_string(font, Vector2(10, H + 16), msg,
                    HORIZONTAL_ALIGNMENT_LEFT, 624, 12, Color("#9fe1cb"))
