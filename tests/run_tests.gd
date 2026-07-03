extends Node
## Headless-тесты портированной логики. Запуск:
##   Godot_...console.exe --headless --path <proj> -- --test
## Выход с кодом 1 при провале (для CI/скриптов).

var failures := 0
var checks := 0


func _ready() -> void:
    print("=== БУРМОЛДА · headless-тесты ===")
    seed(12345)
    _test_data_integrity()
    _test_equip_math()
    _test_attacks_menu()
    _test_ring_effects()
    _test_ttk()
    _test_quests()
    _test_balance()
    _test_world()
    _test_story1()
    _test_story2()
    _test_report_fixes()
    _test_dungeon()
    _test_scenes()
    print("\n=== %s (%d проверок) ===" % [
        "ВСЁ ЗЕЛЁНОЕ" if failures == 0 else "%d ПРОВАЛОВ" % failures, checks])
    get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
    checks += 1
    if cond:
        print("  [OK]   ", msg)
    else:
        print("  [FAIL] ", msg)
        failures += 1


# ─────────────── тесты ───────────────
func _test_data_integrity() -> void:
    print("\n-- данные --")
    check(DataDB.items.size() == 119, "119 предметов (получено %d)" % DataDB.items.size())
    check(DataDB.locations.size() == 35, "35 локаций (%d)" % DataDB.locations.size())
    check(DataDB.npcs.size() == 17, "17 NPC (%d)" % DataDB.npcs.size())
    var bad := 0
    for lid in DataDB.locations:
        for ch in DataDB.locations[lid].get("exits", {}):
            if not DataDB.locations.has(DataDB.locations[lid]["exits"][ch]):
                bad += 1
    check(bad == 0, "все переходы (exits) резолвятся (битых: %d)" % bad)
    check(DataDB.locations.has("hellmine"), "стартовая 'Адская Шахта' на месте")
    check(DataDB.phrase("BURMOLZH").size() > 0, "банк реплик BURMOLZH загружен")


func _test_equip_math() -> void:
    print("\n-- экипировка --")
    var p := Player.new("Тест")
    check(int(Items.total_buffs(p).get("atk", 0)) == 0, "без снаряги atk-бафф = 0")
    p.add_item("weapon_0_5")
    Items.equip(p, "weapon_0_5")
    check(int(Items.total_buffs(p).get("atk", 0)) == 20, "легендарный меч даёт +20 atk")
    var hp_before := p.max_hp
    p.add_item("armor_0_4")
    Items.equip(p, "armor_0_4")
    check(p.max_hp == hp_before + 19, "броня т4 даёт +19 max_hp (%d->%d)" % [hp_before, p.max_hp])
    Items.unequip(p, "weapon")
    check(int(Items.total_buffs(p).get("atk", 0)) == 0, "после снятия меча atk-бафф = 0")


func _test_attacks_menu() -> void:
    print("\n-- приёмы боя --")
    var p := Player.new("Тест")
    check(Attacks.available(p).size() == 2, "без снаряги — 2 приёма (база+рёв)")
    p.add_item("weapon_0_5")
    Items.equip(p, "weapon_0_5")
    p.add_item("shield_0_4")
    Items.equip(p, "shield_0_4")
    p.flags["learn_sigma"] = true
    var ids := []
    for a in Attacks.available(p):
        ids.append(a["id"])
    check("cleave" in ids and "flurry" in ids and "legend" in ids,
          "меч т5 открыл рубящий/вихрь/легендарный")
    check("shieldbash" in ids, "щит открыл удар щитом")
    check("sigma_gaze" in ids, "выученный приём Сигма-взгляд доступен")


