extends Node
## Autoload singleton "DataDB": грузит весь split-JSON из res://data/ в память.
## После сидера (tools/seed.py) эти JSON — источник истины.

var items: Dictionary = {}           # id -> item dict
var items_by_slot: Dictionary = {}   # slot -> Array[item]
var tiers: Array = []
var ring_effects: Dictionary = {}
var slot_names: Dictionary = {}
var stat_names: Dictionary = {}
var locations: Dictionary = {}       # id -> location dict
var loc_index: Dictionary = {}
var npcs: Dictionary = {}            # kind -> npc dict
var monsters: Dictionary = {}        # biome -> Array
var enemies: Array = []
var bosses: Dictionary = {}
var mob_attacks: Array = []
var food: Array = []
var phrases: Dictionary = {}         # BANK (UPPER) -> Array[String]
var quests: Dictionary = {}
var resources: Dictionary = {}       # name -> price
var balance: Dictionary = {}
var node_char_type: Dictionary = {}  # символ карты -> тип ноды
var node_info: Dictionary = {}       # тип -> {title, emoji, resources}
var sprite_pal: Dictionary = {}      # символ -> Color
var sprite_grids: Dictionary = {}    # ключ -> [строки 16x16]
var sprite_keywords: Array = []      # [[keyword, key], ...]
var sprite_npc_override: Dictionary = {}


func _ready() -> void:
    load_all()
    _setup_font()
    _setup_wasd()


func _setup_wasd() -> void:
    for bind in [["ui_up", KEY_W], ["ui_down", KEY_S], ["ui_left", KEY_A], ["ui_right", KEY_D]]:
        var ev := InputEventKey.new()
        ev.keycode = bind[1]
        InputMap.action_add_event(bind[0], ev)


func _setup_font() -> void:
    # добавляем моно-эмодзи как fallback к дефолтному шрифту → эмодзи в тексте
    # перестают быть квадратиками (и в Label, и в draw_string).
    var path := "res://assets/fonts/NotoEmoji-Regular.ttf"
    if not ResourceLoader.exists(path):
        return
    var emoji = load(path)
    if emoji is Font and ThemeDB.fallback_font != null:
        ThemeDB.fallback_font.fallbacks = [emoji]


func load_all() -> void:
    var slot_files := {"weapon": "swords", "armor": "armor", "shield": "shields",
                       "trinket": "trinkets", "ring": "rings"}
    for slot in slot_files:
        var arr: Array = _load("res://data/items/%s.json" % slot_files[slot])
        items_by_slot[slot] = arr
        for it in arr:
            items[it["id"]] = it
    tiers = _load("res://data/items/tiers.json")
    ring_effects = _load("res://data/items/ring_effects.json")
    slot_names = _load("res://data/items/slot_names.json")
    stat_names = _load("res://data/items/stat_names.json")

    loc_index = _load("res://data/locations/_index.json")
    for lid in loc_index.get("order", []):
        locations[lid] = _load("res://data/locations/%s.json" % lid)

    monsters = _load("res://data/monsters/biomes.json")
    enemies = _load("res://data/monsters/enemies.json")
    bosses = _load("res://data/monsters/bosses.json")
    mob_attacks = _load("res://data/monsters/mob_attacks.json")
    food = _load("res://data/monsters/food.json")

    var nidx: Dictionary = _load("res://data/npcs/_index.json")
    for kind in nidx.get("order", []):
        npcs[kind] = _load("res://data/npcs/%s.json" % kind)

    _load_phrases()
    quests = _load("res://data/quests/quests.json")
    resources = _load("res://data/resources.json")
    balance = _load("res://data/balance/combat.json")
    var nd: Dictionary = _load("res://data/nodes.json")
    node_char_type = nd.get("char_type", {})
    node_info = nd.get("info", {})

    var spr: Dictionary = _load("res://data/sprites.json")
    sprite_grids = spr.get("grids", {})
    sprite_keywords = spr.get("mob_keywords", [])
    sprite_npc_override = spr.get("npc_override", {})
    sprite_pal = {}
    var pal_raw: Dictionary = spr.get("pal", {})
    for ch in pal_raw:
        var rgb: Array = pal_raw[ch]
        sprite_pal[ch] = Color(int(rgb[0]) / 255.0, int(rgb[1]) / 255.0, int(rgb[2]) / 255.0)
    _inject_extra_sprites()


