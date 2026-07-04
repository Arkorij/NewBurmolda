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
    _test_bullet_kit()
    _test_hp_ui_sync()
    _test_boss_ambient()
    _test_boss_kits()
    _test_mob_threats()
    _test_dialogs()
    _test_ui_polish()
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
    check(DataDB.items.size() == 122, "122 предмета (получено %d)" % DataDB.items.size())
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
    print("\n-- баланс (хард/боссы/модель боя) --")
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
    # фаза 2 срабатывает один раз на 50% HP (модель боя)
    var bk := Battle.new(p, "kalitin")
    check(bk.check_phase2().is_empty(), "фаза 2 не стартует на фулл HP")
    bk.enemy_hp = int(bk.enemy_max * 0.4)
    var dmg0 := bk.edmg
    check(not bk.check_phase2().is_empty() and bk.phase2 and bk.edmg == dmg0 + 2,
          "на 40%% HP босс свирепеет (+2 урона)")
    check(bk.check_phase2().is_empty(), "повторно фаза 2 не анонсируется")
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


const _PH_BULLETS := 3     # Phase.BULLETS
const _PH_MENU := 1        # Phase.MENU
const _PH_DONE := 4        # Phase.DONE


func _fresh_arena(boss = null, enemy_arr = null) -> Node:
    GameState.new_game("Полигон")
    var a = load("res://scenes/Battle.tscn").instantiate()
    a.boss_key = boss
    if enemy_arr != null:
        a.enemy = enemy_arr
    add_child(a)               # _ready() создаёт battle
    return a


func _test_bullet_kit() -> void:
    print("\n-- BulletKit (примитивы арены) --")
    var a := _fresh_arena(null, ["Манекен", 30, 5])
    a.soul = a.box.get_center()
    a._hit_r = 6.0
    a._iframe = 0.0
    # 1. честный телеграф: фигура с warn безвредна, потом бьёт
    a.bullets.clear()
    GameState.player.hp = GameState.player.max_hp
    a.spawn_shape(&"rect", a.soul, Vector2.ZERO, {"size": Vector2(24, 24), "warn": 0.3})
    var hp0: int = GameState.player.hp
    BulletKit.step_hazards(a, 0.05)
    check(GameState.player.hp == hp0, "угроза в телеграфе безвредна")
    a._iframe = 0.0
    for _i in range(10):
        a._iframe = 0.0
        BulletKit.step_hazards(a, 0.05)
    check(GameState.player.hp < hp0, "после телеграфа фигура бьёт")
    # 2. силовое поле двигает сердце; снятое — нет
    a.soul = a.box.get_center()
    a.forces.clear()
    var fid: int = a.add_force(&"wind", {"dir": Vector2(100, 0)})
    var x0: float = a.soul.x
    BulletKit.step_forces(a, 0.1)
    check(a.soul.x > x0 + 5.0, "ветер двигает сердце")
    a.remove_force(fid)
    var x1: float = a.soul.x
    BulletKit.step_forces(a, 0.1)
    check(absf(a.soul.x - x1) < 0.01, "снятое поле не двигает")
    # 3. опасная зона бьёт ТОЛЬКО после телеграфа
    a.zones.clear()
    a.soul = a.box.get_center()
    a._iframe = 0.0
    GameState.player.hp = GameState.player.max_hp
    a.add_hazard_zone(Rect2(a.soul.x - 20, a.soul.y - 20, 40, 40), {"warn": 0.3, "active": 0.6})
    var hz: int = GameState.player.hp
    BulletKit.step_zones(a, 0.05)
    check(GameState.player.hp == hz, "зона в телеграфе не бьёт")
    for _i in range(8):
        a._iframe = 0.0
        BulletKit.step_zones(a, 0.05)
    check(GameState.player.hp < hz, "зона бьёт после телеграфа")
    # 4. безопасная зона: внутри цело, снаружи бьёт
    a.zones.clear()
    a._iframe = 0.0
    a.soul = a.box.get_center()
    a.add_safe_zone(Rect2(a.soul.x - 26, a.soul.y - 26, 52, 52), {"warn": 0.2, "active": 0.8})
    var hs: int = GameState.player.hp
    for _i in range(8):
        BulletKit.step_zones(a, 0.05)
    check(GameState.player.hp == hs, "внутри безопасной зоны не бьёт")
    a.zones.clear()
    a._iframe = 0.0
    GameState.player.hp = GameState.player.max_hp
    a.add_safe_zone(Rect2(a.box.position.x, a.box.position.y, 26, 26), {"warn": 0.2, "active": 0.8})
    a.soul = a.box.get_center()      # снаружи маленькой безопасной зоны
    var hs2: int = GameState.player.hp
    for _i in range(8):
        a._iframe = 0.0
        BulletKit.step_zones(a, 0.05)
    check(GameState.player.hp < hs2, "снаружи безопасной зоны бьёт")
    # 5. коридор: примитив включается/снимается
    a.set_corridor(Rect2(10, 10, 40, 40))
    check(a.has_corridor, "коридор включён")
    a.set_corridor(Rect2())
    check(not a.has_corridor, "пустой rect снимает коридор")
    # 6. clamp_step ограничивает шаг (достижимость безопасных точек)
    check(BulletKit.clamp_step(0.0, 100.0, 10.0) == 10.0
          and BulletKit.clamp_step(50.0, 20.0, 5.0) == 45.0,
          "clamp_step: без «телепорта» (шаг ≤ max)")
    # 7. биом-физика (маппинг) + ожог раскалённой стены
    a.biome = "volcano"
    check(a._biome_kind() == "hot", "вулкан = раскалённые стены")
    a.biome = "opera_ice"
    check(a._biome_kind() == "ice", "ледяная опера = скольжение")
    a.biome = "swamp"
    check(a._biome_kind() == "goo", "болото = вязко")
    a.biome = ""
    check(a._biome_kind() == "", "подземелье/без биома = обычная физика")
    a.biome = "volcano"
    a._begin_bullets()
    a._active_attacks = []
    a.soul = a.box.position + Vector2(a.SOUL_SIZE, a.SOUL_SIZE)
    a._iframe = 0.0
    a.bh_t = 0.0
    GameState.player.hp = GameState.player.max_hp
    var hb: int = GameState.player.hp
    a._bullets_step(0.016)
    check(GameState.player.hp < hb, "касание раскалённой стены жжёт")
    a.free()
    # 8. динамический хитбокс сжимается в плотном шквале
    var a2 := _fresh_arena(null, ["Тест", 30, 5])
    a2._begin_bullets()              # запускает лёгкую моб-угрозу (не даёт _next_beat спамить)
    for _i in range(60):
        a2.spawn_shape(&"rect", a2.box.position, Vector2.ZERO, {"size": Vector2(6, 6)})
    var r0: float = a2._hit_r
    for _i in range(30):
        a2._bullets_step(0.033)
    check(a2._hit_r < r0 - 0.8 and a2._hit_r >= a2.HIT_R_MIN,
          "плотный шквал сжимает хитбокс (%.1f → %.1f)" % [r0, a2._hit_r])
    a2.free()


