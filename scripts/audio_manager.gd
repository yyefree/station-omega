class_name AudioManager
extends Node

var _streams: Dictionary = {}
var _loops: Dictionary = {}
var _active: Dictionary = {}
var _last_played: Dictionary = {}
const _VOICE_LIMIT := 3
const _REPLAY_CD := { "hurt": 1.2, "hit": 0.12 }
const _pitch_varied := ["revolver", "rifle", "shotgun", "footstep", "land", "jump", "hit", "enemy_dead", "screech", "reload", "empty", "pickup", "plate", "heartbeat", "beast_roar", "beast_dead", "grunt", "splash", "insect"]

func _ready() -> void:
	_streams["revolver"] = _shot_pcm(0.5, {
		"hi_cut": 7200.0, "lo_cut": 320.0, "fall_time": 0.09, "decay": 20.0,
		"sub_freq": 92.0, "sub_amp": 0.6, "sub_decay": 14.0,
		"crack_t": 0.013, "crack_amp": 1.0, "mech": 0.09, "mech_amp": 0.3,
		"tail": 0.55, "gain": 1.0,
	})
	_streams["rifle"] = _shot_pcm(0.55, {
		"hi_cut": 5600.0, "lo_cut": 240.0, "fall_time": 0.12, "decay": 14.0,
		"sub_freq": 72.0, "sub_amp": 0.62, "sub_decay": 11.0,
		"crack_t": 0.012, "crack_amp": 0.9, "mech": 0.08, "mech_amp": 0.2,
		"tail": 0.65, "gain": 1.0,
	})
	_streams["shotgun"] = _shot_pcm(0.65, {
		"hi_cut": 3000.0, "lo_cut": 120.0, "fall_time": 0.16, "decay": 9.0,
		"sub_freq": 50.0, "sub_amp": 0.95, "sub_decay": 7.0,
		"crack_t": 0.02, "crack_amp": 0.75, "mech": 0.13, "mech_amp": 0.3,
		"tail": 0.75, "gain": 1.05,
	})
	_streams["footstep"] = _step_pcm(0.5)
	_streams["wind"] = _wind_pcm()
	_streams["hit"] = _impact_pcm(0.12, 150.0, 900.0, 0.9)
	_streams["penalty"] = _tone_buf(0.22, 190.0, 30.0, 0.5)
	_streams["pickup"] = _pickup_pcm()
	_streams["hurt"] = _hurt_pcm()
	_streams["reload"] = _reload_pcm()
	_streams["empty"] = _mech_stream([[1200.0, 1800.0]], 0.05, 50.0)
	_streams["gameover"] = _gameover_pcm()
	_streams["lever"] = _mech_stream([[900.0, 1500.0], [600.0, 1000.0]], 0.07, 35.0)
	_streams["door"] = _door_pcm()
	_streams["artifact"] = _artifact_pcm()
	_streams["victory"] = _victory_pcm()
	_streams["jump"] = _whoosh_pcm()
	_streams["land"] = _step_pcm(1.0)
	_streams["start"] = _start_pcm()
	_streams["click"] = _tone_buf(0.05, 900.0, 45.0, 0.3)
	_streams["select"] = _tone_buf(0.05, 1200.0, 60.0, 0.3)
	_streams["plate"] = _impact_pcm(0.18, 80.0, 500.0, 0.7)
	_streams["screech"] = _screech_pcm()
	_streams["enemy_dead"] = _enemy_dead_pcm()
	_streams["beast_roar"] = _screech_pcm()
	_streams["beast_dead"] = _enemy_dead_pcm()
	_streams["grunt"] = _impact_pcm(0.16, 100.0, 700.0, 0.6)
	_streams["splash"] = _impact_pcm(0.3, 120.0, 900.0, 0.5)
	_streams["insect"] = _whoosh_pcm()
	_streams["jungle_water"] = _wind_pcm()
	_streams["fall"] = _fall_pcm()
	_streams["heartbeat"] = _heartbeat_pcm()
	_streams["ambient"] = _ambient_pad_pcm()

func _pick_stream(name: String) -> AudioStream:
	var st = _streams.get(name)
	if st is Array and st.size() > 0:
		return st[randi() % st.size()]
	return st