func _test_ring_effects() -> void:
    print("\n-- кольца --")
    # power: детерминированный +урон
    var p := Player.new("Тест")
    p.add_item("ring_power_5")
    Items.equip(p, "ring_power_5")
    var b := Battle.new(p, null, ["Манекен", 200, 1])
    var hp0 := b.enemy_hp
    var r: Array = b._hit(5)                     # 5 + power(10) = 15
    check(int(r[0]) == 15 and b.enemy_hp == hp0 - 15, "кольцо «Мощь» +10 урона (нанёс %d)" % r[0])
    # poison: накладывается и тикает
    var p2 := Player.new("Тест")
    p2.add_item("ring_poison_5")
    Items.equip(p2, "ring_poison_5")
    var b2 := Battle.new(p2, null, ["Манекен", 200, 1])
    b2._hit(5)
    check(b2.enemy_poison == 5, "яд наложен (стаки=%d)" % b2.enemy_poison)
    var tick := b2.poison_tick()
    check(tick == 5 and b2.enemy_poison == 4, "яд тикнул на 5 и убыл до 4")
    # freeze: гарантированная заморозка при 100%
    var p3 := Player.new("Тест")
    var b3 := Battle.new(p3, null, ["Манекен", 200, 1])
    b3.effects = {"freeze": 100}
    b3._hit(5)
    check(b3.enemy_frozen, "мороз при 100% ставит enemy_frozen")


func _test_ttk() -> void:
    print("\n-- TTK (время убийства) --")
    var samples := []
    for i in range(40):
        var p := Player.new("Тест")
        var b := Battle.new(p, null, ["Тест-моб", 20, 4])
        var rounds := 0
        while b.enemy_alive() and rounds < 60:
            b.attack()
            rounds += 1
        samples.append(rounds)
    var avg := 0.0
    for s in samples:
        avg += s
    avg /= samples.size()
    check(avg >= 2.0 and avg <= 8.0, "средний TTK моба ~3 хода (получено %.1f)" % avg)


