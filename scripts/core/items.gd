extends RefCounted
class_name Items
## Логика экипировки/баффов/колец. Данные предметов — в DataDB.items (из JSON).
## Порт burmolda/items.py (кроме генерации: она сделана сидером в JSON).

const EQUIP_SLOTS := ["weapon", "armor", "shield", "trinket", "ring1", "ring2"]


static func get_item(id) -> Variant:
    if id == null:
        return null
    return DataDB.items.get(id)


static func equipment(player: Player) -> Dictionary:
    for s in EQUIP_SLOTS:
        if not player.equipment.has(s):
            player.equipment[s] = null
    return player.equipment


static func ring_effects(player: Player) -> Dictionary:
    ## {effect: magnitude} с надетых колец (ring1/ring2).
    var eff: Dictionary = {}
    var eq := equipment(player)
    for slot in ["ring1", "ring2"]:
        var it = get_item(eq.get(slot))
        if it != null and it.has("effect"):
            var e = it["effect"]
            eff[e] = max(int(eff.get(e, 0)), int(it.get("mag", 1)))
    return eff


static func total_buffs(player: Player) -> Dictionary:
    var total := {"atk": 0, "def": 0, "hp": 0, "swag": 0, "crit": 0, "block": 0}
    for id in equipment(player).values():
        var it = get_item(id)
        if it != null:
            for k in it.get("buffs", {}):
                total[k] = int(total.get(k, 0)) + int(it["buffs"][k])
    return total


static func _apply_hp(player: Player, id, sign: int) -> void:
    var it = get_item(id)
    if it == null:
        return
    var hp := int(it.get("buffs", {}).get("hp", 0))
    if hp == 0:
        return
    player.max_hp = max(1, player.max_hp + sign * hp)
    if sign > 0:
        player.hp += hp
    player.hp = clamp(player.hp, 1, player.max_hp)


static func equip(player: Player, id) -> Array:
    var it = get_item(id)
    if it == null:
        return ["Это не экипировка."]
    if not player.has_item(id):
        return ["Такого предмета нет в сумке."]
    var eq := equipment(player)
    var slot: String = it["slot"]
    if slot == "ring":                        # два слота под кольца
        if eq.get("ring1") == null:
            slot = "ring1"
        elif eq.get("ring2") == null:
            slot = "ring2"
        else:
            slot = "ring1"
    var old = eq[slot]
    player.remove_item(id)
    if old != null:
        _apply_hp(player, old, -1)
        player.add_item(old)
    eq[slot] = id
    _apply_hp(player, id, 1)
    var msg := ["⚔ Надето: %s (%s)" % [it["name"], buffs_str(id)]]
    if old != null:
        msg.append("  снято: %s" % get_item(old)["name"])
    return msg


static func unequip(player: Player, slot: String) -> Array:
    var eq := equipment(player)
    var id = eq.get(slot)
    if id == null:
        return ["Слот пуст."]
    _apply_hp(player, id, -1)
    eq[slot] = null
    player.add_item(id)
    return ["Снято: %s" % get_item(id)["name"]]


static func buffs_str(id) -> String:
    var it = get_item(id)
    if it == null:
        return ""
    if it.has("effect"):                      # кольцо — эффект вместо статов
        var re: Dictionary = DataDB.ring_effects.get(it["effect"], {})
        return "%s: %s" % [re.get("name", it["effect"]), re.get("desc", "")]
    var parts: Array = []
    for k in it.get("buffs", {}):
        parts.append("%s +%d" % [DataDB.stat_names.get(k, k), int(it["buffs"][k])])
    return ", ".join(parts)


static func random_item(max_tier := 5, slot = null) -> Variant:
    var pool: Array = []
    for it in DataDB.items.values():
        if int(it["tier"]) <= max_tier and (slot == null or it["slot"] == slot):
            pool.append(it["id"])
    if pool.is_empty():
        return null
    return pool[randi() % pool.size()]


static func owned_gear(player: Player) -> Array:
    var out: Array = []
    for id in player.inventory:
        if DataDB.items.has(id):
            out.append([id, int(player.inventory[id])])
    return out