func _ok_to_play(name: String) -> bool:
	var cd: float = _REPLAY_CD.get(name, 0.0)
	if cd <= 0.0:
		return true
	var now := Time.get_ticks_msec() / 1000.0
	var last: float = _last_played.get(name, -INF)
	if now - last < cd:
		return false
	_last_played[name] = now
	return true

func play(name: String, volume_db := -8.0) -> void:
	if not _streams.has(name):
		return
	if not _ok_to_play(name):
		return
	var players: Array = _active.get(name, [])
	if players.size() >= _VOICE_LIMIT:
		var oldest: AudioStreamPlayer = players.pop_front()
		oldest.stop()
		oldest.queue_free()
	var p := AudioStreamPlayer.new()
	p.stream = _pick_stream(name)
	p.volume_db = volume_db
	if name in _pitch_varied:
		p.pitch_scale = randf_range(0.93, 1.07)
	add_child(p)
	players.append(p)
	_active[name] = players
	p.finished.connect(_on_finished.bind(name, p))
	p.play()

func play3d(name: String, parent: Node3D, world_pos: Vector3, volume_db := -10.0) -> void:
	if not _streams.has(name):
		return
	if not _ok_to_play(name):
		return
	var players: Array = _active.get(name, [])
	if players.size() >= _VOICE_LIMIT:
		var oldest: AudioStreamPlayer3D = players.pop_front()
		oldest.stop()
		oldest.queue_free()
	var p := AudioStreamPlayer3D.new()
	p.stream = _pick_stream(name)
	p.volume_db = volume_db
	p.max_distance = 45.0
	p.unit_size = 7.0
	if name in _pitch_varied:
		p.pitch_scale = randf_range(0.93, 1.07)
	parent.add_child(p)
	p.global_position = world_pos
	players.append(p)
	_active[name] = players
	p.finished.connect(_on_finished3d.bind(name, p))
	p.play()

func _on_finished(name: String, p: AudioStreamPlayer) -> void:
	var players: Array = _active.get(name, [])
	players.erase(p)
	if players.is_empty():
		_active.erase(name)
	p.queue_free()

func _on_finished3d(name: String, p: AudioStreamPlayer3D) -> void:
	var players: Array = _active.get(name, [])
	players.erase(p)
	if players.is_empty():
		_active.erase(name)
	p.queue_free()

func play_loop(name: String, volume_db := -14.0) -> void:
	if not _streams.has(name):
		return
	if _loops.has(name):
		var lp: AudioStreamPlayer = _loops[name]
		if is_instance_valid(lp):
			lp.stop()
			lp.queue_free()
		_loops.erase(name)
	var p := AudioStreamPlayer.new()
	p.stream = _streams[name]
	p.volume_db = volume_db
	add_child(p)
	p.play()
	_loops[name] = p

func stop_loop(name: String) -> void:
	if not _loops.has(name):
		return
	var lp: AudioStreamPlayer = _loops[name]
	if is_instance_valid(lp):
		lp.stop()
		lp.queue_free()
	_loops.erase(name)

func _wav(buf: PackedFloat32Array, rate := 44100) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _blend(buf: PackedFloat32Array, t0: float, src: PackedFloat32Array, gain: float) -> void:
	var off := int(t0 * 44100)
	for i in src.size():
		var j := off + i
		if j >= 0 and j < buf.size():
			buf[j] += src[i] * gain

