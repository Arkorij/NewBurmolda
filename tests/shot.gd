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
    # комбо: кости + ливень одновременно, коробка сжата
    b._begin_bullets()
    b.active = [{"pat": "walls", "cd": 0.0}, {"pat": "rain", "cd": 0.0}]
    b._seg_t = 99.0
    b.box_target = Rect2(245, 200, 150, 110)
    b.bullets.clear()
    b.zones.clear()
    await get_tree().create_timer(1.2).timeout
    await _save("05_combo_walls_rain")
    b.free()

    var np = load("res://scenes/NPC.tscn").instantiate(); np.kind = "yampol"; add_child(np)
    await _wait(); await _save("06_npc"); np.free()

    var inv = load("res://scenes/Inventory.tscn").instantiate(); add_child(inv)
    await _wait(); await _save("07_inventory"); inv.free()

    # адская шахта: река лавы / озеро с рыбами / этаж ТМ
    var dg = load("res://scenes/Dungeon.tscn").instantiate(); add_child(dg)
    dg.st = dg._gen_room(3, "lava_river"); dg.rooms[3] = dg.st; dg.depth = 3
    dg.ppos = Vector2i(1, dg._midy())
    await _wait(); await get_tree().create_timer(0.4).timeout
    await _save("08_dungeon_river")
    dg.st = dg._gen_room(7, "lava_lake"); dg.rooms[7] = dg.st; dg.depth = 7
    dg.ppos = Vector2i(1, dg._midy())
    await _wait(); await get_tree().create_timer(0.6).timeout
    await _save("08_dungeon_lake")
    dg.st = dg._gen_room(25, "tm"); dg.rooms[25] = dg.st; dg.depth = 25
    dg.ppos = Vector2i(1, dg._midy())
    dg.busy = false
    await _wait(); await _save("08_dungeon_tm")
    dg.free()

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
