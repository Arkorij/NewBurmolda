# -*- coding: utf-8 -*-
"""
Data seeder (one-time / re-runnable): burmolda-python -> NewBurmolda/data/*.json

Reads the pygame-free data & logic modules of the old pygame game and dumps
them as split JSON files that the Godot version loads. After this runs, the
JSON in data/ is the source of truth (edit it directly).

Run with any Python 3.x (stdlib only), e.g.:
    C:\\Python314\\python.exe tools\\seed.py
"""
import sys
import os
import json
import types

HERE = os.path.dirname(os.path.abspath(__file__))
NEW_ROOT = os.path.dirname(HERE)                         # .../NewBurmolda
DATA = os.path.join(NEW_ROOT, "data")
OLD_ROOT = os.path.join(os.path.dirname(NEW_ROOT), "burmolda-python")


# --- safety net: stub pygame so any transitive import cannot fail the seeder ---
class _Dummy:
    def __getattr__(self, k):
        return _Dummy()

    def __call__(self, *a, **k):
        return _Dummy()

    def __getitem__(self, k):
        return _Dummy()

    def __iter__(self):
        return iter(())


_fake = types.ModuleType("pygame")
_fake.__getattr__ = lambda name: _Dummy()
sys.modules.setdefault("pygame", _fake)

sys.path.insert(0, OLD_ROOT)

from burmolda import items, phrases, quests, resources, minigames, config      # noqa: E402
from burmolda.pygame_app import locations, npc_data, sprites                    # noqa: E402
from burmolda.core import combat                                              # noqa: E402


def _write(relpath, obj):
    path = os.path.join(DATA, relpath)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


report = []

# ---------------------------- ITEMS ----------------------------
by_slot = {"weapon": [], "armor": [], "shield": [], "trinket": [], "ring": []}
for iid, it in sorted(items.ITEMS.items()):
    by_slot[it["slot"]].append(it)
_write("items/swords.json", by_slot["weapon"])
_write("items/armor.json", by_slot["armor"])
_write("items/shields.json", by_slot["shield"])
_write("items/trinkets.json", by_slot["trinket"])
_write("items/rings.json", by_slot["ring"])
_write("items/tiers.json",
       [{"prefix": p, "mult": m, "color": c, "price": pr} for (p, m, c, pr) in items.TIERS])
_write("items/slot_names.json", items.SLOT_NAMES)
_write("items/stat_names.json", items.STAT_NAMES)
_write("items/ring_effects.json",
       {k: {"name": v[0], "desc": v[1]} for k, v in items.RING_EFFECTS.items()})
total_items = sum(len(v) for v in by_slot.values())
report.append(("items", total_items))
report.append(("  swords", len(by_slot["weapon"])))
report.append(("  rings", len(by_slot["ring"])))

# -------------------------- LOCATIONS --------------------------
order = list(locations.LOCATIONS.keys())
for lid, loc in locations.LOCATIONS.items():
    _write("locations/%s.json" % lid, loc)
_write("locations/_index.json", {"start": locations.START_ID, "order": order})
report.append(("locations", len(order)))

# -------------------------- MONSTERS ---------------------------
_write("monsters/biomes.json", locations.MONSTERS)
_write("monsters/enemies.json", minigames.ENEMIES)
_write("monsters/bosses.json", minigames.BOSSES)
_write("monsters/mob_attacks.json", minigames.MOB_ATTACKS)
_write("monsters/food.json", phrases.FOOD)

# --------------------------- PHRASES ---------------------------
phrase_banks = 0
for name, val in vars(phrases).items():
    if name.isupper() and isinstance(val, list) and val and all(isinstance(x, str) for x in val):
        _write("phrases/%s.json" % name.lower(), val)
        phrase_banks += 1
report.append(("phrase_banks", phrase_banks))

