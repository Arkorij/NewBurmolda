extends Node
## Autoload "GameState": держит текущего игрока и сейв/лоад.

const SAVE_PATH := "user://save.json"

var player: Player


func new_game(name := "Головастик") -> void:
    player = Player.new(name)
    player.current_loc = DataDB.loc_index.get("start", "base")


func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
    if player == null:
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    f.store_string(JSON.stringify(player.to_dict()))


func load_game() -> bool:
    if not has_save():
        return false
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var data = JSON.parse_string(f.get_as_text())
    if data is Dictionary:
        player = Player.from_dict(data)
        return true
    return false
