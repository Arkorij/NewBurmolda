extends RefCounted
class_name OverworldDebug
## Дебаг-инструменты надмира: чит-меню (F1) и вызов любого боя (F2). Вынесены
## из overworld.gd, чтобы не раздувать главный файл сцены (тот же приём, что
## Sprites/BulletKit: модуль со static-функциями, первым аргументом принимает
## `ow` — экземпляр Overworld — и работает с его полями/методами напрямую).
##
## Читы работают ВСЕГДА, но HUD о них не рассказывает — секретные клавиши.
## Победа в дебаг-бою резолвится как обычный бой (лут/флаги) — отладочный
## инструмент, не более того.


# ─────────────── F1: чит-меню ───────────────
static func open_cheats(ow) -> void:
    ow.busy = true
    var panel := _panel("🐸 ЧИТ-МЕНЮ (дебаг)")
    var m := SoulMenu.new()
    m.position = Vector2(70, 96)
    m.line_h = 22
    panel.add_child(m)
    m.setup(["+1 уровень", "+5 уровней", "+1000 бурмолды", "Полный хил",
             "Легендарный сет (надеть)", "Выучить все приёмы",
             "Все кольца т5 в сумку", "Убить мобов на карте",
             "Телепорт в локацию →", "Закрыть"])
    m.chosen.connect(Callable(OverworldDebug, "_on_cheat").bind(ow, panel))
    m.cancelled.connect(Callable(ow, "_close_overlay").bind(panel))
    ow.overlay.add_child(panel)


static func _on_cheat(i: int, ow, panel: Node) -> void:
    var p := GameState.player
    match i:
        0:
            p.add_cringe(p.next_level_cringe())
            _cheat_done(ow, panel, "⬆ уровень %d" % p.level)
        1:
            for _k in range(5):
                p.add_cringe(p.next_level_cringe())
            _cheat_done(ow, panel, "⬆ уровень %d" % p.level)
        2:
            p.burmolda += 1000
            _cheat_done(ow, panel, "💰 +1000 (всего %d)" % p.burmolda)
        3:
            p.hp = p.max_hp
            _cheat_done(ow, panel, "💚 полный хил")
        4:
            for id in ["weapon_0_5", "armor_0_4", "shield_0_4", "trinket_0_4",
                       "ring_power_5", "ring_freeze_5"]:
                p.add_item(id)
                Items.equip(p, id)
            _cheat_done(ow, panel, "⚔ легендарный сет надет")
        5:
            for f in ["learn_sigma", "learn_bogatyr", "learn_aria", "learn_crystal"]:
                p.flags[f] = true
            _cheat_done(ow, panel, "✦ все приёмы выучены")
        6:
            for eff in ["lifesteal", "power", "crit", "poison", "freeze", "thorns"]:
                p.add_item("ring_%s_5" % eff)
            _cheat_done(ow, panel, "💍 6 колец т5 в сумке")
        7:
            ow.mobs = []
            _cheat_done(ow, panel, "💀 мобы зачищены")
        8:
            open_teleport(ow, panel)
        9:
            ow._close_overlay(panel)


static func _cheat_done(ow, panel: Node, msg: String) -> void:
    panel.queue_free()
    ow._flash_close("✔ ЧИТ: " + msg)
    ow.queue_redraw()


static func open_teleport(ow, old_panel: Node) -> void:
    old_panel.queue_free()
    var panel := _panel("🌀 ТЕЛЕПОРТ (гейт уровня игнорируется)")
    var m := SoulMenu.new()
    m.position = Vector2(70, 84)
    m.line_h = 11
    m.font_size = 10
    panel.add_child(m)
    var ids: Array = DataDB.loc_index.get("order", [])
    var labels: Array = []
    for id in ids:
        var L: Dictionary = DataDB.locations[id]
        labels.append("%s  (ур.%d, опасн.%d)" % [L.get("name", id),
                      int(L.get("min_level", 1)), int(L.get("danger", 0))])
    m.setup(labels)
    m.chosen.connect(func(i: int):
        panel.queue_free()
        ow.busy = false
        ow.load_location(ids[i])
        ow._flash("✔ ЧИТ: телепорт → %s" % DataDB.locations[ids[i]].get("name", "")))
    m.cancelled.connect(Callable(ow, "_close_overlay").bind(panel))
    ow.overlay.add_child(panel)


# ─────────────── F2: дебаг-меню боёв ───────────────
static func open_debug_battles(ow) -> void:
    ## Вызвать любой бой — каждого босса (мировые + Пекло), случайного/слабого/
    ## жёсткого моба.
    ow.busy = true
    var panel := _panel("⚔ ДЕБАГ-БОЙ (F2) — вызвать любой бой")
    var m := SoulMenu.new()
    m.position = Vector2(70, 90)
    m.line_h = 20
    panel.add_child(m)
    m.setup([
        "Босс: Калитин", "Босс: Цизи", "Босс: Жижа",
        "Босс Пекла: Надзиратель", "Босс Пекла: Магистр", "Босс Пекла: ТМ",
        "Моб: случайный (этой локации)", "Моб: слабый (комар)",
        "Моб: жёсткий (danger 9)", "Закрыть"])
    m.chosen.connect(Callable(OverworldDebug, "_on_debug_battle").bind(ow, panel))
    m.cancelled.connect(Callable(ow, "_close_overlay").bind(panel))
    ow.overlay.add_child(panel)


static func _on_debug_battle(i: int, ow, panel: Node) -> void:
    match i:
        0: _debug_fight(ow, null, "kalitin", 5, "hell")
        1: _debug_fight(ow, null, "tsizi", 5, "ice")
        2: _debug_fight(ow, null, "zhizha", 5, "swamp")
        3: _debug_fight(ow, ["Надзиратель Пекла", 125, 13], "overseer", 6, "hell")
        4: _debug_fight(ow, ["Магистр Пекла", 200, 15], "pekl_master", 8, "hell")
        5: _debug_fight(ow, ["ТМ", 360, 19], "tm", 10, "hell")
        6:
            var mons: Array = ow.loc.get("monsters", [])
            var e = mons[randi() % mons.size()] if not mons.is_empty() else ["Тестовый Моб", 30, 5]
            _debug_fight(ow, [e[0], int(e[1]), int(e[2])], null,
                         int(ow.loc.get("danger", 1)), str(ow.loc.get("biome", "")))
        7: _debug_fight(ow, ["🦟 Комар", 14, 3], null, 1, "")
        8: _debug_fight(ow, ["👹 Топляк-Утопленник", 44, 9], null, 9, "wastes")
        9: ow._close_overlay(panel)
    if i != 9:
        panel.queue_free()


static func _debug_fight(ow, enemy_arr, bkey, dng: int, bio: String) -> void:
    ow.busy = true
    var b = load("res://scenes/Battle.tscn").instantiate()
    if enemy_arr != null:
        b.enemy = enemy_arr
    b.boss_key = bkey
    b.danger = dng
    b.biome = bio
    b.battle_over.connect(Callable(ow, "_close_battle").bind(b))
    ow.overlay.add_child(b)


# ─────────────── общий UI-хелпер (полупрозрачная панель + заголовок) ───────────────
static func _panel(title_text: String) -> Control:
    var panel := Control.new()
    ScreenFit.attach(panel, Color(0, 0, 0, 0.8))    # затемнение на всё окно
    var title := Label.new()
    title.text = title_text
    title.position = Vector2(70, 52)
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color("#7CFC5A"))
    panel.add_child(title)
    return panel