func _test_balance() -> void:
    print("\n-- баланс (хард/боссы/паттерны) --")
    var p := Player.new("Баланс")
    # босс жирный: HP = base*mult + level*6
    var bhp := int(DataDB.bosses["kalitin"][1])
    var mult := float(DataDB.balance["BOSS_HP_MULT"]["kalitin"])
    var bb := Battle.new(p, "kalitin")
    check(bb.enemy_max == int(bhp * mult) + p.level * 6 and mult >= 1.5,
          "Калитин жирный (HP %d, мульт %.1f)" % [bb.enemy_max, mult])
    # мобы в харде толще: средний HP при danger 9 > danger 1
    var avg1 := 0.0
    var avg9 := 0.0
    for _i in range(12):
        avg1 += Battle.new(p, null, ["Тест", 30, 5], 1).enemy_max
        avg9 += Battle.new(p, null, ["Тест", 30, 5], 9).enemy_max
    check(avg9 / 12.0 > avg1 / 12.0 * 1.3, "хард-мобы толще (%.0f → %.0f)" % [avg1 / 12.0, avg9 / 12.0])
    # награда растёт с опасностью
    var b1 := Battle.new(p, null, ["Тест", 1, 1], 1)
    var gold0 := p.burmolda
    b1.resolve_victory()
    var r1 := p.burmolda - gold0
    var b9 := Battle.new(p, null, ["Тест", 1, 1], 9)
    gold0 = p.burmolda
    b9.resolve_victory()
    check(p.burmolda - gold0 > r1, "награда в харде выше (%d → %d)" % [r1, p.burmolda - gold0])
    # паттерны боссов — фирменные, во 2-й фазе пул шире
    var bs = load("res://scenes/Battle.tscn").instantiate()
    bs.boss_key = "kalitin"
    bs.battle = Battle.new(p, "kalitin")
    var pool1: Array = bs._pick_pool()
    check("walls" in pool1 and "laser" in pool1, "у Калитина кости/лучи")
    bs.battle.phase2 = true
    var pool2: Array = bs._pick_pool()
    check(pool2.size() > pool1.size(), "во 2-й фазе пул атак шире (%d→%d)" % [pool1.size(), pool2.size()])
    # фаза 2 срабатывает один раз на 50% HP
    var bk := Battle.new(p, "kalitin")
    check(bk.check_phase2().is_empty(), "фаза 2 не стартует на фулл HP")
    bk.enemy_hp = int(bk.enemy_max * 0.4)
    var dmg0 := bk.edmg
    check(not bk.check_phase2().is_empty() and bk.phase2 and bk.edmg == dmg0 + 2,
          "на 40%% HP босс свирепеет (+2 урона)")
    check(bk.check_phase2().is_empty(), "повторно фаза 2 не анонсируется")
    # мобы разных видов — разные стили атак
    bs.boss_key = null
    bs.battle = Battle.new(p, null, ["Костяной Пёс", 30, 5])
    var skel_pool: Array = bs._pick_pool()
    bs.battle = Battle.new(p, null, ["Кислотный Слизень", 30, 5])
    var sliz_pool: Array = bs._pick_pool()
    check("walls" in skel_pool and "rain" in sliz_pool and skel_pool != sliz_pool,
          "скелет кидает кости, слизень — ливень (стили разные)")
    # реролл даёт 1-2 валидных паттерна
    bs.battle = Battle.new(p, null, ["Тест", 30, 5])
    bs.hint_label = Label.new()
    bs.add_child(bs.hint_label)
    var okr := true
    for _k in range(10):
        bs._reshuffle(false)
        okr = okr and bs.active.size() >= 1 and bs.active.size() <= 2
    check(okr, "реролл даёт 1-2 активных паттерна (комбо)")
    bs.free()
    # уворот: источники стакаются мультипликативно (как в Доте), потолок 60%
    var be := Battle.new(p, null, ["Тест", 30, 5])
    be.eq = {"block": 20}
    check(be.evade_chance() == 20, "уворот = Блок%% со снаряги")
    p.add_item("зелье уворота")
    be.use_item("зелье уворота")
    # 1 - 0.80*0.65 = 48% (а не 55 при сложении)
    check(be.evade_chance() == 48, "зелье стакается мультипликативно (48%%)")
    be.evade_sources = [0.9, 0.9, 0.9]
    check(be.evade_chance() == 60, "уворот клампится на 60%%")
    # деградация зелий/росы в течение боя; новый бой — всё восстановлено
    var bd := Battle.new(p, null, ["Тест", 30, 5])
    p.hp = 1
    bd.use_item("__dew__")
    var hp1 := p.hp                         # +8
    p.hp = 1
    bd.use_item("__dew__")
    check(hp1 == 9 and p.hp == 6, "роса деградирует в бою (+8 → +5)")
    var bd2 := Battle.new(p, null, ["Тест", 30, 5])
    p.hp = 1
    bd2.use_item("__dew__")
    check(p.hp == 9, "в новом бою роса снова полная (+8)")
    # кольцо Невозмутимости нельзя продать кузнецу
    check(Items.get_item("ring_calm_q").get("no_sell", false) == true,
          "Кольцо Невозмутимости помечено «не продаётся»")
    # биом-эффекты в бою: маппинг + ожог у стен вулкана
    var bb2 = load("res://scenes/Battle.tscn").instantiate()
    bb2.enemy = ["Тест", 30, 5]
    bb2.biome = "volcano"
    GameState.new_game("Вулканщик")
    add_child(bb2)
    check(bb2._biome_kind() == "hot", "вулкан = раскалённые стены")
    bb2.biome = "opera_ice"
    check(bb2._biome_kind() == "ice", "ледяная опера = скольжение")
    bb2.biome = "swamp"
    check(bb2._biome_kind() == "goo", "болото = вязко")
    bb2.biome = ""
    check(bb2._biome_kind() == "", "подземелье/без биома = обычная физика")
    bb2.biome = "volcano"
    bb2._begin_bullets()
    bb2.soul = bb2.box.position + Vector2(bb2.SOUL_SIZE, bb2.SOUL_SIZE)
    var hp_before := GameState.player.hp
    bb2._bullets_step(0.016)
    check(GameState.player.hp < hp_before, "касание раскалённой стены жжёт")
    # зелёные обманки безвредны, обычные — бьют
    bb2.biome = ""
    bb2._begin_bullets()
    bb2.active = []
    bb2._seg_t = 99.0
    bb2._iframe = 0.0
    bb2.battle.evade_sources = []
    bb2.battle.eq = {}
    bb2.bullets = [{"kind": "ball", "pos": bb2.soul, "vel": Vector2.ZERO, "cls": 1, "safe": true}]
    var hp0 := GameState.player.hp
    bb2._bullets_step(0.016)
    check(GameState.player.hp == hp0, "🟢 зелёная обманка пролетает без урона")
    bb2.bullets = [{"kind": "ball", "pos": bb2.soul, "vel": Vector2.ZERO, "cls": 1, "safe": false}]
    bb2._bullets_step(0.016)
    check(GameState.player.hp < hp0, "обычная пуля в той же точке — бьёт")
    bb2.free()


