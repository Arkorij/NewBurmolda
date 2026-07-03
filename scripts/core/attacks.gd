extends RefCounted
class_name Attacks
## Варианты атак в бою. Порт burmolda/attacks.py.
## available(player) строит меню БОЯ; execute(id, battle) выполняет приём.
## Доступность зависит от тира оружия, щита и выученных у NPC флагов (learn_*).

static func _wtier(p: Player) -> int:
    var it = Items.get_item(Items.equipment(p).get("weapon"))
    return int(it["tier"]) if it != null else -1


static func _has_shield(p: Player) -> bool:
    return Items.equipment(p).get("shield") != null


static func _fx(extra: Array) -> Array:
    return ["  " + " · ".join(extra)] if not extra.is_empty() else []


# ─── приёмы: fn(battle) -> Array[String] ───
static func cleave(b: Battle) -> Array:
    var base := b.attack_power() + _wtier(b.player) * 3 + randi_range(3, 9)
    var r: Array = b._hit(base)
    return ["⚔ РУБЯЩИЙ УДАР! %d урона" % r[0]] + _fx(r[1])


static func flurry(b: Battle) -> Array:
    var tot := 0
    for _i in range(3):
        var r: Array = b._hit(int(b.attack_power() * 0.5) + randi_range(1, 4))
        tot += int(r[0])
    return ["🌀 СВЭГ-ВИХРЬ: 3 удара, %d урона суммарно" % tot]


static func legend(b: Battle) -> Array:
    var base := int((b.attack_power() + _wtier(b.player) * 4) * 2.0)
    var r: Array = b._hit(base)
    return ["✦ ЛЕГЕНДАРНЫЙ РАЗРЕЗ! %d урона" % r[0]] + _fx(r[1])


static func shieldbash(b: Battle) -> Array:
    var base := int(b.attack_power() / 2.0) + randi_range(3, 7)
    var r: Array = b._hit(base)
    var stun := randf() < 0.4
    if stun:
        b.enemy_frozen = true
    return ["🛡 УДАР ЩИТОМ! %d урона%s" % [r[0], " · ❄ оглушён!" if stun else ""]] + _fx(r[1])


static func sigma_gaze(b: Battle) -> Array:
    var base := b.player.swag * 3 + b.player.level * 2 + randi_range(2, 8)
    var r: Array = b._hit(base)
    return ["👁 СИГМА-ВЗГЛЯД! %d урона (сила от свэга)" % r[0]] + _fx(r[1])


static func bogatyr(b: Battle) -> Array:
    # ×1.5 (не ×2): дешёвый приём без оружия не должен догонять легендарный меч
    if randf() < 0.7:
        var r: Array = b._hit(int(b.attack_power() * 1.5) + randi_range(6, 16))
        return ["💪 БОГАТЫРСКИЙ ЗАМАХ! %d урона" % r[0]] + _fx(r[1])
    return ["Замахнулся так широко, что промазал. 😵"]


static func ice_aria(b: Battle) -> Array:
    var r: Array = b._hit(b.attack_power() + randi_range(2, 6))
    b.enemy_frozen = true
    return ["🎵 ЛЕДЯНАЯ АРИЯ! %d урона · ❄ враг застыл!" % r[0]] + _fx(r[1])


static func crystal_volley(b: Battle) -> Array:
    var tot := 0
    for _i in range(4):
        var r: Array = b._hit(randi_range(3, 8))
        tot += int(r[0])
    return ["💎 КРИСТАЛЬНЫЙ ЗАЛП: 4 осколка, %d урона" % tot]


# ─── доступные приёмы (id + человекочитаемое имя) ───
static func available(p: Player) -> Array:
    var out: Array = [
        {"id": "basic", "name": "Бурмольнуть в лицо"},
        {"id": "roar", "name": "Сигма-рёв (риск)"},
    ]
    if _wtier(p) >= 1:
        out.append({"id": "cleave", "name": "Рубящий удар (оружие)"})
    if _wtier(p) >= 3:
        out.append({"id": "flurry", "name": "Свэг-вихрь (оружие т3+)"})
    if _wtier(p) >= 5:
        out.append({"id": "legend", "name": "Легендарный разрез (т5)"})
    if _has_shield(p):
        out.append({"id": "shieldbash", "name": "Удар щитом"})
    if p.flags.get("learn_sigma"):
        out.append({"id": "sigma_gaze", "name": "✦ Сигма-взгляд"})
    if p.flags.get("learn_bogatyr"):
        out.append({"id": "bogatyr", "name": "✦ Богатырский замах"})
    if p.flags.get("learn_aria"):
        out.append({"id": "ice_aria", "name": "✦ Ледяная ария"})
    if p.flags.get("learn_crystal"):
        out.append({"id": "crystal", "name": "✦ Кристальный залп"})
    return out


static func execute(id: String, b: Battle) -> Array:
    match id:
        "basic": return b.attack()
        "roar": return b.roar()
        "cleave": return cleave(b)
        "flurry": return flurry(b)
        "legend": return legend(b)
        "shieldbash": return shieldbash(b)
        "sigma_gaze": return sigma_gaze(b)
        "bogatyr": return bogatyr(b)
        "ice_aria": return ice_aria(b)
        "crystal": return crystal_volley(b)
    return b.attack()
