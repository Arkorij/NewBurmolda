extends Node
## «Игровая» сессия для поиска багов (оконная): ходит по локациям, дерётся,
## собирает ноды — и снимает скриншоты по ходу. Запуск: -- --play

const OUT := "C:/Users/Egor/Documents/110/Dixxer/NewBurmolda/_shots/"
var ow


func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(OUT)
    await get_tree().process_frame
    GameState.new_game("Игрок")
    ow = load("res://scenes/Overworld.tscn").instantiate()
    add_child(ow)
    await _wait(0.3)
    await _save("p01_base_start")

    # погулять по базе (случайные шаги)
    await _walk(25)
    await _save("p02_base_walked")

    # уйти на тропу и подраться с видимым мобом
    ow._travel("tropa")
    await _wait(0.3)
    await _save("p03_tropa")
    if ow.mobs.size() > 0:
        ow._start_map_battle(ow.mobs[0])
        await _wait(0.3)
        await _autobattle("p04")
    await _save("p05_after_battle")

    # добыча: гавань, нода рыбалки
    ow._travel("harbor") if false else ow.load_location("harbor")
    await _wait(0.3)
    var node_pos := _find_node()
    if node_pos.x >= 0:
        ow.ppos = node_pos + Vector2i(1, 0)
        ow._try_move(-1, 0)
        await _wait(0.4)
        await _save("p06_gather")
        for n in ow.overlay.get_children():
            ow._close_overlay(n)
    await _wait(0.2)

    # прогулка по опасной локации с гейтом (мобы, рандомные бои)
    GameState.player.level = 9
    ow.load_location("volcano")
    await _wait(0.3)
    await _walk(30)
    await _save("p07_volcano_walk")

    print("PLAY DONE, issues seen in console above if any")
    get_tree().quit()


func _walk(steps: int) -> void:
    for i in range(steps):
        if ow.busy:      # открылся бой/диалог — закрыть и идти дальше
            for n in ow.overlay.get_children():
                if n.has_signal("battle_over"):
                    await _autobattle("pw%d" % i)
                else:
                    ow._close_overlay(n)
            await _wait(0.1)
            continue
        var d: Array = [[1, 0], [-1, 0], [0, 1], [0, -1]][randi() % 4]
        ow._try_move(d[0], d[1])
        await _wait(0.03)


func _find_node() -> Vector2i:
    for y in ow.grid.size():
        var row: String = ow.grid[y]
        for x in row.length():
            if row[x] in "mfhjc":
                return Vector2i(x, y)
    return Vector2i(-1, -1)


func _autobattle(tag: String) -> void:
    ## Пройти бой «руками»: меню → приём → пропуск снарядной фазы.
    var b = null
    for n in ow.overlay.get_children():
        if n.has_signal("battle_over"):
            b = n
    if b == null:
        return
    await _save(tag + "_battle_open")
    var guard := 0
    while is_instance_valid(b) and b.is_inside_tree() and guard < 60:
        guard += 1
        match b.phase:
            0:      # MESSAGE
                b._advance_message()
            1:      # MENU
                b._on_main(0)
            2:      # SUB
                await _save(tag + "_fight_menu") if guard < 4 else null
                b._on_sub(0)
            3:      # BULLETS — чуть уворачиваемся, потом фаза сама кончится
                if guard % 3 == 0:
                    await _save(tag + "_bullets")
                b._bh_t = b._bh_dur      # ускоряем конец фазы
            4:      # DONE
                break
        await _wait(0.12)
    await _wait(0.2)


func _wait(t: float) -> void:
    await get_tree().create_timer(t).timeout


func _save(sname: String) -> void:
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(OUT + sname + ".png")
    print("shot ", sname)
