extends RefCounted
class_name Battle
## Модель одного боя. Порт burmolda/core/combat.py (Battle) 1:1.
## Все формулы/баланс — как в pygame-версии; числа из DataDB.balance.

const ATTACK_MISS := 0.08

var player: Player
var boss_key                    # String или null
var danger: int = 1             # опасность локации — скейлит HP/урон/награды
var ename: String
var enemy_hp: int
var enemy_max: int
var edmg: int
var art_key: String
var taunts                      # Array или null
var round_n: int = 0
var fear_uses: int = 0
var eq: Dictionary              # баффы надетой экипировки
var effects: Dictionary         # эффекты колец
var enemy_poison: int = 0
var enemy_frozen: bool = false
var _freeze_tried: bool = false   # мороз бросается 1 раз за ход (не за удар!)
var evade_sources: Array = []   # источники уворота от зелий (доли, на этот бой)
var potion_uses: Dictionary = {}  # зелье/роса -> сколько раз пили В ЭТОМ бою
var phase2: bool = false        # босс перешёл во 2-ю фазу (злой)
var finished: bool = false
var won                         # null / true / false
var fled: bool = false


func _init(p: Player, boss = null, enemy = null, dng: int = 1) -> void:
    player = p
    boss_key = boss
    danger = dng
    var e := _make_enemy(boss, enemy)
    ename = e[0]
    enemy_hp = e[1]
    enemy_max = e[1]
    edmg = e[2]
    art_key = str(e[3]) if e[3] != null else (str(boss) if boss != null else "battle")
    taunts = e[4]
    eq = Items.total_buffs(player)
    effects = Items.ring_effects(player)


func _make_enemy(boss, enemy) -> Array:
    var bosses: Dictionary = DataDB.bosses
    if boss != null and bosses.has(boss):
        var b: Array = bosses[boss]            # [name, base_hp, base_dmg, art_key, taunts]
        var mult := float(DataDB.balance.get("BOSS_HP_MULT", {}).get(boss, 1.0))
        # боссы — жирные: множитель + сильный скейл от уровня игрока
        var hp := int(int(b[1]) * mult) + player.level * 6
        var bdmg := int(b[2]) + int(player.level / 3.0)
        return [b[0], hp, bdmg, b[3], b[4]]
    if enemy == null:
        enemy = DataDB.enemies[randi() % DataDB.enemies.size()]
    var nm = enemy[0]
    var bhp := int(enemy[1])
    var bdmg := int(enemy[2])
    var hp := bhp + player.level * 2
    # хардовые локации: мобы заметно толще и злее (глубина сложности)
    var hard := maxi(0, danger - 2)
    hp = int(hp * (1.0 + 0.09 * hard))
    bdmg = int(bdmg * (1.0 + 0.05 * hard))
    hp = max(6, int(round(hp * randf_range(0.85, 1.2))))
    bdmg = max(1, int(round(bdmg * randf_range(0.8, 1.25))))
    return [nm, hp, bdmg, null, null]


func enemy_alive() -> bool:
    return enemy_hp > 0


func attack_power() -> int:
    return player.swag * 2 + player.level + int(Items.total_buffs(player).get("atk", 0))


func crit_chance() -> float:
    return 0.12 + (int(eq.get("crit", 0)) + int(effects.get("crit", 0))) / 100.0


func evade_chance() -> int:
    ## Шанс (%) что пуля пройдёт сквозь. Источники (Блок%, кольцо «calm»,
    ## каждое зелье) складываются МУЛЬТИПЛИКАТИВНО, как уклонение в Доте:
    ## total = 1 - Π(1 - s). Плюс жёсткий потолок 60%.
    var miss := 1.0
    var block := int(eq.get("block", 0))
    if block > 0:
        miss *= 1.0 - block / 100.0
    var calm := int(effects.get("calm", 0))
    if calm > 0:
        miss *= 1.0 - calm / 100.0
    for s in evade_sources:
        miss *= 1.0 - float(s)
    return clampi(int(round((1.0 - miss) * 100.0)), 0, 60)


