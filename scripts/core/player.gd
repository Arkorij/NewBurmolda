extends RefCounted
class_name Player
## Состояние игрока-головастика. Порт burmolda/player.py (движко-независимая логика).

var pname: String = "Безымянный головастик"
var burmolda: int = 10
var cringe: int = 0
var swag: int = 1
var level: int = 1
var hp: int = 30
var max_hp: int = 30
var inventory: Dictionary = {}          # item -> qty
var map_pos = null                      # Vector2i или null
var current_loc = null                  # id локации
var reputation: int = 0
var quests: Dictionary = {}
var equipment: Dictionary = {
    "weapon": null, "armor": null, "shield": null,
    "trinket": null, "ring1": null, "ring2": null,
}
var story_chapter: int = 0
var flags: Dictionary = {}
var stats: Dictionary = {
    "burmold_count": 0, "burmolzh_count": 0, "battles_won": 0, "events_seen": 0,
}


func _init(name := "Безымянный головастик") -> void:
    pname = name
    var b: Dictionary = DataDB.balance
    burmolda = int(b.get("START_BURMOLDA", 10))
    cringe = int(b.get("START_CRINGE", 0))
    swag = int(b.get("START_SWAG", 1))
    level = int(b.get("START_LEVEL", 1))


# ─── ПРОКАЧКА ───
func next_level_cringe() -> int:
    return level * int(DataDB.balance.get("LEVEL_STEP", 100))


func rank() -> String:
    var ranks: Array = DataDB.balance.get("RANKS", [])
    if ranks.is_empty():
        return "Головастик"
    return ranks[min(level - 1, ranks.size() - 1)]


func add_cringe(amount: int) -> Array:
    ## Возвращает список набранных уровней (для сообщений о левелапе).
    cringe += amount
    var ups: Array = []
    while cringe >= next_level_cringe():
        cringe -= next_level_cringe()
        level += 1
        swag += 1
        max_hp += 8
        hp = max_hp
        ups.append(level)
    return ups


# ─── ИНВЕНТАРЬ ───
func add_item(item: String, qty := 1) -> void:
    inventory[item] = int(inventory.get(item, 0)) + qty


func remove_item(item: String, qty := 1) -> bool:
    if int(inventory.get(item, 0)) >= qty:
        inventory[item] = int(inventory[item]) - qty
        if inventory[item] <= 0:
            inventory.erase(item)
        return true
    return false


func has_item(item) -> bool:
    return int(inventory.get(item, 0)) > 0


# ─── HP ───
func heal(amount: int) -> void:
    hp = min(max_hp, hp + amount)


func damage(amount: int) -> bool:
    hp = max(0, hp - amount)
    return hp <= 0


func is_alive() -> bool:
    return hp > 0


# ─── СЕРИАЛИЗАЦИЯ ───
func to_dict() -> Dictionary:
    return {
        "name": pname, "burmolda": burmolda, "cringe": cringe, "swag": swag,
        "level": level, "hp": hp, "max_hp": max_hp, "inventory": inventory,
        "story_chapter": story_chapter, "map_pos": map_pos, "current_loc": current_loc,
        "reputation": reputation, "quests": quests, "equipment": equipment,
        "flags": flags, "stats": stats,
    }


static func from_dict(data: Dictionary) -> Player:
    var p := Player.new(data.get("name", "Головастик"))
    p.burmolda = int(data.get("burmolda", 10))
    p.cringe = int(data.get("cringe", 0))
    p.swag = int(data.get("swag", 1))
    p.level = int(data.get("level", 1))
    p.hp = int(data.get("hp", 30))
    p.max_hp = int(data.get("max_hp", 30))
    p.inventory = data.get("inventory", {})
    p.map_pos = data.get("map_pos")
    p.current_loc = data.get("current_loc")
    p.reputation = int(data.get("reputation", 0))
    p.quests = data.get("quests", {})
    var eqd = data.get("equipment")
    if eqd is Dictionary:
        p.equipment.merge(eqd, true)
    p.story_chapter = int(data.get("story_chapter", 0))
    p.flags.merge(data.get("flags", {}), true)
    p.stats.merge(data.get("stats", {}), true)
    return p