func _lp_filter(src: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var rate := 44100.0
	var a := 1.0 - exp(-TAU * cutoff / rate)
	var y := 0.0
	var out := PackedFloat32Array()
	out.resize(src.size())
	for i in src.size():
		y += a * (src[i] - y)
		out[i] = y
	return out

func _shot_pcm(dur: float, p: Dictionary) -> AudioStreamWAV:
	var rate := 44100
	var n := int(dur * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_usec()) & 0x7fffffff
	var lp := 0.0
	var hi_cut: float = p.get("hi_cut", 5000.0)
	var lo_cut: float = p.get("lo_cut", 300.0)
	var fall_time: float = p.get("fall_time", 0.1)
	var decay: float = p.get("decay", 24.0)
	var sub_freq: float = p.get("sub_freq", 80.0)
	var sub_amp: float = p.get("sub_amp", 0.5)
	var sub_decay: float = p.get("sub_decay", 15.0)
	var crack_t: float = p.get("crack_t", 0.01)
	var crack_amp: float = p.get("crack_amp", 0.9)
	var mech_t: float = p.get("mech", 0.09)
	var mech_amp: float = p.get("mech_amp", 0.25)
	var gain: float = p.get("gain", 1.0)
	var tail: float = p.get("tail", 0.4)
	for i in n:
		var t := float(i) / rate
		var x := rng.randf() * 2.0 - 1.0
		var fc: float = lerpf(hi_cut, lo_cut, clampf(t / maxf(fall_time, 0.001), 0.0, 1.0))
		var a := 1.0 - exp(-TAU * fc / rate)
		lp += a * (x - lp)
		var body := lp * exp(-t * decay)
		var sub := sin(TAU * sub_freq * t) * exp(-t * sub_decay) * sub_amp
		var crack := 0.0
		if t < crack_t:
			crack = x * exp(-t * 130.0) * crack_amp
		var mt := t - mech_t
		var mech := 0.0
		if mt > 0.0 and mt < 0.1:
			mech = (sin(TAU * 2900.0 * mt) * 0.5 + sin(TAU * 4300.0 * mt) * 0.3 + rng.randf() * 0.2) \
				* exp(-mt * 55.0) * mech_amp
		buf[i] = clampf((body + sub + crack + mech) * gain, -1.0, 1.0)
	if tail > 0.0:
		var echoes := [0.05, 0.12, 0.21]
		var egs := [0.28, 0.15, 0.08]
		for k in echoes.size():
			var delay := int(echoes[k] * rate)
			for i in range(delay, n):
				var src: float = buf[i - delay] * egs[k] * exp(-float(i - delay) / rate * 8.0)
				buf[i] = clampf(buf[i] + src, -1.0, 1.0)
	return _wav(buf, rate)

func _impact_pcm(dur: float, sub_freq: float, cutoff: float, amp: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(dur * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var x := rng.randf() * 2.0 - 1.0
		var a := 1.0 - exp(-TAU * cutoff / rate)
		lp += a * (x - lp)
		var body := lp * exp(-t * 30.0)
		var sub := sin(TAU * sub_freq * t) * exp(-t * 45.0) * 0.7
		buf[i] = clampf((body + sub) * amp, -1.0, 1.0)
	return _wav(buf, rate)

func _step_pcm(amp: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(0.14 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var x := rng.randf() * 2.0 - 1.0
		var fc: float = lerpf(1400.0, 200.0, clampf(t / 0.06, 0.0, 1.0))
		var a := 1.0 - exp(-TAU * fc / rate)
		lp += a * (x - lp)
		var body := lp * exp(-t * 32.0)
		var sub := sin(TAU * 58.0 * t) * exp(-t * 55.0) * 0.8
		var crack := 0.0
		if t < 0.008:
			crack = x * exp(-t * 160.0) * 0.7
		buf[i] = clampf((body * 0.7 + sub + crack) * amp, -1.0, 1.0)
	return _wav(buf, rate)

func _whoosh_pcm() -> AudioStreamWAV:
	var rate := 44100
	var n := int(0.18 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var x := rng.randf() * 2.0 - 1.0
		var fc: float = lerpf(300.0, 1800.0, clampf(t / 0.12, 0.0, 1.0))
		var a := 1.0 - exp(-TAU * fc / rate)
		lp += a * (x - lp)
		var env := sin(PI * clampf(t / 0.18, 0.0, 1.0))
		buf[i] = clampf(lp * env * 0.55, -1.0, 1.0)
	return _wav(buf, rate)

func _hurt_pcm() -> AudioStreamWAV:
	var rate := 44100
	var n := int(0.3 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var x := rng.randf() * 2.0 - 1.0
		var a := 1.0 - exp(-TAU * 700.0 / rate)
		lp += a * (x - lp)
		var groan := sin(TAU * (150.0 + 60.0 * t) * t) * exp(-t * 9.0)
		buf[i] = clampf(lp * exp(-t * 10.0) * 0.5 + groan * 0.55, -1.0, 1.0)
	return _wav(buf, rate)

func _enemy_dead_pcm() -> AudioStreamWAV:
	var rate := 44100
	var n := int(0.4 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var x := rng.randf() * 2.0 - 1.0
		var a := 1.0 - exp(-TAU * 500.0 / rate)
		lp += a * (x - lp)
		var body := lp * exp(-t * 18.0)
		var groan := sin(TAU * (220.0 - 140.0 * t) * t) * exp(-t * 7.0) * 0.5
		var crack := 0.0
		if t < 0.01:
			crack = x * exp(-t * 140.0) * 0.6
		buf[i] = clampf(body * 0.8 + groan + crack, -1.0, 1.0)
	return _wav(buf, rate)

func _mech_click(freqs: Array, dur: float) -> PackedFloat32Array:
	var rate := 44100
	var n := int(dur * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in n:
		var t := float(i) / rate
		var s := 0.0
		for f in freqs:
			s += sin(TAU * float(f) * t + float(f) * 0.7)
		s = s * 0.4 + rng.randf() * 0.25
		buf[i] = clampf(s * exp(-t * 40.0), -1.0, 1.0)
	return buf

func _mech_stream(stages: Array, dur: float, decay: float) -> AudioStreamWAV:
	var total := dur * stages.size()
	var buf := PackedFloat32Array()
	buf.resize(int(total * 44100))
	for k in stages.size():
		var seg := PackedFloat32Array()
		seg.resize(int(dur * 44100))
		var freqs: Array = stages[k]
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + k
		for i in seg.size():
			var t := float(i) / 44100.0
			var s := 0.0
			for f in freqs:
				s += sin(TAU * float(f) * t + float(f) * 0.7)
			s = s * 0.4 + rng.randf() * 0.25
			seg[i] = clampf(s * exp(-t * decay), -1.0, 1.0)
		_blend(buf, float(k) * dur, seg, 1.0)
	return _wav(buf, 44100)

func _reload_pcm() -> AudioStreamWAV:
	var rate := 44100
	var buf := PackedFloat32Array()
	buf.resize(int(0.62 * rate))
	_blend(buf, 0.0, _mech_click([2100.0, 3200.0], 0.06), 1.0)
	_blend(buf, 0.2, _mech_click([1400.0, 2600.0], 0.06), 0.8)
	_blend(buf, 0.46, _mech_click([1800.0, 2900.0], 0.05), 0.9)
	return _wav(buf, rate)

func _door_pcm() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.9 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / rate
		var x := rng.randf() * 2.0 - 1.0
		lp += (1.0 - exp(-TAU * 120.0 / rate)) * (x - lp)
		lp2 += (1.0 - exp(-TAU * 30.0 / rate)) * (lp - lp2)
		var sub := sin(TAU * 42.0 * t) * exp(-t * 3.0) * 0.45
		buf[i] = clampf(lp2 * exp(-t * 2.5) * 0.9 + sub, -1.0, 1.0)
	return _wav(buf, rate)

func _artifact_pcm() -> AudioStreamWAV:
	var rate := 44100
	var n := int(0.5 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / rate
		var f := 880.0 + sin(t * 22.0) * 30.0
		var s := sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.01 * t) * 0.18 + sin(TAU * f * 0.5 * t) * 0.2
		buf[i] = clampf(s * exp(-t * 6.0), -1.0, 1.0)
	return _wav(buf, rate)

func _pickup_pcm() -> AudioStreamWAV:
	var rate := 44100
	var n := int(0.25 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / rate
		var f := 660.0 if t < 0.12 else 990.0
		var s := sin(TAU * f * t) * 0.45 + sin(TAU * f * 2.0 * t) * 0.1
		buf[i] = clampf(s * exp(-t * 12.0), -1.0, 1.0)
	return _wav(buf, rate)

func _gameover_pcm() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.7 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / rate
		var f := 392.0 if t < 0.35 else 311.0
		var s := sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.1
		buf[i] = clampf(s * exp(-t * 4.0), -1.0, 1.0)
	return _wav(buf, rate)

func _start_pcm() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.35 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / rate
		var f := 523.0 if t < 0.15 else 784.0
		var s := sin(TAU * f * t) * 0.45 + sin(TAU * f * 3.0 * t) * 0.08
		buf[i] = clampf(s * exp(-t * 14.0), -1.0, 1.0)
	return _wav(buf, rate)

func _tone_buf(dur: float, freq: float, decay: float, amp: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / rate
		var s := sin(TAU * freq * t) * amp
		buf[i] = clampf(s * exp(-t * decay), -1.0, 1.0)
	return _wav(buf, rate)

func _screech_pcm() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.4 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 7.0)
		var f := 2300.0 + sin(t * 55.0) * 800.0 + sin(t * 130.0) * 250.0
		var s := sin(TAU * f * t) * 0.55 + sin(TAU * f * 2.03 * t) * 0.2 + rng.randf() * 0.2
		buf[i] = clampf(s * env * 0.6, -1.0, 1.0)
	return _wav(buf, rate)

func _fall_pcm() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.6 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var f: float = lerpf(900.0, 120.0, clampf(t / 0.55, 0.0, 1.0))
		var s := sin(TAU * f * t) * 0.5 + rng.randf() * 0.3
		var x := rng.randf() * 2.0 - 1.0
		lp += (1.0 - exp(-TAU * 400.0 / rate)) * (x - lp)
		var v := (s * exp(-t * 3.0) + lp * 0.3 * exp(-t * 6.0)) * 0.6
		buf[i] = clampf(v, -1.0, 1.0)
	return _wav(buf, rate)

func _heartbeat_pcm() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.62 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / rate
		var s := 0.0
		for th in [0.0, 0.3]:
			var lt: float = t - th
			if lt >= 0.0 and lt < 0.3:
				var env := exp(-lt * 20.0)
				s += (sin(TAU * 62.0 * lt) * 0.5 + sin(TAU * 95.0 * lt) * 0.28) * env
		buf[i] = clampf(s * 0.9, -1.0, 1.0)
	return _wav(buf, rate)

func _victory_pcm() -> AudioStreamWAV:
	var rate := 22050
	var n := int(1.2 * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var notes := [523.0, 659.0, 784.0, 1047.0]
	for i in n:
		var t := float(i) / rate
		var idx := clampi(int(t / 0.22), 0, 3)
		var lt := t - idx * 0.22
		var env := exp(-lt * 11.0) if lt >= 0.0 else 0.0
		var s := sin(TAU * notes[idx] * t) * 0.5 + sin(TAU * notes[idx] * 2.0 * t) * 0.12
		buf[i] = clampf(s * env, -1.0, 1.0)
	return _wav(buf, rate)

func _wind_pcm() -> AudioStreamWAV:
	var rate := 22050
	var dur := 4.0
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / rate
		lp += (1.0 - exp(-TAU * 300.0 / rate)) * (rng.randf() * 2.0 - 1.0 - lp)
		lp2 += (1.0 - exp(-TAU * 50.0 / rate)) * (lp - lp2)
		var wob := sin(TAU * 0.6 * t) * 0.4 + sin(TAU * 1.3 * t) * 0.25 + sin(TAU * 0.23 * t) * 0.3
		var v := clampf(lp2 * 0.6 + wob * 0.3, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 13000.0))
	var fade := int(rate * 0.5)
	for i in fade:
		var t := float(i) / fade
		var a := data.decode_s16(i * 2)
		var b := data.decode_s16((n - fade + i) * 2)
		var mix := int(a * t + b * (1.0 - t))
		data.encode_s16(i * 2, mix)
		data.encode_s16((n - fade + i) * 2, mix)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return wav

func _ambient_pad_pcm() -> AudioStreamWAV:
	var rate := 22050
	var dur := 8.0
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var notes := [130.81, 164.81, 196.0, 261.63, 329.63]
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for j in notes.size():
			var f: float = notes[j]
			var lfo := sin(TAU * (0.05 + 0.02 * j) * t) * 0.3 + 0.7
			v += sin(TAU * f * t) * lfo * 0.18
		var fade_in := clampf(t / 2.0, 0.0, 1.0)
		var fade_out := clampf((dur - t) / 2.0, 0.0, 1.0)
		v *= fade_in * fade_out
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 10000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return wav