func _test_hp_ui_sync() -> void:
    print("\n-- HP-бар/лейбл синхронны с уроном сразу после атаки --")
    var a := _fresh_arena(null, ["Манекен", 200, 5])
    var hp0: int = a.battle.enemy_hp
    var w0: float = a.hp_fg.size.x
    var r: Array = a.battle._hit(10)          # детерминированный урон, минуя шанс промаха
    a._resolve_action(r[1])
    check(a.battle.enemy_hp == hp0 - 10, "урон нанесён (модель боя)")
    check(a.hp_fg.size.x < w0, "HP-полоса обновилась сразу после атаки (не ждёт побочных событий)")
    check(("HP %d/" % a.battle.enemy_hp) in a.enemy_label.text,
          "текст HP-лейбла соответствует актуальному battle.enemy_hp")
    a.free()


func _test_boss_ambient() -> void:
    print("\n-- фоновые босс-слои (стрей/снег/взгляд) и hold мобов --")
    # Калитин: стрей-пули остались только у него
    var ak := _fresh_arena("kalitin")
    ak.bullets.clear()
    ak._stray_cd = 0.0
    ak._step_boss_ambient(0.016)
    check(ak.bullets.size() > 0, "Калитин: стрей-пули на месте")
    ak.free()
    # Цизи: вместо стрея — снегопад (одиночные снежки сверху)
    var at = _fresh_arena("tsizi")
    at.bullets.clear()
    at._snow_cd = 0.0
    at._step_boss_ambient(0.016)
    check(at.bullets.size() == 1 and at.bullets[0].shape == &"orb"
          and at.bullets[0].pos.y < at.box.position.y,
          "Цизи: снежок падает сверху (не стрей)")
    at.free()
    # ТМ: следящий «взгляд»-лезвие, доворачивается за душой после телеграфа
    var am = _fresh_arena("tm", ["ТМ", 300, 14])
    am.bullets.clear()
    am._gaze_cd = 0.0
    am._step_boss_ambient(0.016)
    check(am._tm_gaze != null and am._tm_gaze.shape == &"blade",
          "ТМ: «взгляд»-лезвие заспавнился")
    am._tm_gaze.warn = 0.0
    am._tm_gaze.pos = am.box.position
    am._tm_gaze.angle = 0.0
    am.soul = am.box.end
    var a0: float = am._tm_gaze.angle
    am._steer_tm_gaze(0.1)
    check(am._tm_gaze.angle > a0, "взгляд ТМ доворачивается к душе")
    am.free()
    # Жижа/Надзиратель/Магистр: фонового слоя нет
    var clean := true
    for bk in ["zhizha", "overseer", "pekl_master"]:
        var az = _fresh_arena(bk, ["Тест", 100, 8]) if bk != "zhizha" else _fresh_arena("zhizha")
        az.bullets.clear()
        az._stray_cd = 0.0
        az._snow_cd = 0.0
        az._gaze_cd = 0.0
        for _i in range(30):
            az._step_boss_ambient(0.05)
        if not az.bullets.is_empty():
            clean = false
        az.free()
    check(clean, "у Жижи/Надзирателя/Магистра стрей-пуль больше нет")
    # хлыст Калитина: короче коробки и с ограниченной жизнью
    var aw = _fresh_arena("kalitin")
    aw.bullets.clear()
    var whip = KalitinKit.CableWhip.new()
    whip.start(aw)
    var bl: Dictionary = aw.bullets[0]
    check(float(bl.half.x) * 2.0 < aw.box.size.y and float(bl.life) <= 2.1,
          "хлыст Калитина укорочен и живёт меньше")
    check(absf(float(bl.spin)) > 0.01, "у хлыста есть spin — BulletKit рисует подсказку направления")
    aw.free()
    # hold: центровые атаки мобов дают 1с на отход и не стреляют в это время
    check(MobThreats._make("spin").hold == 1.0 and MobThreats._make("pulse").hold == 1.0
          and MobThreats._make("cross").hold == 1.0 and MobThreats._make("xspiral").hold == 1.0,
          "hold=1с у всех атак из центра")
    check(MobThreats._make("rain").hold == 0.0 and MobThreats._make("spray").hold == 0.0,
          "у атак с краёв hold нет")
    var ah := _fresh_arena(null, ["Манекен", 30, 5])
    ah.bullets.clear()
    var spin_atk = MobThreats._make("spin")
    spin_atk.start(ah)
    for _i in range(6):
        spin_atk.tick(ah, 0.1)          # 0.6с — ещё hold
    var live := 0
    for b in ah.bullets:
        if float(b.warn) <= 0.0 and not b.get("safe", false):
            live += 1
    check(live == 0, "во время hold настоящих пуль нет (только телеграф в центре)")
    for _i in range(8):
        spin_atk.tick(ah, 0.1)          # 1.4с — атака пошла
    check(ah.bullets.size() > 1, "после hold вихрь стреляет")
    # Орбита: стягивается к центру и РЕЗКО разлетается (не застревает в центре)
    ah.bullets.clear()
    var orb_atk = MobThreats._make("orbit")
    orb_atk.start(ah)
    for _i in range(30):
        orb_atk.tick(ah, 0.1)           # 3с — успела собраться и лопнуть
    check(orb_atk._burst, "орбита собралась в центре и лопнула")
    var flying := true
    for o in orb_atk._orbs:
        if Vector2(o.vel).length() < 100.0:
            flying = false
    check(flying, "шарики орбиты резко разлетелись (не застряли в центре)")
    ah.free()