func _inject_extra_sprites() -> void:
    # спрайты, которых нет в оригинале: кузнец и вход в подземелье
    var extra := {
        "smith": [
            "................",
            ".....kkkkk......",
            "....ksssssk.....",
            "....sskkkss.....",
            "....sssssss.....",
            "...kSSSSSSSk....",
            "..kbbbbbbbbbk...",
            "..bBBBBBBBBBb...",
            "..bBBBBBBBBBbN..",
            "..bBBBBBBBBBkN..",
            "..bsBBBBBBsBk...",
            "..kBBBBBBBBBk...",
            "...BBB...BBB....",
            "...kk.....kk....",
            "..kk.......kk...",
            "................",
        ],
        "dungeon": [
            "................",
            "...kkkkkkkkkk...",
            "..kNNNNNNNNNNk..",
            ".kNNkkkkkkkkNNk.",
            ".kNkddddddddkNk.",
            ".kNkddddddddkNk.",
            ".kNkddddrrddkNk.",
            ".kNkdddrrrrdkNk.",
            ".kNkddrroorrdkk.",
            ".kNkdddrrrrdkNk.",
            ".kNkddddrrddkNk.",
            ".kNkddddddddkk..",
            ".kNNkddddddkk...",
            "..kNNNNNNNNk....",
            "...kkkkkkkk.....",
            "................",
        ],
        "teplichnaya": [   # огромная старая жаба со светящейся головой
            "................",
            "....eeeeeeee....",
            "...eyyyyyyyye...",
            "..eyyyyyyyyyye..",
            "..eywwyyyywwye..",
            "..eywkyyyykwye..",
            "..eyyyyyyyyyye..",
            "...eyykkkkyye...",
            "..GGgggggggGGG..",
            ".GGGGGGGGGGGGGG.",
            ".GGGGGGGGGGGGGG.",
            ".GGgGGGGGGGGgGG.",
            ".GGGGGGGGGGGGGG.",
            "..GG.GGGGGG.GG..",
            "..gg........gg..",
            "................",
        ],
        "zombie": [   # молчаливый гниющий бродяга (бурчит)
            "................",
            ".....zzzzz......",
            "....zzzzzzz.....",
            "....zwkzzrz.....",
            "....zzzzzzz.....",
            "....zzkkzzz.....",
            ".....zzzzz......",
            "....ddddddd.....",
            "...dddddddddd...",
            "...ddZddddZdd...",
            "...ddddddddd....",
            "....ddddddd.....",
            "....zz...zz.....",
            "....zz...zz.....",
            "...zz.....zz....",
            "................",
        ],
    }
    for k in extra:
        if not sprite_grids.has(k):
            sprite_grids[k] = extra[k]
    _inject_hell_sprites()

    print("[DataDB] %d items, %d locations, %d npcs, %d phrase-banks" % [
        items.size(), locations.size(), npcs.size(), phrases.size()])


