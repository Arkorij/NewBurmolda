extends RefCounted
class_name MobThreats
## Угрозы рядовых мобов. По просьбе владельца — это БЫСТРЫЙ ПЛОТНЫЙ БУЛЛЕТ-ХЕЛЛ,
## но КОРОТКИЙ: фаза длится ~3-5с (см. _bh_dur мобов в battle_scene). Не «одна
## фигура за раз», а непрерывный поток одного паттерна — резко и динамично, но
## недолго и не запредельно.
##
## ВАЖНО: паттерн выбирается СЛУЧАЙНО из всего пула — НЕЗАВИСИМО от вида моба
## и от биома локации. Разнообразие важнее тематической привязки: один и тот же
## вид моба в разных боях может выдать любой из 25 паттернов. Биом при этом
## влияет ТОЛЬКО на рамку/душу (скольжение/теснота+ожог/вязкость/ветер —
## см. `battle_scene._biome_kind()`), но НЕ на выбор паттерна — эти два эффекта
## всегда независимы и складываются просто «в один и тот же бой».
##
## Сами атаки разложены по файлам `scripts/core/mob_patterns/` — по типу снаряда
## (этот файл только выбирает и диспетчит, не раздувается новыми паттернами):
##   orb_patterns.gd    — 15 паттернов, круглые пули `&"orb"`
##   cross_patterns.gd  — 3 паттерна, летающие кресты `&"cross"`
##   laser_patterns.gd  — 2 паттерна, тонкие быстрые лучи (add_hazard_zone)
##   rocket_patterns.gd — 2 паттерна, самонаводящиеся ракеты со взрывным следом
##   sniper_patterns.gd — 3 паттерна, почти-моментальные пули с мигающим origin
##
## Хочешь добавить 26-й паттерн — допиши имя в ARCHETYPES, класс в подходящий
## (или новый) файл модуля, и ветку в _make(). Больше никаких привязок не нужно.

const OrbPatterns = preload("res://scripts/core/mob_patterns/orb_patterns.gd")
const CrossPatterns = preload("res://scripts/core/mob_patterns/cross_patterns.gd")
const LaserPatterns = preload("res://scripts/core/mob_patterns/laser_patterns.gd")
const RocketPatterns = preload("res://scripts/core/mob_patterns/rocket_patterns.gd")
const SniperPatterns = preload("res://scripts/core/mob_patterns/sniper_patterns.gd")

const ARCHETYPES := [
    "spray", "rain", "spin", "burst", "gust",
    "cross", "zigzag", "pulse", "converge", "wall",
    "drizzle", "orbit", "snake", "corner", "mines",
    # ── доп. пул с другими типами снарядов ──
    "xrain", "xspray", "xspiral",              # летающие кресты
    "lasersweep", "lasercross",                # тонкие быстрые лучи
    "rockets", "rocketpair",                   # самонаводящиеся ракеты со следом
    "sniper", "sniperduo", "snipervolley",     # почти-моментальные пули с мигающим origin
]


static func sequence(_mob_key: String) -> Array:
    return [_make(ARCHETYPES[randi() % ARCHETYPES.size()])]


static func _make(arch: String) -> BossAttack:
    match arch:
        "rain": return OrbPatterns.Rain.new()
        "spin": return OrbPatterns.Spin.new()
        "burst": return OrbPatterns.Burst.new()
        "gust": return OrbPatterns.Gust.new()
        "cross": return OrbPatterns.Cross.new()
        "zigzag": return OrbPatterns.Zigzag.new()
        "pulse": return OrbPatterns.Pulse.new()
        "converge": return OrbPatterns.Converge.new()
        "wall": return OrbPatterns.Wall.new()
        "drizzle": return OrbPatterns.Drizzle.new()
        "orbit": return OrbPatterns.Orbit.new()
        "snake": return OrbPatterns.Snake.new()
        "corner": return OrbPatterns.Corner.new()
        "mines": return OrbPatterns.Mines.new()
        "xrain": return CrossPatterns.XRain.new()
        "xspray": return CrossPatterns.XSpray.new()
        "xspiral": return CrossPatterns.XSpiral.new()
        "lasersweep": return LaserPatterns.LaserSweep.new()
        "lasercross": return LaserPatterns.LaserCross.new()
        "rockets": return RocketPatterns.Rockets.new()
        "rocketpair": return RocketPatterns.RocketPair.new()
        "sniper": return SniperPatterns.Sniper.new()
        "sniperduo": return SniperPatterns.SniperDuo.new()
        "snipervolley": return SniperPatterns.SniperVolley.new()
        _: return OrbPatterns.Spray.new()