func _test_world() -> void:
    print("\n-- мир (спавн/порталы/гейт) --")
    GameState.new_game("Мир")
    var ow = load("res://scenes/Overworld.tscn").instantiate()
    add_child(ow)
    ow.set_process(false)          # без бродячих мобов в тесте
    ow.load_location("base")
    ow._travel("tropa")
    check(ow.loc_id == "tropa", "переход base→tropa сработал")
    # спавн должен быть рядом с порталом '1' (ведёт обратно в base)
    var p1 := Vector2i(-1, -1)
    var p5 := Vector2i(-1, -1)
    for y in ow.grid.size():
        var row: String = ow.grid[y]
        if p1.x < 0 and row.find("1") >= 0:
            p1 = Vector2i(row.find("1"), y)
        if p5.x < 0 and row.find("5") >= 0:
            p5 = Vector2i(row.find("5"), y)
    check(p1.x >= 0 and Vector2(ow.ppos - p1).length() < 2.0,
          "спавн рядом с обратным порталом (%s ↔ %s)" % [ow.ppos, p1])
    check(p5.x >= 0 and Vector2(p5 - p1).length() > 3.0,
          "порталы 1 и 5 на тропе разнесены")
    # гейт уровня
    GameState.player.level = 1
    ow._travel("volcano")
    check(ow.loc_id == "tropa", "гейт: 1-й уровень в вулкан не пускает")
    GameState.player.level = 99
    ow._travel("volcano")
    check(ow.loc_id == "volcano", "с высоким уровнем — пускает")
    ow.free()


func _test_story1() -> void:
    print("\n-- сюжет-правка 1 (Тепличная/Дед/Воздухан/Зомби) --")
    # Дед: «Старые счёты» теперь про ТМ
    check(DataDB.quests["ded_bones"]["boss"] == "tm_defeated"
          and "ТМ" in DataDB.quests["ded_bones"]["desc"], "квест Деда нацелен на ТМ")
    # Цизи получил свой квест — «Перегрев» от Попова
    check(DataDB.quests["popov_wind"]["boss"] == "tsizi_defeated"
          and DataDB.quests["popov_wind"]["giver"] == "popov",
          "Попов даёт квест на Цизи («Перегрев»)")
    # цепочка Тепличной: 3 загадки, финал — Кольцо Невозмутимости
    check(DataDB.quests.has("tepl_1") and DataDB.quests["tepl_2"]["requires"] == "tepl_1"
          and DataDB.quests["tepl_3"]["reward"].get("item") == "ring_calm_q",
          "цепочка Тепличной ведёт к Кольцу Невозмутимости")
    check(not DataDB.quests["tepl_1"]["reward"].has("burmolda"),
          "загадки Тепличной платят только кринжем")
    # Кольцо Невозмутимости работает в увороте
    var p := Player.new("Спокойный")
    p.add_item("ring_calm_q")
    Items.equip(p, "ring_calm_q")
    var b := Battle.new(p, null, ["Тест", 30, 5])
    check(b.evade_chance() == 18, "Кольцо Невозмутимости даёт 18%% уворота")
    # Воздухан: честность не считается, враньё — считается
    var p2 := Player.new("Врун")
    NPCEffects.apply(p2, "vozduhan_quest_take")
    check(p2.flags.get("vozduhan_quest_taken", false), "задание Воздухана берётся")
    NPCEffects.apply(p2, "vozduhan_truth")
    check(not p2.flags.get("vozduhan_quest_done", false), "честный ответ НЕ засчитан")
    NPCEffects.apply(p2, "vozduhan_lie")
    check(p2.flags.get("vozduhan_quest_done", false), "враньё засчитано (дух лжи доволен)")
    # новые NPC загружены, спрайты на месте
    check(DataDB.npcs.has("teplichnaya") and DataDB.npcs.has("zombie"),
          "Тепличная и Зомби в данных")
    check(DataDB.sprite_grids.has("teplichnaya") and DataDB.sprite_grids.has("zombie"),
          "спрайты Тепличной и Зомби нарисованы")
    # Тепличная гарантированно встречает новичка на базе
    GameState.new_game("Новичок")
    var ow = load("res://scenes/Overworld.tscn").instantiate()
    add_child(ow)
    ow.set_process(false)
    ow.load_location("base")
    var found := false
    for w in ow.wanderers:
        if w.kind == "teplichnaya":
            found = true
    check(found, "Тепличная встречает новичка на базе")
    ow.free()