func _inject_hell_sprites() -> void:
    ## Обитатели Адской Шахты (Пекло, «ТМ») — свои пиксель-арты в стиле игры.
    var hell := {
        "ash_bug": [   # Зольный Жук — серый панцирь, тлеющие точки
            "................",
            "....d......d....",
            ".....d....d.....",
            "...dNNNNNNNNd...",
            "..dNNdNNNNdNNd..",
            ".dNNNNNNNNNNNNd.",
            ".dNoNNNNNNNNoNd.",
            ".dNNNNwkkwNNNNd.",
            ".dNNNNNNNNNNNNd.",
            "..dNNoNNNNoNNd..",
            "...dNNNNNNNNd...",
            "....dddddddd....",
            "...d..d..d..d...",
            "..d...d..d...d..",
            "................",
            "................",
        ],
        "ember": [     # Уголёк-Живчик — живой огонёк
            "................",
            ".......o........",
            "......yo........",
            ".....oyyo.......",
            ".....oyyo.......",
            "....oyyyyo......",
            "....oryyro......",
            "...oyyyyyyo.....",
            "...oywkwkyo.....",
            "...oyyyyyyo.....",
            "...ooyykyoo.....",
            "....oyyyyo......",
            ".....oyyo.......",
            "....o.oo.o......",
            "................",
            "................",
        ],
        "magma_crab": [   # Магмовый Краб — панцирь из остывшей лавы
            "................",
            "....k......k....",
            "....w......w....",
            "..o..BBBBBB..o..",
            ".oo.BBBBBBBB.oo.",
            ".o.rBBBBBBBBr.o.",
            ".o.rrBBBBBBrr.o.",
            "..orrrrrrrrrro..",
            "..rrrwkrrwkrrr..",
            "...rrrrrrrrrr...",
            "....rrkkkkrr....",
            "...rr.r..r.rr...",
            "..rr..r..r..rr..",
            "................",
            "................",
            "................",
        ],
        "shade": [     # Тень Шахтёра — призрак с фонарём во лбу
            "................",
            ".....dddddd.....",
            "....dNNNNNNd....",
            "....dNyyNNNd....",
            "...dNNNNNNNNd...",
            "...dNwkNNwkNd...",
            "...dNNNNNNNNd...",
            "...dNNkkkkNNd...",
            "...dNNNNNNNNd...",
            "...dNNNNNNNNd...",
            "....dNNNNNNd....",
            "....dNdNNdNd....",
            ".....d.dd.d.....",
            "................",
            "................",
            "................",
        ],
        "lava_fish": [   # Лавовая Рыба — плюётся медленными шарами
            "................",
            "................",
            "................",
            ".....oo.........",
            "....oyyo....o...",
            "...oyyyyo..oo...",
            "..oyywkyyooyo...",
            "..oyyyyyyyyyo...",
            "...oyyyyo..oo...",
            "....oyyo....o...",
            ".....oo.........",
            "................",
            "................",
            "................",
            "................",
            "................",
        ],
        "overseer": [   # Надзиратель Пекла (мини-босс) — рогатый, с плетью
            ".....r....r.....",
            "....rr....rr....",
            "....kkkkkkkk....",
            "...kSSSSSSSSk...",
            "...kSwkSSwkSk...",
            "...kSSSSSSSSk...",
            "...kSSkkkkSSk...",
            "..kkNNNNNNNNkk..",
            ".kNNNNNNNNNNNNk.",
            ".kNNkNNNNNNkNNko",
            ".kNNkNNNNNNkNk.o",
            "..kkNNNNNNNNk.o.",
            "...kNNk..kNNk.o.",
            "...kkk....kkko..",
            "................",
            "................",
        ],
        "pekl_master": [   # Магистр Пекла (босс) — мантия и корона огня
            "....r..rr..r....",
            ".....rrrrrr.....",
            "....PPPPPPPP....",
            "...PPPPPPPPPP...",
            "...PPwkPPwkPP...",
            "...PPPPPPPPPP...",
            "...PPPkkkkPPP...",
            "..PPPPPPPPPPPP..",
            ".PPpPPPPPPPPpPP.",
            ".PPpPPPPPPPPpPP.",
            ".PPpPPrrrrPPpPP.",
            "..PPPPPPPPPPPP..",
            "..PPP......PPP..",
            "..PP........PP..",
            "................",
            "................",
        ],
        "tm": [   # ТМ — никто не знает, что это. Даже спрайт боится.
            "................",
            "....P......P....",
            "...PkkkkkkkkP...",
            "..PkkkkkkkkkkP..",
            ".PkkkkkkkkkkkkP.",
            ".PkkwwkkkkwwkkP.",
            ".PkkwwkkkkwwkkP.",
            ".PkkkkkkkkkkkkP.",
            ".PkkkkkkkkkkkkP.",
            ".PkkkrkkkkrkkkP.",
            "..PkkkrrrrkkkP..",
            "...PkkkkkkkkP...",
            "....PkkkkkkP....",
            "...P.k.kk.k.P...",
            "..P..........P..",
            "................",
        ],
        "chest": [   # сундук Пекла
            "................",
            "................",
            "...kkkkkkkkkk...",
            "..kbbbbbbbbbbk..",
            "..kbBBBBBBBBbk..",
            "..kbbbbbbbbbbk..",
            "..kkkkkkkkkkkk..",
            "..kBBByyyBBBBk..",
            "..kBBByyyBBBBk..",
            "..kBBBBBBBBBBk..",
            "..kBBBBBBBBBBk..",
            "..kBBBBBBBBBBk..",
            "..kkkkkkkkkkkk..",
            "................",
            "................",
            "................",
        ],
    }
    for k in hell:
        if not sprite_grids.has(k):
            sprite_grids[k] = hell[k]
    # маппинг имён (В НАЧАЛО списка — чтобы «краб»/«тень»/«рыба» не перехватили)
    var kw := [["зольный", "ash_bug"], ["уголёк", "ember"],
               ["магмовый краб", "magma_crab"], ["тень шахтёра", "shade"],
               ["лавовая рыба", "lava_fish"], ["надзиратель", "overseer"],
               ["магистр пекла", "pekl_master"], ["тм", "tm"]]
    kw.append_array(sprite_keywords)
    sprite_keywords = kw


func _load(path: String) -> Variant:
    var f := FileAccess.open(path, FileAccess.READ)
    assert(f != null, "DataDB: не открыть " + path)
    var data: Variant = JSON.parse_string(f.get_as_text())
    assert(data != null, "DataDB: битый JSON " + path)
    return data


func _load_phrases() -> void:
    var dir := DirAccess.open("res://data/phrases")
    if dir == null:
        return
    for fn in dir.get_files():
        if fn.ends_with(".json"):
            phrases[fn.get_basename().to_upper()] = _load("res://data/phrases/%s" % fn)


func item(id) -> Variant:
    return items.get(id)


func phrase(bank: String) -> Array:
    return phrases.get(bank.to_upper(), [])