# ----------------------------- NPCS ----------------------------
FOOD_NAMES = {n for n, _h, _c in phrases.FOOD}
_NAMED = {
    npc_data.gain_swag: "gain_swag",
    npc_data.bless_hp: "bless_hp",
    npc_data.heal_full: "heal_full",
    npc_data.sell_potion: "sell_potion",
    npc_data.feast: "feast",
    npc_data.beef_up: "beef_up",
    npc_data.ladushki: "ladushki",
    npc_data.vozduhan_hint: "vozduhan_hint",
    npc_data.vozduhan_bet: "vozduhan_bet",
}


def resolve_fn(fn):
    """Python effect function -> {effect: id, arg?: value} for GDScript reimpl."""
    if fn in _NAMED:
        return {"effect": _NAMED[fn]}
    clo = getattr(fn, "__closure__", None)
    if clo:                                   # give_food / give_item closure
        arg = clo[0].cell_contents
        eid = "give_food" if arg in FOOD_NAMES else "give_item"
        return {"effect": eid, "arg": arg}
    raise ValueError("unknown effect fn: %r" % (fn,))


def conv_option(opt):
    o = dict(opt)
    if callable(o.get("effect")):
        o.update(resolve_fn(o.pop("effect")))
    if callable(o.get("fn")):
        o.update(resolve_fn(o.pop("fn")))
    return o


for kind, cfg in npc_data.NPCS.items():
    out = dict(cfg)
    out["kind"] = kind
    out["options"] = [conv_option(o) for o in cfg["options"]]
    _write("npcs/%s.json" % kind, out)
_write("npcs/_index.json", {"order": list(npc_data.NPCS.keys())})
report.append(("npcs", len(npc_data.NPCS)))

# --------------------- QUESTS / RESOURCES ----------------------
_write("quests/quests.json", quests.QUESTS)
_write("resources.json", resources.RESOURCES)
report.append(("quests", len(quests.QUESTS)))
report.append(("resources", len(resources.RESOURCES)))

# ------------------------------ NODES --------------------------
# ноды добычи: символ→тип и тип→(заголовок, эмодзи, ресурсы)
_write("nodes.json", {
    "char_type": locations.NODE_TYPE,
    "info": {t: {"title": v[0], "emoji": v[1], "resources": v[2]}
             for t, v in locations.NODE_INFO.items()},
})
report.append(("node_types", len(locations.NODE_INFO)))

# ----------------------------- SPRITES -------------------------
# оригинальные пиксель-арты: палитра, 16x16 сетки, маппинг имён -> ключ
_write("sprites.json", {
    "pal": {k: list(v) for k, v in sprites.PAL.items()},
    "grids": sprites._GRIDS,
    "mob_keywords": [list(t) for t in sprites._MOB_KEYWORDS],
    "npc_override": sprites._NPC_SPRITE,
})
report.append(("sprite_grids", len(sprites._GRIDS)))

# ---------------------------- BALANCE --------------------------
# old-runtime paths (contain an absolute user path) are irrelevant to Godot,
# which saves to user://  — drop them so nothing machine-specific is baked in.
_SKIP_CFG = {"SAVE_DIR", "SAVE_FILE"}
balance = {k: v for k, v in vars(config).items()
           if k.isupper() and k not in _SKIP_CFG
           and isinstance(v, (int, float, str, list, dict, bool))}
balance["BOSS_HP_MULT"] = combat.BOSS_HP_MULT
balance["ATTACK_MISS"] = combat.Battle.ATTACK_MISS
_write("balance/combat.json", balance)

# ----------------------------- REPORT --------------------------
print("=== SEED OK ===")
for name, n in report:
    print("  %-14s %s" % (name, n))
print("  start_id       %s" % locations.START_ID)
assert total_items == 118, "expected 118 items, got %d" % total_items
assert len(order) >= 30, "too few locations: %d" % len(order)
assert len(npc_data.NPCS) >= 10, "too few npcs"
print("data ->", DATA)
