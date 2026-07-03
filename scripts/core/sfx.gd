extends Node
## Autoload "Sfx": мягкие процедурные звуки (тише, с атакой — без щелчков).

var _player: AudioStreamPlayer
var _bank: Dictionary = {}


func _ready() -> void:
    _player = AudioStreamPlayer.new()
    _player.volume_db = -7.0
    add_child(_player)
    _bank = {
        "select": _tone(587.0, 0.05, 0.09),
        "hit": _tone(150.0, 0.09, 0.11),
        "hurt": _tone(98.0, 0.11, 0.12),
        "win": _tone(784.0, 0.20, 0.10),
    }


func play(sound: String) -> void:
    if _player != null and _bank.has(sound):
        _player.stream = _bank[sound]
        _player.play()


func _tone(freq: float, dur: float, vol: float) -> AudioStreamWAV:
    var sr := 22050
    var n := int(sr * dur)
    var atk := maxi(1, int(n * 0.18))
    var data := PackedByteArray()
    data.resize(n * 2)
    for i in n:
        var t := float(i) / sr
        var env := float(i) / atk if i < atk else 1.0 - float(i - atk) / float(maxi(1, n - atk))
        var s := sin(TAU * freq * t) * vol * env
        data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767))
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = sr
    w.stereo = false
    w.data = data
    return w
