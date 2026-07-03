extends RefCounted
class_name NPCEffects
## Реализация эффектов NPC по effect-ID (сидер выгрузил их из Python-функций).
## Порт burmolda/pygame_app/npc_data.py (эффекты покупок/кастомов).

static func gain_swag(p: Player) -> Array:
    p.swag += 2
    return ["Урок сигма-бурмольжа. +2 свэга 😎"]


static func bless_hp(p: Player) -> Array:
    p.max_hp += 12
    p.heal(12)
    return ["Благословение болота: +12 к макс. HP навсегда 💚"]


static func heal_full(p: Player) -> Array:
    var healed := p.max_hp - p.hp
    p.heal(p.max_hp)
    p.flags["drank_dew"] = true
    return ["Роса исцеляет: +%d HP (полный бак) 💧" % healed]


static func sell_potion(p: Player) -> Array:
    p.add_item("зелье свэга")
    return ["🎁 Получено: зелье свэга (выпей в бою для буста)"]


static func evade_potion(p: Player) -> Array:
    p.add_item("зелье уворота")
    return ["🎁 Получено: зелье уворота (в бою: +35% шанс пропустить пули)"]


static func feast(p: Player) -> Array:
    var healed := p.max_hp - p.hp
    p.heal(p.max_hp)
    return ["Ты наелся до отвала! +%d HP (полный бак) 🍗" % healed]


static func beef_up(p: Player) -> Array:
    p.max_hp += 8
    p.heal(8)
    return ["Стейк из топляка качает тушку: +8 к макс. HP 💪"]


static func give_item(p: Player, item: String) -> Array:
    p.add_item(item)
    return ["🎁 Получено: %s" % item]


static func give_food(p: Player, food: String) -> Array:
    p.add_item(food)
    return ["🍖 Куплено: %s (съешь в бою для лечения)" % food]


static func ladushki(p: Player) -> Array:
    if p.burmolda < 10:
        return ["Нет даже 10 бурмолды? Позорище, — смеётся она."]
    p.burmolda -= 10
    if randf() < 0.5:
        p.burmolda += 25
        return ["Ты выиграл в ладушки! +25 бурмолды 🖐️"]
    return ["Малая тебя переладушила. Проигрыш! 😼"]


static func vozduhan_hint(p: Player) -> Array:
    p.add_cringe(8)
    var lies := DataDB.phrase("VOZDUHAN_LIES")
    var lie: String = lies[randi() % lies.size()] if not lies.is_empty() else "Болото сухое, зуб даю."
    return ["Воздухан наклоняется и врёт тебе на ухо:", lie,
            "(не верь ни единому слову, бро)"]


static func vozduhan_bet(p: Player) -> Array:
    if p.burmolda < 15:
        return ["Нет 15 бурмолды на спор. «Так я и думал», — врёт он."]
    p.burmolda -= 15
    if randf() < 0.8:
        p.burmolda += 35
        return ["Ты поймал его на вранье! +35 бурмолды 😎"]
    return ["Каким-то чудом он наврал убедительнее. Проигрыш!"]


# ─── диспетчер по effect-ID ───
static func apply(p: Player, effect: String, arg = null) -> Array:
    match effect:
        "gain_swag": return gain_swag(p)
        "bless_hp": return bless_hp(p)
        "heal_full": return heal_full(p)
        "sell_potion": return sell_potion(p)
        "evade_potion": return evade_potion(p)
        "feast": return feast(p)
        "beef_up": return beef_up(p)
        "give_item": return give_item(p, str(arg))
        "give_food": return give_food(p, str(arg))
        "ladushki": return ladushki(p)
        "vozduhan_hint": return vozduhan_hint(p)
        "vozduhan_bet": return vozduhan_bet(p)
    return ["...ничего не произошло."]


static func buy(p: Player, cost: int, effect: String, arg = null) -> Array:
    if p.burmolda >= cost:
        p.burmolda -= cost
        return ["💸 -%d бурмолды (осталось %d)" % [cost, p.burmolda]] + apply(p, effect, arg)
    return ["Не хватает бурмолды, нищеброд болотный. 🪙"]