func _potion_mult(key: String) -> float:
    ## Деградация зелий: каждый повторный приём В ЭТОМ бою слабее (×0.6).
    ## Новый бой — новый Battle — эффективность восстанавливается сама.
    return pow(0.6, int(potion_uses.get(key, 0)))


# ─────────────── фазы боссов ───────────────
const BOSS_PHASE2_LINES := {
    "kalitin": ["💢 КАЛИТИН ВХОДИТ В РАЖ!",
                "Кости гремят как барабаны — атаки чаще и злее!"],
    "tsizi": ["💨 ЦИЗИ РАЗДУВАЕТСЯ В УРАГАН!",
              "Шквал крепчает — держись за камыши, головастик!"],
    "zhizha": ["🟢 ЖИЖА БУРЛИТ И ПУЗЫРИТСЯ!",
               "Кислота льётся отовсюду!"],
    "overseer": ["🔥 НАДЗИРАТЕЛЬ ЩЁЛКАЕТ ПЛЕТЬЮ БЫСТРЕЕ!",
                 "«СМЕНА ПРОДЛЕВАЕТСЯ! РАБОТАЙ!»"],
    "pekl_master": ["📜 МАГИСТР ПЕКЛА ШТАМПУЕТ БЕЗ ОЧЕРЕДИ!",
                    "«Все талоны — недействительны! Ещё печатей!»"],
    "tm": ["👁 ТМ РАСКРЫВАЕТ ВСЕ ЧЕТЫРЕ ГЛАЗА.",
           "Тьма сгущается. «тм.»"],
}


func check_phase2() -> Array:
    ## Босс на ≤50% HP свирепеет (однократно). -> строки-анонс (пустые если нет).
    if boss_key != null and not phase2 and enemy_hp <= int(enemy_max * 0.5):
        phase2 = true
        edmg += 2
        return BOSS_PHASE2_LINES.get(boss_key, ["Босс свирепеет!"])
    return []


func _hit(dmg) -> Array:
    ## Нанести урон + применить эффекты колец. -> [итоговый_урон, [доп-строки]].
    dmg = max(1, int(dmg) + int(effects.get("power", 0)))
    enemy_hp -= dmg
    var extra: Array = []
    var ls := int(effects.get("lifesteal", 0))
    if ls > 0 and randf() < 0.55:
        var heal: int = max(2, int(dmg / float(max(1, 5 - min(ls, 3)))))
        player.heal(heal)
        extra.append("🩸 вампиризм +%d HP" % heal)
    var po := int(effects.get("poison", 0))
    if po > 0:
        enemy_poison += po
        extra.append("☠ яд наложен")
    # мороз: ОДИН бросок за ход игрока (иначе многоударные приёмы дают
    # почти гарантированную вечную заморозку); после заморозки флаг не
    # сбрасывается до следующей фазы врага → морозить можно не чаще, чем
    # через ход — боссы успевают отвечать.
    var fr := int(effects.get("freeze", 0))
    if fr > 0 and not enemy_frozen and not _freeze_tried:
        _freeze_tried = true
        if randf() < fr / 100.0:
            enemy_frozen = true
            extra.append("❄ ЗАМОРОЗКА — враг пропустит ход!")
    return [dmg, extra]


func poison_tick() -> int:
    _freeze_tried = false     # враг реально ходит → мороз снова доступен
    if enemy_poison > 0:
        var d := enemy_poison
        enemy_hp -= d
        enemy_poison = max(0, enemy_poison - 1)
        return d
    return 0


