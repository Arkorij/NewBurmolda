extends Node2D
## Загрузочная сцена. При флаге --test уходит в headless-тесты,
## иначе (пока каркас) печатает статус загруженных данных.

func _ready() -> void:
    if "--test" in OS.get_cmdline_user_args():
        get_tree().call_deferred("change_scene_to_file", "res://tests/TestRunner.tscn")
        return
    if "--shot" in OS.get_cmdline_user_args():
        get_tree().call_deferred("change_scene_to_file", "res://tests/Shot.tscn")
        return
    get_tree().call_deferred("change_scene_to_file", "res://scenes/Title.tscn")
