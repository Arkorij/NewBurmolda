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


# особые вещи (трофеи/дары) со своим спрайтом — по подстроке имени
const _SPECIAL_SPRITES := [
    ["череп", "item_skull"], ["вентилятор", "ventil"], ["пропуск", "item_pass"],
    ["отросток", "item_sprout"], ["лиан", "item_sprout"],
    ["погремушка", "item_rattle"], ["ямполь", "item_charm_yampol"],
]

# ключевые слова ресурсов → спрайт добычи (порядок важен: «слиток» раньше
# «железо»-руды, «железо» раньше «железа́»-органа → goo)
const _RES_SPRITES := [
    ["озу", "res_ram"], ["слиток", "res_ingot"],
    ["железо", "res_ore"], ["руд", "res_ore"],
    ["угол", "res_coal"], ["пепел", "res_ash"], ["пыль", "res_ash"],
    ["рыб", "res_fish"], ["карп", "res_fish"], ["угорь", "res_fish"],
    ["цветок", "res_flower"],
    ["трав", "res_herb"], ["корешок", "res_herb"], ["спорынья", "res_herb"],
    ["крошка", "res_ice"],
    ["кристалл", "res_gem"], ["самоцвет", "res_gem"],
    ["кость", "res_bone"], ["панцир", "res_bone"],
    ["перо", "res_feather"], ["шерст", "res_fur"],
    ["сердце", "res_heart"],
]


static func item_key(inv_key: String) -> String:
    ## Ключ 16x16-спрайта для ЛЮБОГО ключа инвентаря: снаряжение (id из
    ## DataDB.items) — вариант по слоту и ТИРУ (своя сетка на каждый тир),
    ## кольца — по ЭФФЕКТУ (цвет камня); ресурсы и особые вещи — по ключевому
    ## слову имени; зелья/еда — свои; остальное — «квестовый свиток».
    var low := inv_key.to_lower()
    var it = DataDB.items.get(inv_key)
    if it != null:
        var tier := int(it.get("tier", 0))
        match str(it.get("slot", "")):
            "weapon":
                return "item_sword_t%d" % clampi(tier, 0, 5)
            "armor":
                return "item_armor_t%d" % clampi(tier, 0, 4)
            "shield":
                return "item_shield_t%d" % clampi(tier, 0, 4)
            "trinket":
                for pair in _SPECIAL_SPRITES:   # квестовые обереги — свои спрайты
                    if pair[0] in low:
                        return pair[1]
                return "item_trinket_t%d" % clampi(tier, 0, 4)
            "ring":
                var rk := "item_ring_%s" % str(it.get("effect", "power"))
                return rk if has(rk) else "item_ring_power"
        return "item_quest"
    if inv_key.begins_with("зелье"):
        return "item_potion_evade" if "уворот" in low else "item_potion_swag"
    for f in DataDB.food:
        if str(f[0]) == inv_key:
            if "шаурма" in low:
                return "item_food_shawarma"
            return "item_food_steak" if "стейк" in low else "item_food_meat"
    if DataDB.resources.has(inv_key):
        for pair in _RES_SPRITES:
            if pair[0] in low:
                return pair[1]
        return "res_goo"
    for pair in _SPECIAL_SPRITES:
        if pair[0] in low:
            return pair[1]
    return "item_quest"


static func draw_item(ci: CanvasItem, rect: Rect2, inv_key: String) -> void:
    draw_grid(ci, rect, item_key(inv_key))


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