# ─────────────── FIGHT ───────────────
func attack() -> Array:
    if randf() < ATTACK_MISS:
        return ["«%s!» ...мимо! %s увернулся." % [_burmolzh(), ename]]
    var base := attack_power() + randi_range(1, 5)
    var crit := randf() < crit_chance()
    if crit:
        base = int(base * 1.8)
    var r := _hit(base)
    var tail := " КРИТ! 💥" if crit else ""
    var out := ["«%s!» ➜ %d урона 🔊%s" % [_burmolzh(), r[0], tail]]
    if not r[1].is_empty():
        out.append("  " + " · ".join(r[1]))
    return out


func roar() -> Array:
    if randf() < 0.60:
        var base := player.swag * 3 + player.level + randi_range(4, 14)
        var r := _hit(base)
        var out := ["МОЩНЫЙ РЁВ! %d урона 😤" % r[0]]
        if not r[1].is_empty():
            out.append("  " + " · ".join(r[1]))
        return out
    return ["Ты перестарался и закашлялся. Промах! 😵"]


func kalitin_fear() -> Array:
    var base := 24 + player.swag * 2 + randi_range(4, 10)
    var dmg: int = max(4, int(base * pow(0.6, fear_uses)))
    fear_uses += 1
    enemy_hp -= dmg
    var adapt := "" if fear_uses == 1 else "  (Калитин привыкает к страху...)"
    return ["Ты достаёшь паяльник и термофен...", _kalitin_fear_line(),
            "➜ %d урона по костям! 🔥%s" % [dmg, adapt]]


# ─────────────── ход врага ───────────────
func enemy_attack_lines() -> Array:
    round_n += 1
    var msgs: Array = []
    if taunts != null and taunts.size() > 0 and round_n % 3 == 0:
        msgs.append(taunts[randi() % taunts.size()])
    else:
        var t: String = DataDB.mob_attacks[randi() % DataDB.mob_attacks.size()]
        msgs.append(t.format({"name": ename}))
    if boss_key == "tsizi" and randf() < 0.3:
        msgs.append("💨 Цизи СДУВАЕТ тебя в камыши! Ты теряешь опору!")
    return msgs


func roll_enemy_hit() -> int:
    var hit := edmg + randi_range(0, player.level)
    if boss_key != null and randf() < 0.25:
        hit = int(hit * 1.6)
    return hit


func apply_hit(hit) -> Array:
    player.damage(hit)
    return ["-%d HP 💥" % hit]


func enemy_turn_instant() -> Array:
    var msgs := enemy_attack_lines()
    var hit := roll_enemy_hit()
    if boss_key != null and hit > edmg + player.level:
        msgs.append("☠️ УСИЛЕННЫЙ УДАР!")
    msgs.append_array(apply_hit(hit))
    return msgs


# ─────────────── ITEM / MERCY ───────────────
func heal_options() -> Array:
    ## Доступные предметы лечения: [[key, label], ...].
    var opts: Array = []
    if player.has_item("зелье свэга"):
        opts.append(["зелье свэга", "Зелье свэга (+2 свэг, +15 HP)"])
    if player.has_item("зелье уворота"):
        opts.append(["зелье уворота", "Зелье уворота (+уворот на бой; каждое следующее слабее)"])
    for entry in DataDB.food:
        var nm: String = entry[0]
        if player.has_item(nm):
            opts.append([nm, "%s (+%d HP)" % [nm, int(entry[1])]])
    opts.append(["__dew__", "Глотнуть росы (+8 HP)"])
    return opts