func _test_boss_kits() -> void:
    print("\n-- авторские киты боссов --")
    var keys := ["kalitin", "tsizi", "zhizha", "overseer", "pekl_master", "tm"]
    var kits := {
        "kalitin": KalitinKit.new(), "tsizi": TsiziKit.new(), "zhizha": ZhizhaKit.new(),
        "overseer": OverseerKit.new(), "pekl_master": PeklMasterKit.new(), "tm": TmKit.new(),
    }
    for key in keys:
        var kit = kits[key]
        # opening() — непустые биты из валидных BossAttack; каждая атака НЕСЁТ правило
        var op: Array = kit.opening()
        var op_ok: bool = op.size() > 0
        var rule_ok := true
        for beat in op:
            op_ok = op_ok and beat.size() >= 1
            for atk in beat:
                op_ok = op_ok and (atk is BossAttack)
                rule_ok = rule_ok and not str(atk.name).is_empty() \
                        and not str(atk.rule).is_empty()
        check(op_ok, "%s: opening() даёт валидные биты (%d)" % [key, op.size()])
        check(rule_ok, "%s: каждая атака несёт имя+правило (order-in-chaos)" % key)
        # pick() — непустой набор своих атак в интро и в ярости
        var p0: Array = kit.pick(0, false)
        var p3: Array = kit.pick(3, true)
        var pick_ok: bool = p0.size() >= 1 and p3.size() >= 1
        for atk in p0 + p3:
            pick_ok = pick_ok and (atk is BossAttack)
        check(pick_ok, "%s: pick() даёт свои атаки (интро %d / ярость %d)" % [key, p0.size(), p3.size()])
    # уникальность: имена атак не пересекаются между китами
    var names_by := {}
    for key in keys:
        var set := {}
        for beat in kits[key].opening():
            for atk in beat:
                set[atk.name] = true
        names_by[key] = set
    var overlap := 0
    for i in range(keys.size()):
        for j in range(i + 1, keys.size()):
            for nm in names_by[keys[i]]:
                if names_by[keys[j]].has(nm):
                    overlap += 1
    check(overlap == 0, "мувсеты боссов не пересекаются (общих атак: %d)" % overlap)
    # дымовой прогон полного хода уворота — для всех 6 боссов, интро и ярость
    for key in keys:
        for hard in [false, true]:
            var a := _fresh_arena(key)
            if hard:
                a.battle.phase2 = true
                a.turn_no = 8
            a._begin_bullets()
            var frames := 0
            while a.phase == _PH_BULLETS and frames < 1400:
                GameState.player.hp = GameState.player.max_hp   # переживаем всю фазу (прогон всех атак)
                a._bullets_step(0.033)
                frames += 1
            check(a.phase != _PH_BULLETS,
                  "%s%s: ход уворота отыгрывается до конца" % [key, " (ярость)" if hard else ""])
            a.free()
    # фаза 2 достижима: кит и прогресс opening ЖИВУТ между ходами (не пересоздаются)
    var ap := _fresh_arena("kalitin")
    check(ap._kit != null, "кит босса создан один раз (в _ready)")
    ap._beat_i = 3
    ap._begin_bullets()      # НЕ должен сбросить _beat_i в 0
    check(ap._beat_i >= 3, "_begin_bullets не сбрасывает opening → pick()/фаза 2 достижимы")
    ap.free()