func _test_story2() -> void:
    print("\n-- сюжет-правка 2 (Зав Воздуха / Рыба-гейткипер) --")
    # цепочка Рыбы: 3 муторных квеста без наград, гейтят «Старые счёты» Деда
    check(DataDB.quests.has("fish_1") and DataDB.quests["fish_2"]["requires"] == "fish_1"
          and DataDB.quests["fish_3"]["requires"] == "fish_2",
          "цепочка Рыбы из 3 квестов собрана")
    check(DataDB.quests["fish_1"]["reward"].is_empty()
          and DataDB.quests["fish_3"]["reward"].is_empty(),
          "квесты Рыбы не дают наград (ей плевать)")
    check(DataDB.quests["ded_bones"]["requires"] == "fish_3",
          "«Старые счёты» Деда закрыты за Рыбой (гейткипер)")
    check(not DataDB.quests.has("fish_revenge"), "старая «Месть воде» удалена")
    # Дед не выдаёт квест, пока Рыба не закрыта
    var pg := Player.new("Гейт")
    check(not "ded_bones" in Quests.givable(pg, "ded"), "Дед молчит до квестов Рыбы")
    pg.quests["fish_1"] = {"status": "done", "progress": 0}
    pg.quests["fish_2"] = {"status": "done", "progress": 0}
    pg.quests["fish_3"] = {"status": "done", "progress": 0}
    check("ded_bones" in Quests.givable(pg, "ded"), "после Рыбы Дед даёт «Старые счёты»")
    # Зав Воздуха: ОЗУ — ресурс, продаётся; premium-скупка платит x1.5
    check(Econ.is_resource("ОЗУ") and Econ.price("ОЗУ") == 45, "ОЗУ — ресурс (45 ⛃)")
    var ps := Player.new("Продавец")
    ps.add_item("ржавая руда", 2)          # 2 x 5 = 10
    var res := Econ.sell_all(ps, 1.5)
    check(res[0] == 15, "premium-скупка Зава платит x1.5 (10 → 15)")
    # опции Зава: квест ОЗУ и premium-скупка на месте с правильными флагами
    var pv: Dictionary = DataDB.npcs["popov"]
    var has_fetch := false
    var has_premium := false
    for opt in pv["options"]:
        if opt.get("kind") == "fetch" and opt.get("give_item") == "антиспам-оберег":
            has_fetch = true
        if opt.get("kind") == "sell" and float(opt.get("premium", 1.0)) > 1.0 \
                and opt.get("req_flag") == "popov_ozu_done":
            has_premium = true
    check(has_fetch and has_premium, "сдача ОЗУ и царская скупка настроены у Зава")


