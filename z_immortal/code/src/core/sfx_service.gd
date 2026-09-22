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

func play_dash() -> void:
	# Soft cyan whoosh — land dust beat, not a skill ping.
	_beep(380.0, 0.05, 0.14)
	get_tree().create_timer(0.04).timeout.connect(func() -> void: _beep(520.0, 0.06, 0.12))

func play_start() -> void:
	# Short two-tone chime — 开战 ritual, not a hit.
	_beep(560.0, 0.05, 0.16)
	get_tree().create_timer(0.055).timeout.connect(func() -> void: _beep(820.0, 0.07, 0.22))

func play_skill_miss() -> void:
	# Soft low whoosh — empty ring-slash must not sound like a hit.
	_beep(260.0, 0.07, 0.12)

func play_deny() -> void:
	# Muted ash tick — empty pill / CD dock grey flash; not miss whoosh or jade sip.
	_beep(170.0, 0.04, 0.1)
	get_tree().create_timer(0.035).timeout.connect(func() -> void: _beep(130.0, 0.045, 0.07))

func play_ring_hit() -> void:
	# Bright double-tick — confirms 环斩 connected.
	_beep(920.0, 0.04, 0.22)
	get_tree().create_timer(0.045).timeout.connect(func() -> void: _beep(1180.0, 0.05, 0.26))

func play_yingren() -> void:
	# Warm-steel punish — mid clang then brief shimmer; not hit/ring ping.
	_beep(460.0, 0.05, 0.26)
	get_tree().create_timer(0.048).timeout.connect(func() -> void: _beep(680.0, 0.06, 0.22))

func play_heal_pressure() -> void:
	# Soft steel footfall — 愈后外门近身 land; cooler/lower than 迎刃 punish.
	_beep(300.0, 0.055, 0.2)
	get_tree().create_timer(0.06).timeout.connect(func() -> void: _beep(520.0, 0.045, 0.16))

func play_pill() -> void:
	# Soft jade sip — 服丹翠闪; rising calm, not heal-pressure steel / pickup ping.
	_beep(540.0, 0.045, 0.18)
	get_tree().create_timer(0.055).timeout.connect(func() -> void: _beep(720.0, 0.055, 0.2))
	get_tree().create_timer(0.12).timeout.connect(func() -> void: _beep(900.0, 0.05, 0.14))

func play_heal_enter() -> void:
	# Calm jade well — 愈地 enter; softer/lower than 服丹 sip, not steel pressure.
	_beep(380.0, 0.06, 0.15)
	get_tree().create_timer(0.07).timeout.connect(func() -> void: _beep(540.0, 0.07, 0.13))

func play_ash_enter() -> void:
	# Crimson ash sting — 煞地 enter; descending red, not jade well / boss telegraph.
	_beep(280.0, 0.055, 0.18)
	get_tree().create_timer(0.06).timeout.connect(func() -> void: _beep(195.0, 0.07, 0.14))

func play_mist_enter() -> void:
	# Soft violet fog — 滞地 enter; mid purple drift, not jade well / crimson ash.
	_beep(320.0, 0.07, 0.14)
	get_tree().create_timer(0.08).timeout.connect(func() -> void: _beep(440.0, 0.08, 0.12))

func play_crisis_enter() -> void:
	# Hot red pulse — crisis ≤30% enter once; sharper than ash sting, not hurt thud.
	_beep(420.0, 0.05, 0.22)
	get_tree().create_timer(0.07).timeout.connect(func() -> void: _beep(280.0, 0.075, 0.18))

func play_elite_land() -> void:
	# Warm-gold crown drop — louder than trash land, softer than boss thud.
	_beep(500.0, 0.055, 0.24)
	get_tree().create_timer(0.055).timeout.connect(func() -> void: _beep(760.0, 0.07, 0.26))

func play_break() -> void:
	# Warm-gold 破绽 open — punish window chime, not clear victory / elite drop.
	_beep(540.0, 0.05, 0.26)
	get_tree().create_timer(0.055).timeout.connect(func() -> void: _beep(780.0, 0.06, 0.24))
	get_tree().create_timer(0.12).timeout.connect(func() -> void: _beep(940.0, 0.05, 0.18))

func play_sheath() -> void:
	# Warm-gold「收刀」— descending sheath settle; not clear victory / 破绽 open.
	_beep(720.0, 0.05, 0.24)
	get_tree().create_timer(0.065).timeout.connect(func() -> void: _beep(460.0, 0.085, 0.22))

func play_telegraph() -> void:
	# Danger warn — orange telegraph start; low→mid, not gold 破绽 / boss land.
	_beep(220.0, 0.065, 0.24)
	get_tree().create_timer(0.07).timeout.connect(func() -> void: _beep(340.0, 0.075, 0.2))

func play_hare_peck_warn() -> void:
	# Soft teal chirp — 灵兔侧啄 crescent; not steel blade / orange boss warn.
	_beep(640.0, 0.04, 0.15)
	get_tree().create_timer(0.042).timeout.connect(func() -> void: _beep(860.0, 0.04, 0.13))

func play_hare_peck() -> void:
	# Teal peck snap on hop-in — short bite after the warn.
	_beep(740.0, 0.035, 0.17)

func play_blade_warn() -> void:
	# Cold steel scrape — 弟子亮刃 draw; mid, not teal hare chirp.
	_beep(420.0, 0.045, 0.18)
	get_tree().create_timer(0.05).timeout.connect(func() -> void: _beep(580.0, 0.04, 0.15))

func play_blade_thrust() -> void:
	# Short steel stab — thrust after 亮刃 plant.
	_beep(520.0, 0.04, 0.2)

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
