# БУРМОЛДА — Godot 4.7 (перенос с pygame)

Перенос игры из `../burmolda-python` (pygame) на Godot 4. Логика портирована на
GDScript; весь контент лежит **данными** (split-JSON в `data/`), которые правятся
руками. Старая версия `burmolda-python` не трогается и остаётся играбельной.

## Запуск
- **Двойной клик** по `Играть.bat`, **или**
- Открыть `tools/godot/Godot_v4.7-stable_win64.exe` → Import → `project.godot` → ▶ (F5).

Управление: **стрелки** — ходьба/меню, **Enter/Space** — выбрать/дальше,
**Esc** — назад/сохранить. Подойди к букве на карте = поговорить с NPC;
жёлтая клетка = переход в другую локацию.

## Структура
```
data/            ← источник истины (JSON по категориям): items, locations, npcs,
                   phrases, monsters, quests, balance, resources
scripts/core/    ← портированная логика: player, items, battle, attacks, loot,
                   econ, npc_effects, data_db (autoload), game_state (autoload)
scripts/scenes/  ← сцены: main, title, overworld, battle_scene, npc_scene
scripts/ui/      ← soul_menu (меню в стиле Undertale)
scenes/          ← .tscn (тонкие: корень + скрипт)
tools/seed.py    ← разовый сидер: burmolda-python -> data/*.json
tools/godot/     ← портативный редактор Godot 4.7
tests/           ← headless-тесты логики
```

## Пересобрать данные из старого проекта
```
C:\Python314\python.exe tools\seed.py
```

## Прогнать тесты (headless)
```
tools\godot\Godot_v4.7-stable_win64_console.exe --headless --path . -- --test
```
Код возврата 1 при провале. Текущий статус: 22/22 зелёные.

## Что готово (Фаза 0–1)
Данные, ядро (бой/предметы/кольца/приёмы), вертикальный срез: титул, надмир с
одной большой картой, диалоги NPC (болтовня/покупка/выбор/продажа/обучение приёмам),
бой в стиле Undertale (динамическое меню приёмов от снаряги, кольца-эффекты,
bullet-hell), трофеи, левелап, сохранение.

## Дальше
- Фаза 2 — все 35 локаций, боссы, ноды добычи, постеры.
- Фаза 3 — инвентарь/экипировка, кузнец, подземелье, квесты.
- Фаза 4 — спрайты/анимации/звук (+шрифт с эмодзи).
- Фаза 5 — экспорт в `.exe` и в браузер.
