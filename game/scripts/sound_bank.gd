extends Node

const RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _pi := 0
var music_player: AudioStreamPlayer

func _ready() -> void:
	_build_all()
	for _i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.finished.connect(func():
		if music_player.stream != null and Game.music_on:
			music_player.play()
	)
	add_child(music_player)

func play_music(stage_idx: int) -> void:
	var track_num := (stage_idx % 5) + 1
	var path := "res://music/stage%d.mp3" % track_num
	if ResourceLoader.exists(path):
		var stream := load(path)
		music_player.stream = stream
		if Game.music_on:
			music_player.play()
		else:
			music_player.stop()
	else:
		music_player.stop()

func set_music_enabled(on: bool) -> void:
	if on:
		if music_player.stream != null and not music_player.playing:
			music_player.play()
	else:
		music_player.stop()

func stop_music() -> void:
	music_player.stop()

func play(id: String, vol_db: float = 0.0, pitch: float = 0.0) -> void:
	if not Game.sound_on:
		return
	var s: AudioStreamWAV = _streams.get(id)
	if s == null:
		return
	var p := _players[_pi]
	_pi = (_pi + 1) % _players.size()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + (pitch if id == "bounce" else 0.0) + randf_range(-0.03, 0.03)
	p.play()

func play_bounce(speed: float) -> void:
	play("bounce", clamp(-20.0 + speed * 2.0, -18.0, -2.0), randf_range(-0.18, 0.18))

# --- synthesis helpers ---

func _render(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := clampf(samples[i], -1.0, 1.0)
		var s16 := int(v * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	stream.data = data
	return stream

func _sine(f: float, t: float) -> float:
	return sin(TAU * f * t)

func _square(f: float, t: float) -> float:
	return sign(sin(TAU * f * t)) * 0.35

func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	for i in mini(a.size(), b.size()):
		out[i] = a[i] + b[i]
	return out

func _env_decay(length: int, power: float) -> PackedFloat32Array:
	var env := PackedFloat32Array()
	env.resize(length)
	for i in length:
		env[i] = pow(1.0 - float(i) / float(length), power)
	return env

func _build_all() -> void:
	_streams["dot"] = _synth_dot()
	_streams["bounce"] = _synth_bounce()
	_streams["finish"] = _synth_finish()
	_streams["power"] = _synth_power()
	_streams["star"] = _synth_star()
	_streams["hurt"] = _synth_hurt()

func _synth_dot() -> AudioStreamWAV:
	var len := int(RATE * 0.065)
	var s := PackedFloat32Array()
	s.resize(len)
	var env := _env_decay(len, 2.5)
	for i in len:
		var t := float(i) / float(RATE)
		var freq := lerpf(880.0, 1320.0, float(i) / float(len))
		s[i] = _sine(freq, t) * env[i] * 0.55 + _sine(freq * 2.0, t) * env[i] * 0.15
	return _render(s)

func _synth_bounce() -> AudioStreamWAV:
	var len := int(RATE * 0.12)
	var s := PackedFloat32Array()
	s.resize(len)
	var env := _env_decay(len, 3.0)
	for i in len:
		var t := float(i) / float(RATE)
		var freq := lerpf(140.0, 55.0, float(i) / float(len))
		s[i] = _sine(freq, t) * env[i] * 0.6
	var noise_len := int(RATE * 0.025)
	var ns := PackedFloat32Array()
	ns.resize(noise_len)
	var nenv := _env_decay(noise_len, 4.0)
	for i in noise_len:
		ns[i] = randf_range(-1.0, 1.0) * nenv[i] * 0.18
	var combined := PackedFloat32Array()
	combined.resize(len)
	for i in len:
		combined[i] = s[i]
	for i in mini(noise_len, len):
		combined[i] += ns[i]
	return _render(combined)

func _synth_finish() -> AudioStreamWAV:
	var notes := PackedFloat32Array([523.0, 659.0, 784.0, 1047.0])
	var note_dur := 0.1
	var total := int(RATE * note_dur * float(notes.size()))
	var s := PackedFloat32Array()
	s.resize(total)
	var env := _env_decay(total, 1.6)
	for i in total:
		var fi := int(float(i) / (RATE * note_dur))
		fi = mini(fi, notes.size() - 1)
		var t := float(i) / float(RATE)
		var freq := notes[fi]
		s[i] = _sine(freq, t) * env[i] * 0.5 + _sine(freq * 2.0, t) * env[i] * 0.12
	return _render(s)

func _synth_power() -> AudioStreamWAV:
	var len := int(RATE * 0.32)
	var s := PackedFloat32Array()
	s.resize(len)
	var env := _env_decay(len, 1.8)
	for i in len:
		var t := float(i) / float(RATE)
		var progress := float(i) / float(len)
		var freq := lerpf(280.0, 1400.0, progress)
		var shimmer := 1.0 + 0.4 * sin(t * 50.0)
		s[i] = _sine(freq, t) * env[i] * 0.5 * shimmer + _sine(freq * 1.5, t) * env[i] * 0.18
	return _render(s)

func _synth_star() -> AudioStreamWAV:
	var len := int(RATE * 0.28)
	var s := PackedFloat32Array()
	s.resize(len)
	var env := _env_decay(len, 2.0)
	for i in len:
		var t := float(i) / float(RATE)
		s[i] = (_sine(1568.0, t) + _sine(2093.0, t)) * env[i] * 0.28
	return _render(s)

func _synth_hurt() -> AudioStreamWAV:
	var len := int(RATE * 0.30)
	var s := PackedFloat32Array()
	s.resize(len)
	var env := _env_decay(len, 2.0)
	for i in len:
		var t := float(i) / float(RATE)
		var freq := lerpf(260.0, 110.0, float(i) / float(len))
		var trem := 1.0 + 0.6 * sin(t * 18.0)
		s[i] = _square(freq, t) * env[i] * 0.45 * trem + _sine(freq, t) * env[i] * 0.15
	return _render(s)
