extends RefCounted
class_name Econ
## Экономика ресурсов: добыл на ноде → продал торговцу. Порт burmolda/resources.py.

static func is_resource(item) -> bool:
    return DataDB.resources.has(item)


static func price(item) -> int:
    return int(DataDB.resources.get(item, 0))


static func resource_items(player: Player) -> Array:
    var out: Array = []
    for it in player.inventory:
        if is_resource(it):
            out.append([it, int(player.inventory[it])])
    return out


static func total_value(player: Player) -> int:
    var t := 0
    for pair in resource_items(player):
        t += price(pair[0]) * int(pair[1])
    return t


static func sell_all(player: Player, premium := 1.0) -> Array:
    ## -> [total, count, lines]. premium — множитель цены (щедрые скупщики).
    ## Вещи под активную квестовую сдачу (Quests.fetch_reserved, например ОЗУ
    ## для Попова) придерживаются — скупщик их не заберёт, пока квест не закрыт.
    var items := resource_items(player)
    var reserved := Quests.fetch_reserved(player)
    var total := 0
    var count := 0
    var lines: Array = []
    var held: Array = []
    for pair in items:
        var it = pair[0]
        if reserved.has(it):
            held.append(str(it))
            continue
        var q := int(pair[1])
        var val := int(price(it) * q * premium)
        total += val
        count += q
        player.remove_item(it, q)
        lines.append("  %s x%d → %d бурмолды" % [it, q, val])
    if count == 0 and held.is_empty():
        return [0, 0, ["Нет ресурсов на продажу. Иди добудь чего-нибудь."]]
    if count > 0:
        player.burmolda += total
        lines.append("ИТОГО: +%d бурмолды за %d шт." % [total, count])
    else:
        lines.append("Продавать нечего — всё остальное придержано.")
    if not held.is_empty():
        lines.append("🔒 придержано для квеста: %s" % ", ".join(PackedStringArray(held)))
    return [total, count, lines]