func _test_mob_threats() -> void:
    print("\n-- лёгкая моб-система (25 паттернов, независимо от вида/биома) --")
    check(MobThreats.ARCHETYPES.size() >= 25, "25+ паттернов буллет-хелла для мобов (%d)"
          % MobThreats.ARCHETYPES.size())
    # каждый архетип собирается в валидную атаку с именем+правилом
    var all_ok := true
    for arch in MobThreats.ARCHETYPES:
        var atk: BossAttack = MobThreats._make(arch)
        all_ok = all_ok and (atk is BossAttack) and not str(atk.name).is_empty() \
                and not str(atk.rule).is_empty()
    check(all_ok, "каждый паттерн — валидная атака с именем+правилом")
    # паттерн НЕ зависит от вида моба: один и тот же ключ даёт разные паттерны
    var names := {}
    for _i in range(60):
        var seq: Array = MobThreats.sequence("komar")   # всегда один и тот же вид
        names[seq[0].name] = true
    check(names.size() >= 5, "паттерн случаен и независим от вида моба (%d разных из 60 бросков)"
          % names.size())
    # неизвестный вид тоже даёт валидную угрозу (без привязки к таблице)
    var unknown: Array = MobThreats.sequence("совсем_неизвестный_моб")
    check(unknown.size() >= 1 and unknown[0] is BossAttack,
          "неизвестный вид моба тоже получает валидный паттерн")
    # живой прогон КАЖДОГО паттерна ~1с — ловим рантайм-ошибки новых типов снарядов
    # (кресты/лучи/ракеты/снайперы): спавн, движение, взрыв ракет, очередь снайпера
    var ran := 0
    for arch in MobThreats.ARCHETYPES:
        var ra := _fresh_arena(null, ["Прогон", 20, 4])
        ra._begin_bullets()
        ra._active_attacks = [MobThreats._make(arch)]
        ra._active_attacks[0].start(ra)
        for _f in range(30):
            GameState.player.hp = GameState.player.max_hp
            ra._bullets_step(0.033)
        ran += 1
        ra.free()
    check(ran == MobThreats.ARCHETYPES.size(), "все %d паттернов прогоняются вживую" % ran)
    # дымовой прогон боя с мобом — доигрывается до конца
    var a := _fresh_arena(null, ["🐸 Бешеная Жаба-Переросток", 24, 6])
    a._begin_bullets()
    var frames := 0
    while a.phase == _PH_BULLETS and frames < 400:
        GameState.player.hp = GameState.player.max_hp
        a._bullets_step(0.033)
        frames += 1
    check(a.phase != _PH_BULLETS, "бой с мобом отыгрывается до конца")
    a.free()
    # биом влияет ТОЛЬКО на рамку/душу, независимо от паттерна: адский/данж моб —
    # рамка меньше; пустоши — ветер сносит; ни то, ни другое не трогает выбор паттерна
    var ah := _fresh_arena(null, ["Тест", 20, 4])
    ah.biome = "hell"
    ah._begin_bullets()
    check(ah.box.size.x < 196.0 and ah.box.size.y < 150.0,
          "адский/данж биом сжимает рамку моба")
    ah.free()
    var aw := _fresh_arena(null, ["Тест", 20, 4])
    aw.biome = "wastes"
    aw._begin_bullets()
    var has_wind := false
    for f in aw.forces:
        if f.kind == &"wind":
            has_wind = true
    check(has_wind, "пустоши/пустыня дают ветер, сносящий душу моба")
    aw.free()
    # для боссов рамку биом НЕ трогает — её ведёт авторский кит
    var ab := _fresh_arena("kalitin")
    ab.biome = "hell"
    ab._begin_bullets()
    check(ab.box.size.x == 196.0 and ab.box.size.y == 150.0,
          "у боссов биом не лезет в рамку — её ведёт кит")
    ab.free()