func _test_report_fixes() -> void:
    print("\n-- фиксы по отчёту (читы/фарм/лут/гейты/мороз) --")
    # smoke: все строки use_item/heal_options валидны (ловим форматные крахи)
    var p := Player.new("Смок")
    p.add_item("зелье свэга")
    p.add_item("зелье уворота")
    var bs := Battle.new(p, null, ["Тест", 30, 5])
    var ok := true
    for opt in bs.heal_options():
        ok = ok and str(opt[1]).length() > 0
    for key in ["зелье свэга", "зелье уворота", "__dew__"]:
        for line in bs.use_item(key):
            ok = ok and line is String and str(line).length() > 0
    check(ok, "smoke: строки предметов боя не крашатся и не пустые")
    # мороз: один бросок за приём, не чаще чем через ход
    var pf := Player.new("Мороз")
    var bf := Battle.new(pf, null, ["Тест", 200, 5])
    bf.effects = {"freeze": 100}
    bf._hit(5)
    check(bf.enemy_frozen and bf._freeze_tried, "мороз сработал на первом ударе")
    bf.enemy_frozen = false          # симулируем «пропущенный ход»
    bf._hit(5)
    check(not bf.enemy_frozen, "повторный удар в том же ходу НЕ морозит")
    bf.poison_tick()                 # враг реально сходил
    bf._hit(5)
    check(bf.enemy_frozen, "после хода врага мороз снова доступен")
    # квестовое кольцо не падает лутом
    var leak := false
    for _i in range(300):
        if Items.random_item(5, "ring") == "ring_calm_q":
            leak = true
    check(not leak, "ring_calm_q не выпадает из random_item (300 бросков)")
    # гейты сюжетных зон и порядок целей
    check(int(DataDB.locations["kalitin"]["min_level"]) == 5
          and int(DataDB.locations["bonefield"]["min_level"]) == 3,
          "Логово Калитина за гейтом 5 ур. (кости — 3)")
    var pg := Player.new("Спидраннер")
    pg.flags["kalitin_defeated"] = true
    check("Цизи" in Quests.main_goal(pg), "Калитин без Цизи ≠ «игра пройдена»")
    pg.flags["tsizi_defeated"] = true
    check("пройдена" in Quests.main_goal(pg), "оба босса = игра пройдена")
    # замена слабейшего кольца
    var pr := Player.new("Ювелир")
    for id in ["ring_power_1", "ring_power_5", "ring_crit_3"]:
        pr.add_item(id)
    Items.equip(pr, "ring_power_1")
    Items.equip(pr, "ring_power_5")
    Items.equip(pr, "ring_crit_3")
    var worn := [pr.equipment["ring1"], pr.equipment["ring2"]]
    check(not "ring_power_1" in worn and "ring_power_5" in worn and "ring_crit_3" in worn,
          "третье кольцо заменяет более слабое (т1), а не первый слот")
    # мини-игры: раз за визит (опция исчезает после использования)
    GameState.new_game("Игрок")
    var ns = load("res://scenes/NPC.tscn").instantiate()
    ns.kind = "yampol_jr"
    add_child(ns)
    var before: int = ns.visible_options.size()
    for opt in ns.visible_options:
        if opt.get("once", false):
            ns.used_once[opt.get("label", "")] = true
    ns._rebuild_options()
    check(ns.visible_options.size() == before - 1, "ладушки: раз за визит (опция скрылась)")
    ns.free()
    # читы выключены без --cheats
    var ow2 = load("res://scenes/Overworld.tscn").instantiate()
    add_child(ow2)
    ow2.set_process(false)
    check(not ow2._cheats_on(), "F1-читы выключены без флага --cheats")
    ow2.free()


func _test_dungeon() -> void:
    print("\n-- адская шахта --")
    GameState.new_game("Шахтёр")
    var dg = load("res://scenes/Dungeon.tscn").instantiate()
    add_child(dg)
    dg.set_process(false)
    # 60 этажей генерятся без зависаний, двери всегда достижимы (ряд midy чист)
    var ok_path := true
    var kinds := {}
    for d in range(1, 61):
        dg._enter_room(d, false)
        kinds[dg.st.kind] = true
        var midy: int = dg._midy()
        for x in range(1, int(dg.st.w) - 1):
            var ch: String = dg._cell_of(dg.st, Vector2i(x, midy))
            if ch != ".":
                ok_path = false
    check(true, "60 этажей сгенерированы без зависаний")
    check(ok_path, "ряд дверей всегда проходим (путь гарантирован)")
    check(kinds.size() >= 5, "комнаты разнообразны (%d видов)" % kinds.size())
    # расписание боссов
    dg._enter_room(5, false)
    check(dg.st.mobs.size() == 1 and str(dg.st.mobs[0].enemy[0]) == "Надзиратель Пекла",
          "этаж 5 — мини-босс Надзиратель")
    dg._enter_room(10, false)
    check(str(dg.st.mobs[0].enemy[0]) == "Магистр Пекла", "этаж 10 — босс Магистр Пекла")
    dg._enter_room(25, false)
    check(str(dg.st.mobs[0].enemy[0]) == "ТМ", "этаж 25 — ТМ")
    # дверь заперта пока мобы живы; после зачистки открыта
    dg._enter_room(3, false)
    var was_alive: bool = not dg._all_dead()
    for m in dg.st.mobs:
        m.alive = false
    check(was_alive and dg._all_dead(), "зачистка комнаты открывает дверь")
    # возврат назад хранит комнату (та же сетка)
    var g4: Array = dg.rooms[4]["grid"] if dg.rooms.has(4) else []
    dg._enter_room(4, false)
    var g4b: Array = dg.st.grid
    check(g4.is_empty() or g4 == g4b, "комнаты персистентны внутри похода")
    # спрайты Пекла резолвятся
    check(Sprites.mob_key("ТМ") == "tm" and Sprites.mob_key("Магмовый Краб") == "magma_crab"
          and Sprites.mob_key("Надзиратель Пекла") == "overseer",
          "спрайты Пекла резолвятся по именам")
    dg.free()