func use_item(key: String) -> Array:
    ## Зелья и роса ДЕГРАДИРУЮТ в течение боя (каждый приём слабее);
    ## еда — конечный ресурс, не деградирует.
    if key == "зелье свэга" and player.remove_item("зелье свэга"):
        var m := _potion_mult(key)
        potion_uses[key] = int(potion_uses.get(key, 0)) + 1
        var sw: int = max(0, int(round(2.0 * m)))
        var hl: int = max(1, int(round(15.0 * m)))
        player.swag += sw
        player.heal(hl)
        var tail := "" if m >= 1.0 else " (эффект слабеет)"
        return ["Зелье свэга: +%d свэг, +%d HP 🧪%s" % [sw, hl, tail]]
    if key == "зелье уворота" and player.remove_item("зелье уворота"):
        var m2 := _potion_mult(key)
        potion_uses[key] = int(potion_uses.get(key, 0)) + 1
        evade_sources.append(0.35 * m2)
        var tail2 := "" if m2 >= 1.0 else " (туман пожиже)"
        return ["Зелье уворота: тело как туман 🌫 (итого уворот %d%%)%s" % [evade_chance(), tail2]]
    for entry in DataDB.food:
        if key == entry[0] and player.remove_item(key):
            player.heal(int(entry[1]))
            return ["Ты съел: %s. +%d HP 🍖" % [key, int(entry[1])]]
    # роса бесплатна — поэтому деградирует жёстче всех
    var md := _potion_mult("__dew__")
    potion_uses["__dew__"] = int(potion_uses.get("__dew__", 0)) + 1
    var heal: int = max(1, int(round(8.0 * md)))
    player.heal(heal)
    var tail3 := "" if md >= 1.0 else " (роса выдыхается)"
    return ["Глоток росы: +%d HP 💧%s" % [heal, tail3]]


func flee() -> Array:
    ## -> [сбежал?, lines]. От боссов не сбежать.
    if boss_key != null:
        return [false, ["От босса не сбежать, головастик! 🚫"]]
    if randf() < 0.5:
        fled = true
        finished = true
        won = false
        return [true, ["Ты юркнул в камыши. Побег удался! 🏃"]]
    return [false, ["Камыши предали тебя. Побег провален! 🌾"]]


# ─────────────── завершение ───────────────
func resolve_victory() -> Array:
    # награды растут с опасностью локации — качаться в харде выгоднее
    var reward := 25 + player.level * 5 + danger * 6
    var cringe := 20 + danger * 3
    if boss_key != null:
        reward += 80
        cringe += 40
    player.burmolda += reward
    var ups := player.add_cringe(cringe)
    player.stats["battles_won"] = int(player.stats.get("battles_won", 0)) + 1
    var msgs := ["🏆 ПОБЕДА над %s!" % ename,
                 "+%d бурмолды, +%d кринж-опыта" % [reward, cringe]]
    match boss_key:
        "kalitin":
            player.flags["kalitin_defeated"] = true
            player.flags["boss_defeated"] = true
            player.add_item("череп Калитина")
            msgs.append("🎁 Трофей: череп Калитина (чисто для понта)")
        "tsizi":
            player.flags["tsizi_defeated"] = true
            player.add_item("карманный вентилятор")
            msgs.append("🎁 Трофей: карманный вентилятор (сдувает комаров)")
        "zhizha":
            player.flags["boss_defeated"] = true
    for lvl in ups:
        msgs.append("⬆ LEVEL UP! Теперь ты — %s (ур. %d)" % [player.rank(), lvl])
    msgs.append_array(Quests.on_kill(player, ename))
    Quests.refresh(player)
    finished = true
    won = true
    return msgs


func resolve_defeat() -> Array:
    player.hp = 1
    player.stats["deaths"] = int(player.stats.get("deaths", 0)) + 1
    finished = true
    won = false
    return ["Ты пал в жижу... но болото не отпускает так просто.",
            "Тина выталкивает тебя обратно с 1 HP. Дыши, головастик."]


# ─────────────── реплики ───────────────
func _burmolzh() -> String:
    var bank := DataDB.phrase("BURMOLZH")
    return bank[randi() % bank.size()] if not bank.is_empty() else "БУРМОЛЬ"


func _kalitin_fear_line() -> String:
    var bank := DataDB.phrase("KALITIN_FEAR")
    return bank[randi() % bank.size()] if not bank.is_empty() else "Калитин дрожит!"