func _test_dialogs() -> void:
    print("\n-- диалоги (одноразовость / цепочки / уровень / эффекты) --")
    # 1. choice-опции одноразовы (once_flag) у ВСЕХ, кроме Деда (он всё забывает)
    var ok := true
    var total := 0
    for kind in DataDB.npcs:
        for opt in DataDB.npcs[kind].get("options", []):
            if str(opt.get("kind", "")) != "choice":
                continue
            total += 1
            var has_of: bool = opt.has("once_flag")
            if kind == "ded":
                ok = ok and not has_of
            else:
                ok = ok and has_of
            for a in opt.get("answers", []):
                ok = ok and not str(a.get("text", "")).is_empty() \
                        and not str(a.get("line", "")).is_empty()
    check(ok, "choice одноразовы везде, кроме Деда; ответы валидны")
    check(total >= 50, "реплик с выбором много (%d)" % total)
    # 2. есть реплики по уровню (гейт прокачки) + замкнутые цепочки set_flag→req_flag
    var lvl := 0
    var set_flags := {}
    var req_flags := {}
    for kind in DataDB.npcs:
        for opt in DataDB.npcs[kind].get("options", []):
            if opt.has("req_level") and int(opt["req_level"]) > 1:
                lvl += 1
            if opt.has("req_flag"):
                req_flags[opt["req_flag"]] = true
            for a in opt.get("answers", []):
                if a.has("set_flag"):
                    set_flags[a["set_flag"]] = true
    check(lvl >= 3, "есть реплики-по-уровню (%d)" % lvl)
    var chain_ok := set_flags.size() >= 3
    for f in set_flags:
        chain_ok = chain_ok and req_flags.has(f)
    check(chain_ok, "цепочки замкнуты: каждый set_flag открывает req_flag-реплику (%d)" % set_flags.size())
    # 3. поведение: одноразовость/уровень фильтруют, ответ даёт эффект + ставит флаг
    GameState.new_game("Диалог")
    var ns = load("res://scenes/NPC.tscn").instantiate()
    ns.kind = "yampol"
    add_child(ns)
    ns.player.flags["dlg_yampol_pod"] = true
    ns._rebuild_options()
    var hidden := true
    for o in ns.visible_options:
        if str(o.get("once_flag", "")) == "dlg_yampol_pod":
            hidden = false
    check(hidden, "одноразовая реплика скрыта после ответа (флаг стоит)")
    ns.player.level = 1
    ns.player.flags.erase("dlg_yampol_grown")
    ns._rebuild_options()
    var lgated_hidden := true
    for o in ns.visible_options:
        if str(o.get("once_flag", "")) == "dlg_yampol_grown":
            lgated_hidden = false
    check(lgated_hidden, "реплика по уровню скрыта на низком уровне")
    ns.player.level = 5
    ns._rebuild_options()
    var lvisible := false
    for o in ns.visible_options:
        if str(o.get("once_flag", "")) == "dlg_yampol_grown":
            lvisible = true
    check(lvisible, "реплика по уровню появляется на нужном уровне")
    var sw0: int = GameState.player.swag
    ns.current_choice = {"once_flag": "dlg_test_effect"}
    ns._apply_answer({"text": "t", "line": "l", "swag": 3, "set_flag": "dlg_test_chain"})
    check(GameState.player.swag == sw0 + 3, "ответ выдаёт эффект (свэг)")
    check(GameState.player.flags.get("dlg_test_effect", false)
          and GameState.player.flags.get("dlg_test_chain", false),
          "ответ ставит once_flag и set_flag")
    ns.free()


