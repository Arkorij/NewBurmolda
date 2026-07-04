extends Control
## Титульный экран: название, подзаголовок, «ENTER — новая игра / C — продолжить».

var font: Font


func _ready() -> void:
    font = ThemeDB.fallback_font
    ScreenFit.attach(self, Color("#07100a"))   # фон на всё окно, контент по центру
    _big(DataDB.balance.get("GAME_TITLE", "БУРМОЛДА"), 46, 150, Color("#7CFC5A"))
    _big(DataDB.balance.get("GAME_SUBTITLE", "самый свэг кринж"), 18, 210, Color("#8fe1cb"))
    _big("ENTER — новая игра", 18, 300, Color("#f0f0ff"))
    if GameState.has_save():
        _big("C — продолжить", 16, 330, Color("#b0b0c0"))
    _big("перенос pygame → Godot 4.7 · вертикальный срез", 12, 440, Color("#50506a"))
    set_process_unhandled_input(true)


func _big(txt: String, sz: int, y: int, col: Color) -> void:
    var l := Label.new()
    l.text = txt
    l.position = Vector2(0, y)
    l.size = Vector2(640, 40)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", sz)
    l.add_theme_color_override("font_color", col)
    add_child(l)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        GameState.new_game("Головастик")
        get_tree().change_scene_to_file("res://scenes/Overworld.tscn")
    elif event is InputEventKey and event.pressed and event.keycode == KEY_C:
        if GameState.load_game():
            get_tree().change_scene_to_file("res://scenes/Overworld.tscn")
