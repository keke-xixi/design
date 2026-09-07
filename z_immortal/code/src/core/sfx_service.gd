extends Node

## Lightweight procedural SFX (no asset pack required).

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -8.0
	add_child(_player)

func play_hit() -> void:
	_beep(520.0, 0.04, 0.22)

func play_kill() -> void:
	_beep(740.0, 0.06, 0.28)

func play_boss() -> void:
	_beep(160.0, 0.12, 0.35)
	# Second tick slightly later via deferred.
	get_tree().create_timer(0.08).timeout.connect(func() -> void: _beep(320.0, 0.1, 0.28))

func play_hurt() -> void:
	_beep(220.0, 0.08, 0.3)

func play_clear() -> void:
	_beep(660.0, 0.08, 0.28)
	get_tree().create_timer(0.1).timeout.connect(func() -> void: _beep(990.0, 0.1, 0.3))

func play_skill() -> void:
	_beep(880.0, 0.05, 0.2)

func play_wave() -> void:
	_beep(440.0, 0.1, 0.25)

func play_pickup() -> void:
	_beep(990.0, 0.035, 0.18)

func _beep(freq: float, duration: float, volume: float) -> void:
	var sample_rate := 22050
	var frames := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(sample_rate)
		var env := 1.0 - (t / duration)
		var sample := int(sin(TAU * freq * t) * env * volume * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	_player.stream = stream
	_player.play()
