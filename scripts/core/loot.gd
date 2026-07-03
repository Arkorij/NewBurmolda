extends RefCounted
class_name Loot
## Трофеи после боя: ресурсы (по опасности) + шанс на снаряжение.
## Дух burmolda/loot.py: чем опаснее локация/босс — тем лучше дроп.

const _COMMON := ["мятая кость", "клок шерсти-кринж", "осколок панциря", "костяная пыль"]
const _UNCOMMON := ["ядовитая железа", "перо стервятника", "ледяная крошка",
                    "тёмный кристалл-кринж"]


static func grant(player: Player, danger: int, is_boss := false) -> Array:
    var lines: Array = []
    if randf() < 0.85:
        var pool: Array = _UNCOMMON if (danger >= 3 and randf() < 0.5) else _COMMON
        var res: String = pool[randi() % pool.size()]
        player.add_item(res)
        lines.append("🎒 добыто: %s" % res)
    # снаряжение: в харде — чаще и круче; с босса — гарантированно и на тир выше
    var gear_chance := 0.15 + danger * 0.04 + (1.0 if is_boss else 0.0)
    if randf() < gear_chance:
        var max_tier: int = clamp(int(danger / 2.0), 0, 5)
        var min_tier: int = clamp(int(danger / 3.0), 0, 4)
        if is_boss:
            max_tier = min(5, max_tier + 1)
            min_tier = min(4, min_tier + 1)
        var gid = _roll_gear(min_tier, max_tier)
        if gid != null:
            player.add_item(gid)
            lines.append("✨ выпало снаряжение: %s" % Items.get_item(gid)["name"])
    if lines.is_empty():
        lines.append("С этого — ни шерсти, ни бурмолды.")
    return lines


static func _roll_gear(min_tier: int, max_tier: int) -> Variant:
    ## Случайный предмет в коридоре тиров — в харде мусор не сыпется.
    var pool: Array = []
    for it in DataDB.items.values():
        if int(it["tier"]) >= min_tier and int(it["tier"]) <= max_tier:
            pool.append(it["id"])
    if pool.is_empty():
        return Items.random_item(max_tier)
    return pool[randi() % pool.size()]