func _test_ui_polish() -> void:
    print("\n-- UI: пагинация, скролл меню, инвентарь, HUD --")
    # 1. UiText.paginate: длинный текст режется на страницы, каждая влезает
    var lines: Array = []
    for i in range(20):
        lines.append("строка-%02d " % i + "х".repeat(90))
    var pages := UiText.paginate(lines, 50, 7)
    check(pages.size() > 1, "длинное сообщение разбито на страницы (%d)" % pages.size())
    var fits := true
    for pg in pages:
        var rows := 0
        for l in str(pg).split("\n"):
            rows += UiText.wrapped_rows(l, 50)
        if rows > 7:
            fits = false
    check(fits, "каждая страница влезает в отведённые строки")
    check(UiText.paginate(["коротко"], 50, 7).size() == 1, "короткое сообщение — одна страница")
    # 2. SoulMenu: скролл-окно не показывает больше max_visible пунктов
    var sm := SoulMenu.new()
    add_child(sm)
    var many: Array = []
    for i in range(30):
        many.append("пункт %d" % i)
    sm.max_visible = 10
    sm.setup(many)
    var vr: Vector2i = sm.visible_range()
    check(vr.y - vr.x == 10, "SoulMenu показывает окно в 10 пунктов из 30")
    sm.index = 25
    sm._ensure_visible()
    vr = sm.visible_range()
    check(vr.x <= 25 and 25 < vr.y, "курсор на 25-м — окно доехало до него")
    sm.free()
    # 3. спрайт есть у ЛЮБОГО ключа инвентаря (снаряга/ресурсы/еда/зелья/трофеи)
    var all_ok := true
    for id in DataDB.items:
        if not Sprites.has(Sprites.item_key(id)):
            all_ok = false
    for res in DataDB.resources:
        if not Sprites.has(Sprites.item_key(res)):
            all_ok = false
    for f in DataDB.food:
        if not Sprites.has(Sprites.item_key(str(f[0]))):
            all_ok = false
    check(all_ok, "у всех предметов/ресурсов/еды есть спрайт (122 предмета + 27 ресурсов)")
    check(Sprites.item_key("зелье свэга") == "item_potion_swag"
          and Sprites.item_key("зелье уворота") == "item_potion_evade"
          and Sprites.item_key("череп Калитина") == "item_skull"
          and Sprites.item_key("карманный вентилятор") == "ventil"
          and Sprites.item_key("ОЗУ") == "res_ram"
          and Sprites.item_key("оберег Ямполь") == "item_charm_yampol"
          and Sprites.item_key("weapon_0_5") != Sprites.item_key("weapon_0_0")
          and Sprites.item_key("ring_poison_5") == "item_ring_poison",
          "спрайты различают тиры оружия, эффекты колец и особые вещи")
    # 4. инвентарь: вкладки раскладывают предметы по категориям
    GameState.new_game("Барахольщик")
    var p := GameState.player
    p.add_item("weapon_0_2")
    p.add_item("ржавая руда", 5)
    p.add_item("зелье свэга")
    p.add_item("череп Калитина")
    var inv = load("res://scenes/Inventory.tscn").instantiate()
    add_child(inv)
    check(inv._build_tab("weapon").size() == 1, "вкладка ОРУЖИЕ видит меч")
    var loot: Array = inv._build_tab("loot")
    check(loot.size() == 1 and loot[0]["key"] == "ржавая руда"
          and int(loot[0]["qty"]) == 5, "вкладка ДОБЫЧА: руда ×5 с ценой")
    check(inv._build_tab("supplies").size() == 1, "вкладка ПРИПАСЫ видит зелье")
    var q: Array = inv._build_tab("quest")
    check(q.size() == 1 and q[0]["key"] == "череп Калитина", "вкладка КВЕСТ видит трофей")
    # квестовый резерв: ОЗУ при взятом (но не сданном) квесте Попова — в КВЕСТ
    # и не продаётся; сдал — снова обычная добыча
    p.add_item("ОЗУ")
    check(inv._build_tab("loot").size() == 2, "ОЗУ без квеста — обычная добыча")
    p.flags["popov_ozu_taken"] = true
    check(Quests.fetch_reserved(p).has("ОЗУ"), "квест взят → ОЗУ в резерве")
    var lq: Array = inv._build_tab("quest")
    var in_quest := false
    for e in lq:
        if e["key"] == "ОЗУ":
            in_quest = "не продаётся" in str(e["sub"])
    check(in_quest and inv._build_tab("loot").size() == 1,
          "ОЗУ переехало в КВЕСТ (🔒) и пропало из ДОБЫЧИ")
    var sold: Array = Econ.sell_all(p, 1.0)
    check(p.has_item("ОЗУ") and "придержано" in str(sold[2]),
          "скупщик не забирает зарезервированное ОЗУ")
    p.flags["popov_ozu_done"] = true
    check(not Quests.fetch_reserved(p).has("ОЗУ")
          and inv._build_tab("loot").size() == 1 + int(p.has_item("ржавая руда")),
          "квест сдан → резерв снят, ОЗУ снова в ДОБЫЧЕ")
    # квестовые обереги — настоящие предметы: лежат в ОБЕРЕГАХ и надеваются
    p.add_item("оберег Ямполь")
    var tt: Array = inv._build_tab("trinket")
    check(tt.size() == 1 and tt[0]["key"] == "оберег Ямполь",
          "оберег Ямполь — во вкладке ОБЕРЕГИ, а не в КВЕСТ")
    Items.equip(p, "оберег Ямполь")
    check(p.equipment["trinket"] == "оберег Ямполь", "квестовый оберег надевается")
    Items.unequip(p, "trinket")
    p.remove_item("оберег Ямполь")
    # надеть/снять через вкладку
    inv.tab_i = 0
    inv._rebuild()
    inv._activate(inv.entries[0])                    # надеть меч
    check(p.equipment["weapon"] == "weapon_0_2", "ENTER во вкладке надевает")
    check(str(inv.entries[0]["action"]) == "unequip", "надетое — первым, со «снять»")
    inv._activate(inv.entries[0])                    # снять
    check(p.equipment["weapon"] == null, "повторный ENTER снимает")
    # скролл списка: 20 предметов, окно 8
    for i in range(20):
        p.add_item("предмет-заглушка %02d" % i)
    inv.tab_i = 7                                    # КВЕСТ
    inv.sel_i = 15
    inv._rebuild()
    check(inv.scroll > 0 and inv.sel_i - inv.scroll < inv.ROWS_VISIBLE,
          "список скроллится к выбранному (scroll=%d)" % inv.scroll)
    inv.free()
    # 5. HUD-панель: refresh собирает состояние, тост-сообщение попадает в text
    var hud := HudPanel.new()
    add_child(hud)
    hud.refresh("Тестовая Топь", "💾 сохранено")
    check("Тестовая Топь" in hud.text and "♥" in hud.text and "кринж" in hud.text
          and "сохранено" in hud.text, "HUD: локация, полосы и тост в состоянии")
    hud.free()
    # 6. NPC: длинная речь листается страницами, меню спрятано до конца
    var ns = load("res://scenes/NPC.tscn").instantiate()
    ns.kind = "yampol"
    add_child(ns)
    var long_lines: Array = []
    for i in range(12):
        long_lines.append("Ямполь вещает о сигма-энергии болота, часть %d. " % i + "бу".repeat(40))
    ns._speak(long_lines)
    check(ns._pages.size() > 1, "длинная речь NPC разбита на страницы")
    ns._rebuild_options()
    check(not ns.menu.visible, "пока речь листается — меню опций спрятано")
    ns._page_i = ns._pages.size() - 1
    ns._show_page()
    check(ns.menu.visible, "на последней странице меню вернулось")
    ns.free()
    # 7. бой: длинный лог (победа над боссом с кучей строк) тоже постраничный
    var ar = load("res://scenes/Battle.tscn").instantiate()
    ar.enemy = ["Манекен", 30, 5]
    add_child(ar)
    var big: Array = []
    for i in range(16):
        big.append("Строка исхода боя %d — " % i + "лут".repeat(25))
    ar._show_lines(big, func(): pass)
    check(ar._pages.size() > 1 and ar.log_label.text == ar._pages[0],
          "длинный боевой лог разбит на страницы (не налезает на статы)")
    ar._advance_message()      # дописать страницу
    ar._advance_message()      # следующая страница
    check(ar._page_i == 1 and ar.log_label.text == ar._pages[1],
          "ENTER листает боевой лог дальше")
    ar.free()


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
    # F2 дебаг-меню боёв (вынесено в OverworldDebug): открывается и вызывает бой
    ow.busy = false
    OverworldDebug.open_debug_battles(ow)
    check(ow.overlay.get_child_count() > 0, "F2 открывает дебаг-меню боёв")
    var dpanel: Node = ow.overlay.get_child(ow.overlay.get_child_count() - 1)
    OverworldDebug._on_debug_battle(0, ow, dpanel)   # кейс 0 — босс Калитин
    var spawned := false
    for c in ow.overlay.get_children():
        if c.has_method("_begin_bullets"):  # это Battle-арена
            spawned = true
    check(spawned, "F2 → вызов боя с боссом спавнит Battle-арену")
    # зум камеры и миникарта
    check(ow.cam.zoom == Vector2(2, 2), "камера приближена (зум x2)")
    check(is_instance_valid(ow.minimap) and ow.minimap.ow == ow,
          "миникарта подключена к надмиру")
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
    # читы: F1 работает, но HUD о нём молчит (секретная клавиша)
    var ow2 = load("res://scenes/Overworld.tscn").instantiate()
    add_child(ow2)
    ow2.set_process(false)
    ow2.load_location("base")
    check(not "F1" in ow2.hud.text, "HUD не рекламирует чит-меню")
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
    # расписание боссов (20-этажный цикл)
    dg._enter_room(5, false)
    check(dg.st.mobs.size() == 1 and str(dg.st.mobs[0].enemy[0]) == "Надзиратель Пекла",
          "этаж 5 — стражник Надзиратель")
    dg._enter_room(10, false)
    check(str(dg.st.mobs[0].enemy[0]) == "Магистр Пекла", "этаж 10 — мини-босс Магистр Пекла")
    var guards_ok := true
    for gf in [11, 13, 17, 19]:
        dg._enter_room(gf, false)
        if str(dg.st.mobs[0].enemy[0]) != "Надзиратель Пекла":
            guards_ok = false
    check(guards_ok, "этажи 11/13/17/19 — стражник каждые 2 этажа")
    dg._enter_room(15, false)
    check(str(dg.st.mobs[0].enemy[0]) == "Магистр Пекла", "этаж 15 — снова мини-босс")
    dg._enter_room(20, false)
    check(str(dg.st.mobs[0].enemy[0]) == "ТМ", "этаж 20 — ТМ")
    dg._enter_room(40, false)
    check(str(dg.st.mobs[0].enemy[0]) == "ТМ", "этаж 40 — ТМ снова (цикл повторяется)")
    # стражник: злее по урону, но тоньше (короткая жёсткая стычка)
    var guard: Array = dg._boss_enemy(11, "mini")
    check(int(guard[2]) > 8 + 5 and int(guard[1]) < 65 + 11 * 6,
          "стражник бьёт больнее, но HP меньше старого")
    # после ТМ: «Пепельные» твари жирнее и злее, чем до ТМ на том же прогрессе
    var pre_tm: Array = dg._mob_enemy(19)
    var post_tm: Array = dg._mob_enemy(21)
    check(str(post_tm[0]).begins_with("Пепельный "),
          "после ТМ мобы становятся «Пепельными»")
    check(int(post_tm[1]) > int(pre_tm[1]) and int(post_tm[2]) >= int(pre_tm[2]),
          "после ТМ мобы жирнее (%d>%d HP)" % [int(post_tm[1]), int(pre_tm[1])])
    check(dg._cycle_of(20) == 0 and dg._cycle_of(21) == 1 and dg._cycle_of(41) == 2,
          "циклы Пекла считаются по 20 этажей")
    # сундуки: с 10 этажа бывают двойные; после ТМ их стабильно больше;
    # золотые встречаются (шанс 5%+)
    seed(777)
    var saw_double := false
    var saw_gold := false
    var post_min := 99
    for _i in range(120):
        var r1: Dictionary = dg._gen_room(12, "plain")
        if r1.chests.size() >= 2:
            saw_double = true
        var r2: Dictionary = dg._gen_room(25, "plain")
        post_min = mini(post_min, r2.chests.size())
        for cc in r2.chests + r1.chests:
            if cc.get("gold", false):
                saw_gold = true
    check(saw_double, "с 10 этажа выпадают двойные сундуки")
    check(post_min >= 1, "после ТМ на этаже всегда есть сундук (их больше)")
    check(saw_gold, "золотые сундуки существуют")
    var tm_room: Dictionary = dg._gen_room(20, "tm")
    check(tm_room.chests[0].get("gold", false), "у ТМ сундук всегда золотой")
    # новые твари и золотой сундук имеют спрайты
    var news_ok := true
    for nm in ["Летучая Кринж-Мышь", "Магмовый Голем", "Горелый Сигма-Бес",
               "Призрак Забоя", "Лавовый Слизень", "Пепельный Магмовый Голем"]:
        if Sprites.mob_key(nm) == "mob":
            news_ok = false
    check(news_ok and Sprites.has("chest_gold"), "новые твари Пекла и золотой сундук со спрайтами")
    # водяное озеро: рыбы безвредны (не копят плевки)
    var wr: Dictionary = dg._gen_room(3, "water_lake")
    var water_ok: bool = wr.fish.size() >= 2
    for wf in wr.fish:
        if not wf.get("water", false):
            water_ok = false
    dg.st = wr
    dg.rooms[3] = wr
    dg.depth = 3
    dg.projectiles.clear()
    for _t in range(200):
        dg._fish_step(0.05)
    check(water_ok and dg.projectiles.is_empty(), "водяные рыбы — декор, не плюются")
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
