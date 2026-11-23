extends Node
## Procedurally synthesized sound effects, engine loop and chiptune music. No asset files needed.

const RATE := 22050

var sounds := {}
var engine_stream: AudioStreamWAV
var _songs := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _want_song := ""
var _thread: Thread


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_make_sounds()
	engine_stream = _make_engine()
	apply_volumes()
	_thread = Thread.new()
	_thread.start(_compose_all)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func _setup_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func apply_volumes() -> void:
	if Save.data.is_empty() or AudioServer.get_bus_index("Music") == -1:
		return
	var m: float = Save.setting("music", 0.7)
	var s: float = Save.setting("sfx", 0.9)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(m, 0.0001)) - 6.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(s, 0.0001)))


func play(sname: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not sounds.has(sname):
		return
	for p in _pool:
		if not p.playing:
			p.stream = sounds[sname]
			p.pitch_scale = pitch
			p.volume_db = vol_db
			p.play()
			return


func music(song: String) -> void:
	_want_song = song
	if _songs.has(song):
		if _music.stream != _songs[song] or not _music.playing:
			_music.stream = _songs[song]
			_music.play()


func stop_music() -> void:
	_want_song = ""
	_music.stop()


# ------------------------------------------------------------------ synthesis helpers

static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func _sq(phase: float, duty := 0.5) -> float:
	return 1.0 if fposmod(phase, 1.0) < duty else -1.0


static func _tri(phase: float) -> float:
	var p := fposmod(phase, 1.0)
	return 4.0 * absf(p - 0.5) - 1.0


static func _note_hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Simple tone sweep with envelope. kind: 0 square, 1 triangle, 2 noise, 3 sine
func _tone(dur: float, f0: float, f1: float, kind := 0, vol := 0.5, decay := 4.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var noise := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += f / RATE
		var v := 0.0
		match kind:
			0: v = _sq(phase, 0.5)
			1: v = _tri(phase)
			2:
				if fposmod(phase, 1.0) < f / RATE * 1.5 or i % 2 == 0:
					noise = randf_range(-1, 1)
				v = noise
			3: v = sin(phase * TAU)
		var env := minf(1.0, i / (RATE * 0.004)) * exp(-decay * t)
		out[i] = v * vol * env
	return out


func _seq(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	if b.size() > out.size():
		out.resize(b.size())
	for i in b.size():
		out[i] += b[i]
	return out


func _make_sounds() -> void:
	sounds["click"] = _wav(_tone(0.05, 900, 900, 0, 0.25, 6))
	sounds["select"] = _wav(_seq([_tone(0.06, 660, 660, 0, 0.3, 3), _tone(0.1, 990, 990, 0, 0.3, 4)]))
	sounds["back"] = _wav(_seq([_tone(0.06, 660, 660, 0, 0.3, 3), _tone(0.1, 440, 440, 0, 0.3, 4)]))
	sounds["denied"] = _wav(_tone(0.25, 140, 110, 0, 0.3, 3))
	sounds["count"] = _wav(_tone(0.25, 523, 523, 0, 0.35, 5))
	sounds["go"] = _wav(_tone(0.7, 1046, 1046, 0, 0.35, 3))
	sounds["pickup"] = _wav(_seq([_tone(0.05, 784, 784, 0, 0.25, 2), _tone(0.05, 988, 988, 0, 0.25, 2), _tone(0.05, 1175, 1175, 0, 0.25, 2), _tone(0.12, 1568, 1568, 0, 0.25, 4)]))
	sounds["roll"] = _wav(_tone(0.04, 1200, 1200, 0, 0.15, 6))
	sounds["boost"] = _wav(_mix(_tone(0.6, 200, 900, 2, 0.35, 3), _tone(0.6, 150, 600, 0, 0.15, 3)))
	sounds["mini"] = _wav(_mix(_tone(0.35, 300, 1000, 2, 0.3, 4), _tone(0.3, 500, 1200, 1, 0.2, 4)))
	sounds["hit"] = _wav(_mix(_tone(0.5, 600, 80, 2, 0.6, 5), _tone(0.4, 120, 40, 3, 0.6, 5)))
	sounds["bump"] = _wav(_mix(_tone(0.15, 200, 60, 3, 0.6, 8), _tone(0.1, 800, 200, 2, 0.25, 10)))
	sounds["fire"] = _wav(_tone(0.3, 1400, 300, 0, 0.3, 4))
	sounds["drop"] = _wav(_tone(0.25, 220, 90, 1, 0.5, 6))
	sounds["shield"] = _wav(_mix(_tone(0.5, 600, 1200, 3, 0.3, 3), _tone(0.5, 900, 1800, 3, 0.2, 3)))
	sounds["pop"] = _wav(_tone(0.2, 1500, 200, 2, 0.4, 8))
	sounds["land"] = _wav(_tone(0.18, 140, 50, 3, 0.5, 7))
	sounds["lap"] = _wav(_seq([_tone(0.08, 784, 784, 0, 0.3, 2), _tone(0.08, 1046, 1046, 0, 0.3, 2), _tone(0.2, 1318, 1318, 0, 0.3, 3)]))
	sounds["final"] = _wav(_seq([_tone(0.1, 659, 659, 0, 0.3, 2), _tone(0.1, 659, 659, 0, 0.3, 2), _tone(0.1, 880, 880, 0, 0.3, 2), _tone(0.35, 1318, 1318, 0, 0.3, 2)]))
	sounds["finish"] = _wav(_seq([_tone(0.12, 523, 523, 0, 0.3, 1), _tone(0.12, 659, 659, 0, 0.3, 1), _tone(0.12, 784, 784, 0, 0.3, 1), _tone(0.5, 1046, 1046, 0, 0.3, 2)]))
	sounds["reward"] = _wav(_seq([_tone(0.07, 1046, 1046, 3, 0.4, 2), _tone(0.07, 1318, 1318, 3, 0.4, 2), _tone(0.07, 1568, 1568, 3, 0.4, 2), _tone(0.07, 2093, 2093, 3, 0.4, 2), _tone(0.4, 2637, 2637, 3, 0.3, 3)]))
	sounds["buy"] = _wav(_seq([_tone(0.05, 1318, 1318, 0, 0.25, 2), _tone(0.2, 1975, 1975, 0, 0.25, 4)]))


func _make_engine() -> AudioStreamWAV:
	# 105 Hz fundamental -> exactly 210 samples per period, so the loop is seamless.
	var period := 210
	var n := period * 12
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var ph := float(i % period) / period
		var saw := 2.0 * ph - 1.0
		var v := saw * 0.45 + _sq(ph * 2.0, 0.3) * 0.15 + sin(ph * TAU * 3.0) * 0.12
		v += sin(TAU * float(i) / n) * 0.05 * _sq(ph * 4.0)
		out[i] = v * 0.5
	return _wav(out, true)


# ------------------------------------------------------------------ music (runs on a thread)

func _compose_all() -> void:
	var menu := _compose(112, [60, 57, 53, 55], 1, 11)
	call_deferred("_song_ready", "menu", menu)
	var race := _compose(150, [57, 53, 48, 55], 0, 7)
	call_deferred("_song_ready", "race", race)
	var podium := _compose(132, [60, 65, 67, 60], 0, 3)
	call_deferred("_song_ready", "podium", podium)


func _song_ready(sname: String, stream: AudioStreamWAV) -> void:
	_songs[sname] = stream
	if _want_song == sname:
		music(sname)


func _compose(bpm: float, chords: Array, lead_kind: int, seed_val: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var step := 60.0 / bpm / 4.0  # 16th note
	var steps_per_chord := 32  # 2 bars
	var total_steps := steps_per_chord * chords.size() * 2  # play progression twice (2nd varied)
	var spl := int(step * RATE)
	var n := spl * total_steps
	var out := PackedFloat32Array()
	out.resize(n)
	# melody: pick chord tones / scale notes on a rhythmic grid
	var scale := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16]
	var rhythm := [1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0]
	var melody := []
	for s in total_steps:
		var chord: int = chords[(s / steps_per_chord) % chords.size()]
		if rhythm[s % 16] == 1:
			var deg: int = [0, 2, 4, 7, 4, 2][rng.randi() % 6] if rng.randf() < 0.7 else scale[rng.randi() % scale.size()]
			melody.append(chord + 12 + deg)
		else:
			melody.append(-1)
	var lead_phase := 0.0
	var bass_phase := 0.0
	var noise := 0.0
	for s in total_steps:
		var chord: int = chords[(s / steps_per_chord) % chords.size()]
		var bass_note: int = chord - 24 + (12 if s % 4 == 2 else 0)
		var bass_f := _note_hz(bass_note)
		var mel: int = melody[s]
		var mel_f := _note_hz(mel) if mel >= 0 else 0.0
		var arp_f := _note_hz(chord + [0, 4, 7, 12][s % 4] + (0 if chord % 12 == 9 or chord % 12 == 2 else 0))
		for j in spl:
			var i := s * spl + j
			var t := float(j) / spl
			var v := 0.0
			# bass (triangle)
			bass_phase += bass_f / RATE
			v += _tri(bass_phase) * 0.28 * (1.0 - t * 0.5)
			# lead
			if mel >= 0:
				lead_phase += mel_f / RATE
				var lv := _sq(lead_phase, 0.25) if lead_kind == 0 else _tri(lead_phase)
				v += lv * (0.11 if lead_kind == 0 else 0.2) * exp(-2.5 * t)
			# soft arpeggio
			v += sin(TAU * arp_f * float(i) / RATE) * 0.05 * exp(-4.0 * t)
			# drums
			var beat := s % 16
			if beat % 4 == 0:
				v += sin(TAU * (60.0 + 90.0 * exp(-30.0 * t)) * t * step) * 0.45 * exp(-8.0 * t)
			if lead_kind == 0 and (beat == 4 or beat == 12):
				if j % 2 == 0:
					noise = randf_range(-1, 1)
				v += noise * 0.18 * exp(-10.0 * t)
			if beat % 2 == 1:
				if j % 2 == 0:
					noise = randf_range(-1, 1)
				v += noise * 0.05 * exp(-30.0 * t)
			out[i] = clampf(v, -1.0, 1.0) * 0.8
	return _wav(out, true)
