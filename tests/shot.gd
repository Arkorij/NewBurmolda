extends Node
## Одноразовый скриншотер (оконный): рендерит ключевые сцены/состояния в PNG.
## Запуск: --shot. Пользователь разрешил окно для отладки.

const OUT := "C:/Users/Egor/Documents/110/Dixxer/NewBurmolda/_shots/"


func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(OUT)
    await get_tree().process_frame
    GameState.new_game("Скрин")
    var p := GameState.player
    p.add_item("weapon_0_5"); Items.equip(p, "weapon_0_5")
    p.add_item("shield_0_4"); Items.equip(p, "shield_0_4")
    p.add_item("ring_poison_5"); Items.equip(p, "ring_poison_5")
    p.add_item("armor_0_4"); Items.equip(p, "armor_0_4")
    p.add_item("зелье свэга")
    p.flags["learn_sigma"] = true

    var t = load("res://scenes/Title.tscn").instantiate(); add_child(t)
    await _wait(); await _save("01_title"); t.free()

    # плакаты боссов (на согласование)
    var posters := [
        ["kalitin", "Калитин", "★ КОСТЯНОЙ БАРАБАНЩИК ★", Color("#c0293a"),
         "Гремит костями в такт. Боится замены ОЗУ в макбуках."],
        ["tsizi", "Дух Цизи", "★ ДУХ СКВОЗНЯКА ★", Color("#35b6d6"),
         "Дует и лжёт. Лжёт и дует. Иногда одновременно."],
        ["zhizha", "Великая Жижа", "★ ВЕЛИКАЯ ЖИЖА ★", Color("#4ac04a"),
         "Финальная форма болота. Не имеет формы."],
        ["tm", "ТМ", "★ НЕЧТО ИЗ ГЛУБИН ★", Color("#5a2a9a"),
         "Никто не знает расшифровки. «тм», — говорит ТМ."],
    ]
    for pd in posters:
        var po = load("res://scenes/Poster.tscn").instantiate()
        po.sprite_key = pd[0]
        po.title_text = pd[1]
        po.subtitle_text = pd[2]
        po.color = pd[3]
        po.flavor = pd[4]
        add_child(po)
        await _wait()
        await _save("09_poster_" + pd[0])
        po.free()

    var ow = load("res://scenes/Overworld.tscn").instantiate(); add_child(ow)
    await _wait(); await _save("02_overworld")
    p.hp = int(p.max_hp * 0.4)           # HUD: полосы HP/кринжа + тост
    p.cringe = int(p.next_level_cringe() * 0.6)
    ow._flash("💾 сохранено — тост-сообщение под HUD")
    await _wait(); await _save("02_overworld_hud")
    p.hp = p.max_hp
    p.level = 99
    for lid in ["tropa", "harbor", "volcano", "ice"]:
        if DataDB.locations.has(lid):
            ow.load_location(lid)
            await _wait(); await get_tree().create_timer(0.5).timeout
            await _save("02_loc_" + lid)
    ow.free()

    var b = load("res://scenes/Battle.tscn").instantiate(); b.enemy = ["Жаба-кринж", 40, 5]; add_child(b)
    await _wait()
    b._advance_message()
    await get_tree().process_frame
    b._advance_message()
    await _wait(); await _save("03_battle_menu")
    b._on_main(0)
    await _wait(); await _save("04_battle_fight")
    b._begin_bullets()
    await _wait_long(); await _save("05_battle_bullets")
    # длинный лог исхода — постраничный (не должен налезать на статы)
    var big: Array = []
    for i in range(14):
        big.append("Длинная строка исхода боя номер %d — лут, кринж и прочие радости." % i)
    b._show_lines(big, func(): pass)
    b._advance_message()      # дописать первую страницу мгновенно
    await _wait(); await _save("05_battle_longlog")
    b.free()

    # босс-файты: Калитин (хлыст с подсказкой), Цизи (снегопад), ТМ (взгляд)
    var bk = load("res://scenes/Battle.tscn").instantiate()
    bk.boss_key = "kalitin"
    add_child(bk)
    await _wait()
    bk._begin_bullets()
    bk._active_attacks = [KalitinKit.CableWhip.new()]
    bk._active_attacks[0].start(bk)
    bk._stray_cd = 0.2
    await get_tree().create_timer(0.7).timeout
    await _save("10_boss_kalitin_whip")
    bk.free()
    var bt = load("res://scenes/Battle.tscn").instantiate()
    bt.boss_key = "tsizi"
    add_child(bt)
    await _wait()
    bt._begin_bullets()
    bt._snow_cd = 0.0
    for _s in range(5):
        bt._spawn_snowflake()
    await get_tree().create_timer(0.9).timeout
    await _save("10_boss_tsizi_snow")
    bt.free()
    var btm = load("res://scenes/Battle.tscn").instantiate()
    btm.boss_key = "tm"
    btm.enemy = ["ТМ", 460, 17]
    add_child(btm)
    await _wait()
    btm._begin_bullets()
    btm._gaze_cd = 0.0
    btm._step_boss_ambient(0.016)
    await get_tree().create_timer(1.0).timeout
    await _save("10_boss_tm_gaze")
    btm.free()

    var np = load("res://scenes/NPC.tscn").instantiate(); np.kind = "yampol"; add_child(np)
    await _wait(); await _save("06_npc"); np.free()

    for wk in ["teplichnaya", "zombie"]:
        var wn = load("res://scenes/NPC.tscn").instantiate()
        wn.kind = wk
        add_child(wn)
        await _wait()
        await _save("06_npc_" + wk)
        wn.free()

    # инвентарь: снаряга + добыча + резерв ОЗУ + квестовые обереги
    p.add_item("weapon_2_3"); p.add_item("weapon_0_0"); p.add_item("armor_1_3")
    p.add_item("ring_freeze_3"); p.add_item("trinket_2_2")
    p.add_item("оберег Ямполь")
    p.add_item("ржавая руда", 7); p.add_item("мелкая рыбёшка", 3)
    p.add_item("пучок кринж-травы", 2); p.add_item("тёмный кристалл-кринж")
    p.add_item("мятая кость", 4); p.add_item("уголёк-бурмолёк", 2)
    p.add_item("цветок свэга"); p.add_item("перо стервятника")
    p.add_item("сердце пекла"); p.add_item("зольный слиток")
    p.add_item("ледяная крошка", 2); p.add_item("клок шерсти-кринж")
    p.add_item("ком жирной грязи", 3)
    p.add_item("ОЗУ", 2); p.flags["popov_ozu_taken"] = true
    p.add_item("череп Калитина"); p.add_item("карманный вентилятор")
    p.add_item("пропуск на болотный движ"); p.add_item("отросток лианы")
    p.add_item("зелье уворота"); p.add_item("болотная шаурма")
    p.add_item("стейк из топляка")
    var inv = load("res://scenes/Inventory.tscn").instantiate(); add_child(inv)
    await _wait(); await _save("07_inventory_weapon")
    for tabshot in [[3, "trinkets"], [5, "supplies"], [6, "loot"], [7, "quest"]]:
        inv.tab_i = tabshot[0]
        inv._rebuild()
        await _wait()
        await _save("07_inventory_" + str(tabshot[1]))
    inv.free()

    # адская шахта: все виды комнат + ярусы палитр + пост-ТМ пепелище
    var dg = load("res://scenes/Dungeon.tscn").instantiate(); add_child(dg)
    var dshots := [
        [3, "lava_river", "river"], [7, "lava_lake", "lake"],
        [4, "water_lake", "water"], [8, "crystal", "crystal"],
        [12, "mushroom", "mushroom"], [16, "bones", "bones"],
        [23, "ash", "ash_postm"], [20, "tm", "tm"],
    ]
    for ds in dshots:
        dg.st = dg._gen_room(ds[0], ds[1])
        dg.rooms[ds[0]] = dg.st
        dg.depth = ds[0]
        dg.ppos = Vector2i(1, dg._midy())
        dg.busy = false
        dg._update_info()
        await _wait(); await get_tree().create_timer(0.5).timeout
        await _save("08_dungeon_" + str(ds[2]))
    # золотой сундук крупным планом: комната с форс-золотом
    dg.st = dg._gen_room(12, "plain")
    dg.st.chests.clear()
    dg.st.chests.append({"pos": Vector2i(6, dg._midy() - 2), "opened": false, "gold": true})
    dg.st.chests.append({"pos": Vector2i(9, dg._midy() - 2), "opened": false, "gold": false})
    dg.rooms[12] = dg.st
    dg.depth = 12
    await _wait(); await get_tree().create_timer(0.4).timeout
    await _save("08_dungeon_chests")
    dg.free()

    # ── адаптивность: те же экраны в окне 16:9 (stretch=expand) ──
    get_window().size = Vector2i(1136, 640)
    await _wait()
    var oww = load("res://scenes/Overworld.tscn").instantiate(); add_child(oww)
    await _wait(); await get_tree().create_timer(0.4).timeout
    await _save("11_wide_overworld")
    oww.free()
    var bw = load("res://scenes/Battle.tscn").instantiate()
    bw.boss_key = "kalitin"
    add_child(bw)
    await _wait()
    bw._begin_bullets()
    await get_tree().create_timer(0.8).timeout
    await _save("11_wide_battle")
    bw.free()
    var invw = load("res://scenes/Inventory.tscn").instantiate(); add_child(invw)
    await _wait(); await _save("11_wide_inventory"); invw.free()

    print("SHOTS DONE")
    get_tree().quit()


func _wait() -> void:
    await get_tree().process_frame
    await get_tree().create_timer(0.18).timeout


func _wait_long() -> void:
    await get_tree().create_timer(0.5).timeout


func _save(sname: String) -> void:
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    img.save_png(OUT + sname + ".png")
    print("shot ", sname)
