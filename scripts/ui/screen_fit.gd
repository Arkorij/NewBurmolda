extends Node
class_name ScreenFit
## Адаптация UI-экранов к ЛЮБОМУ соотношению сторон окна (stretch = expand):
## контент экрана свёрстан в базовой рамке 640x480 — ScreenFit центрует её в
## окне и (опционально) держит фоновый ColorRect на ВСЁ окно, чтобы по краям
## не было дыр. Использование: ScreenFit.attach(self, Color("#0a0a12")) в
## _ready сцены; сцены, рисующие фон сами в _draw, зовут attach(self) без
## цвета и ScreenFit.backdrop(self, цвет) первым делом в _draw.

const BASE := Vector2(640, 480)      # базовая рамка вёрстки всех экранов

var root: Control
var bg: ColorRect = null


static func attach(r: Control, bg_col := Color(0, 0, 0, 0)) -> ScreenFit:
    var f := ScreenFit.new()
    f.root = r
    if bg_col.a > 0.0:
        f.bg = ColorRect.new()
        f.bg.color = bg_col
        r.add_child(f.bg)
        r.move_child(f.bg, 0)
    r.add_child(f)
    return f


static func offset(ctrl: Control) -> Vector2:
    ## Смещение центрированной рамки BASE в текущем окне (для ручных сдвигов —
    ## например, тряска боевой арены должна трястись ВОКРУГ этого смещения).
    return ((ctrl.get_viewport_rect().size - BASE) * 0.5).floor()


static func backdrop(ctrl: Control, col: Color) -> void:
    ## Залить ВСЁ окно фоном из _draw сцены (координаты локальные, поэтому
    ## компенсируем сдвиг центрирования).
    ctrl.draw_rect(Rect2(-ctrl.position, ctrl.get_viewport_rect().size), col, true)


func _ready() -> void:
    _refit()
    get_viewport().size_changed.connect(_refit)


func _refit() -> void:
    var vs: Vector2 = root.get_viewport_rect().size
    root.position = ((vs - BASE) * 0.5).floor()
    if bg != null:
        bg.position = -root.position
        bg.size = vs
