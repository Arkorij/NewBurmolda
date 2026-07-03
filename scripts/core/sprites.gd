extends RefCounted
class_name Sprites
## Пиксель-арт из оригинала (pygame): 16x16 сетки + палитра из DataDB.
## Рисуется примитивами прямо в _draw любого CanvasItem (nearest-neighbour).

static func mob_key(name: String) -> String:
    var low := str(name).to_lower()
    for pair in DataDB.sprite_keywords:
        if pair[0] in low:
            return pair[1]
    return "mob"


static func npc_key(kind: String) -> String:
    return DataDB.sprite_npc_override.get(kind, kind)


static func has(key: String) -> bool:
    return DataDB.sprite_grids.has(key)


static func draw_grid(ci: CanvasItem, rect: Rect2, key: String) -> void:
    var grid = DataDB.sprite_grids.get(key)
    if grid == null:
        grid = DataDB.sprite_grids.get("mob")
    if grid == null:
        ci.draw_rect(rect, Color("#8a5cff"), true)
        return
    var rows: int = grid.size()
    var cols: int = String(grid[0]).length()
    var ps: int = int(min(rect.size.x / float(cols), rect.size.y / float(rows)))
    if ps < 1:
        ps = 1
    var ox: float = rect.position.x + (rect.size.x - ps * cols) * 0.5
    var oy: float = rect.position.y + (rect.size.y - ps * rows) * 0.5
    for y in rows:
        var row: String = grid[y]
        for x in row.length():
            var ch := row[x]
            if ch == "." or ch == " ":
                continue
            var col = DataDB.sprite_pal.get(ch)
            if col != null:
                ci.draw_rect(Rect2(ox + x * ps, oy + y * ps, ps, ps), col, true)


static func draw_mob(ci: CanvasItem, rect: Rect2, name: String) -> void:
    draw_grid(ci, rect, mob_key(name))


static func draw_npc(ci: CanvasItem, rect: Rect2, kind: String) -> void:
    draw_grid(ci, rect, npc_key(kind))


static func draw_heart(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
    ## Сердечко-«душа» (Undertale-soul) вместо квадрата.
    var r := s * 0.30
    ci.draw_circle(c + Vector2(-r * 0.9, -r * 0.55), r, color)
    ci.draw_circle(c + Vector2(r * 0.9, -r * 0.55), r, color)
    ci.draw_colored_polygon(PackedVector2Array([
        c + Vector2(-r * 1.78, -r * 0.12),
        c + Vector2(r * 1.78, -r * 0.12),
        c + Vector2(0, s * 0.62)]), color)
