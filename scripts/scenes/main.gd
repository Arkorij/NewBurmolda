extends Node2D
## Загрузочная сцена. При флаге --test уходит в headless-тесты,
## иначе (пока каркас) печатает статус загруженных данных.

func _ready() -> void:
    # окно свободно растягивается (stretch=expand), но не меньше базовой рамки
    # вёрстки 640x480 — иначе экранам не хватит места
    get_window().min_size = Vector2i(640, 480)
    # за краями карт/рамок в широком окне виден clear color — пусть будет тёмным
    RenderingServer.set_default_clear_color(Color("#0b0a10"))
    if "--test" in OS.get_cmdline_user_args():
        get_tree().call_deferred("change_scene_to_file", "res://tests/TestRunner.tscn")
        return
    if "--shot" in OS.get_cmdline_user_args():
        get_tree().call_deferred("change_scene_to_file", "res://tests/Shot.tscn")
        return
    if "--audit" in OS.get_cmdline_user_args():
        get_tree().call_deferred("change_scene_to_file", "res://tests/Audit.tscn")
        return
    if "--play" in OS.get_cmdline_user_args():
        get_tree().call_deferred("change_scene_to_file", "res://tests/Play.tscn")
        return
    get_tree().call_deferred("change_scene_to_file", "res://scenes/Title.tscn")
