extends RefCounted
class_name Quests
## Лёгкие квесты: взять у NPC → выполнить (убить N мобов / победить босса) → сдать.
## Порт burmolda/quests.py. Определения — DataDB.quests. Состояние — player.quests.

const GIVER_NAMES := {
    "yampol": "Ямполь", "shest": "Шестухины", "tusha": "Туши", "popov": "Попова",
    "yampol_jr": "Ямполь Мл.", "vozduhan": "Воздухана", "dima": "Димы",
    "ded": "Деда", "baba": "Бабы", "fish_npc": "Рыбы",
    "teplichnaya": "Тепличной (если найдёшь)",
}


static func _st(player: Player, qid):
    return player.quests.get(qid)


static func is_done(player: Player, qid) -> bool:
    var s = _st(player, qid)
    return s != null and s.get("status") == "done"


static func givable(player: Player, kind: String) -> Array:
    var out: Array = []
    for qid in DataDB.quests:
        var qq: Dictionary = DataDB.quests[qid]
        if qq.get("giver") != kind or player.quests.has(qid):
            continue
        var req = qq.get("requires")
        if req != null and not is_done(player, req):
            continue
        out.append(qid)
    return out


static func ready(player: Player, kind: String) -> Array:
    var out: Array = []
    for qid in DataDB.quests:
        var qq: Dictionary = DataDB.quests[qid]
        var s = _st(player, qid)
        if qq.get("turnin") == kind and s != null and s.get("status") == "ready":
            out.append(qid)
    return out


static func active(player: Player) -> Array:
    var out: Array = []
    for qid in player.quests:
        if player.quests[qid].get("status") in ["active", "ready"]:
            out.append(qid)
    return out


static func start(player: Player, qid: String) -> Array:
    var qq: Dictionary = DataDB.quests[qid]
    player.quests[qid] = {"status": "active", "progress": 0}
    refresh(player)
    return ["📜 Взято задание: «%s»" % qq["name"], qq["desc"]]


static func on_kill(player: Player, mob_name: String) -> Array:
    var low := str(mob_name).to_lower()
    var msgs: Array = []
    for qid in player.quests.keys():
        var s: Dictionary = player.quests[qid]
        var qq: Dictionary = DataDB.quests[qid]
        if s.get("status") != "active" or qq.get("type") != "kill":
            continue
        var hit := false
        for k in qq.get("keys", []):
            if k in low:
                hit = true
                break
        if hit:
            s["progress"] = int(s.get("progress", 0)) + 1
            if int(s["progress"]) >= int(qq["count"]):
                s["status"] = "ready"
                msgs.append("✅ Задание «%s» готово — сдай у %s!" % [qq["name"], giver_name(qq["turnin"])])
            else:
                msgs.append("📜 %s: %d/%d" % [qq["name"], int(s["progress"]), int(qq["count"])])
    return msgs


static func refresh(player: Player) -> void:
    for qid in DataDB.quests:
        var qq: Dictionary = DataDB.quests[qid]
        var s = _st(player, qid)
        if s == null or s.get("status") != "active" or qq.get("type") != "boss":
            continue
        if player.flags.get(qq.get("boss")):
            s["status"] = "ready"


static func turn_in(player: Player, qid: String) -> Array:
    var s = _st(player, qid)
    var qq: Dictionary = DataDB.quests[qid]
    if s == null or s.get("status") != "ready":
        return ["Это задание ещё не готово."]
    s["status"] = "done"
    var rw: Dictionary = qq.get("reward", {})
    var msgs: Array = ["🏆 Задание «%s» выполнено!" % qq["name"]]
    if rw.get("burmolda"):
        player.burmolda += int(rw["burmolda"])
        msgs.append("+%d бурмолды 💰" % int(rw["burmolda"]))
    if rw.get("cringe"):
        player.add_cringe(int(rw["cringe"]))
        msgs.append("+%d кринж-опыта 🤮" % int(rw["cringe"]))
    if rw.get("rep"):
        player.reputation += int(rw["rep"])
        msgs.append("+%d репутации 🤝" % int(rw["rep"]))
    if rw.get("item"):
        player.add_item(rw["item"])
        # если награда — id снаряжения, показываем человеческое имя
        var it = DataDB.items.get(rw["item"])
        msgs.append("🎁 Предмет: %s" % (it["name"] if it != null else rw["item"]))
    return msgs


static func progress_str(player: Player, qid: String) -> String:
    var s = _st(player, qid)
    var qq: Dictionary = DataDB.quests[qid]
    if s == null:
        return ""
    match s.get("status"):
        "done": return "✔ выполнено"
        "ready": return "✅ готово к сдаче"
    if qq.get("type") == "kill":
        return "%d/%d" % [int(s.get("progress", 0)), int(qq["count"])]
    return "в процессе"


static func main_goal(player: Player) -> String:
    var f: Dictionary = player.flags
    # «пройдена» только когда повержены ОБА сюжетных босса — если игрок
    # ухитрился завалить Калитина раньше Цизи, цель честно отправляет назад
    if (f.get("kalitin_defeated") or f.get("boss_defeated")) and f.get("tsizi_defeated"):
        return "★ Игра пройдена! Ты — Верховная Бурмолда болота."
    if f.get("kalitin_defeated") and not f.get("tsizi_defeated"):
        return "Калитин пал... но дух Цизи всё ещё дует. Заверши начатое (буква Z)."
    if not f.get("tsizi_defeated"):
        if player.level < 3:
            return "Цель: прокачайся (добывай, бей мобов) и одолей Духа Цизи."
        return "Цель: найди и одолей Духа Цизи (буква Z на карте)."
    return "Цель: одолей Калитина (буква K на карте) — это финал."


static func giver_name(kind) -> String:
    return GIVER_NAMES.get(kind, kind)