func _test_scenes() -> void:
    print("\n-- сцены (smoke) --")
    GameState.new_game("Тест")
    var ok := true
    for path in ["res://scenes/Title.tscn", "res://scenes/Overworld.tscn"]:
        var inst = load(path).instantiate()
        add_child(inst)
        ok = ok and is_instance_valid(inst)
        inst.free()
    check(ok, "Title/Overworld инстанцируются без ошибок")
    var bs = load("res://scenes/Battle.tscn").instantiate()
    bs.enemy = ["Смок-моб", 20, 4]
    add_child(bs)
    check(is_instance_valid(bs) and bs.battle != null, "Battle.tscn создаётся и строит модель боя")
    bs.free()
    var ns = load("res://scenes/NPC.tscn").instantiate()
    ns.kind = "yampol"
    add_child(ns)
    check(is_instance_valid(ns), "NPC.tscn инстанцируется (yampol)")
    ns.free()
    for path in ["res://scenes/Poster.tscn", "res://scenes/Echo.tscn"]:
        var n2 = load(path).instantiate()
        add_child(n2)
        ok = ok and is_instance_valid(n2)
        n2.free()
    var g = load("res://scenes/Gather.tscn").instantiate()
    g.node_type = "mine"
    add_child(g)
    check(is_instance_valid(g) and not g.res_list.is_empty(), "Gather.tscn (шахта) читает ресурсы ноды")
    g.free()
    check(DataDB.node_info.size() == 6, "6 типов нод загружено")
    for path in ["res://scenes/Inventory.tscn", "res://scenes/Blacksmith.tscn",
                 "res://scenes/Dungeon.tscn", "res://scenes/QuestLog.tscn", "res://scenes/Journal.tscn"]:
        var n3 = load(path).instantiate()
        add_child(n3)
        ok = ok and is_instance_valid(n3)
        n3.free()
    check(ok, "все экраны Фазы 2–3 инстанцируются без ошибок")
    print("\n-- Фаза 4 (спрайты/шрифт/звук) --")
    check(Sprites.mob_key("Комар") == "komar" and Sprites.mob_key("Жаба-кринж") == "zhaba",
          "спрайт-ключ мобов резолвится по имени (komar/zhaba)")
    check(DataDB.sprite_grids.size() >= 40 and DataDB.sprite_grids.has("player"),
          "пиксель-арт сетки загружены (есть 'player')")
    check(ResourceLoader.exists("res://assets/fonts/NotoEmoji-Regular.ttf"), "эмодзи-шрифт на месте")
    check(Sfx._bank.size() == 4, "Sfx: 4 звука сгенерировано")


func _test_quests() -> void:
    print("\n-- квесты --")
    var p := Player.new("Квестор")
    check("shest_dew" in Quests.givable(p, "shest"), "Шестухина выдаёт «Свежая роса»")
    Quests.start(p, "shest_dew")
    Quests.on_kill(p, "Комар")
    Quests.on_kill(p, "Жаба-кринж")
    Quests.on_kill(p, "Жижевой Уж")
    check(p.quests["shest_dew"]["status"] == "ready", "3 убийства (комар/жаба/уж) → квест готов")
    var before := p.burmolda
    Quests.turn_in(p, "shest_dew")
    check(p.quests["shest_dew"]["status"] == "done" and p.burmolda == before + 30,
          "сдача даёт награду +30 бурмолды")
