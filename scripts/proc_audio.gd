class_name ProcAudio
## Horror sounds generated in code (no audio files needed).

static var _cache := {}


static func get_sound(sound_name: String) -> AudioStreamWAV:
	if not _cache.has(sound_name):
		match sound_name:
			"drone": _cache[sound_name] = _drone()
			"heart": _cache[sound_name] = _heart()
			"breath": _cache[sound_name] = _breath()
			"thud": _cache[sound_name] = _thud()
			"ring": _cache[sound_name] = _ring()
			"click": _cache[sound_name] = _click()
			"creak": _cache[sound_name] = _creak()
			"slam": _cache[sound_name] = _slam()
			"static": _cache[sound_name] = _static()
			_: _cache[sound_name] = _sting()
	return _cache[sound_name]


static func _wav(s: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


static func _drone() -> AudioStreamWAV:
	var rate := 11025
	var n := rate * 6
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp = lp * 0.97 + randf_range(-1.0, 1.0) * 0.03
		s[i] = 0.30 * sin(TAU * 45.0 * t) + 0.22 * sin(TAU * 47.5 * t) + 0.08 * sin(TAU * 90.0 * t + 1.0) + lp * 0.6
	return _wav(s, rate, true)


static func _thump(t: float, at: float) -> float:
	var x := t - at
	if x < 0.0:
		return 0.0
	return sin(TAU * 58.0 * x * (1.0 - 0.5 * x)) * exp(-x * 16.0)


static func _heart() -> AudioStreamWAV:
	var rate := 11025
	var s := PackedFloat32Array()
	s.resize(rate)
	for i in rate:
		var t := float(i) / rate
		s[i] = 0.9 * (_thump(t, 0.0) + 0.75 * _thump(t, 0.3))
	return _wav(s, rate, true)


static func _breath() -> AudioStreamWAV:
	var rate := 11025
	var n := rate * 3
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var env := pow(0.5 - 0.5 * cos(TAU * t * 2.0 / 3.0), 2.0)
		lp = lp * 0.7 + randf_range(-1.0, 1.0) * 0.3
		s[i] = (lp * 0.7 + 0.15 * sin(TAU * 70.0 * t)) * env
	return _wav(s, rate, true)


static func _thud() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.6)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / rate
		s[i] = sin(TAU * 52.0 * t * (1.0 - t)) * exp(-t * 14.0) * 0.9 + randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.3
	return _wav(s, rate, false)


static func _sting() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 1.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		ph += TAU * (1100.0 * exp(-t * 2.2) + 120.0) / rate
		s[i] = tanh(2.5 * (sin(ph) + 0.5 * sin(ph * 2.03))) * 0.5 * exp(-t * 1.4) + randf_range(-1.0, 1.0) * exp(-t * 5.0) * 0.4
	return _wav(s, rate, false)


# ---- cinematic sounds -------------------------------------------------------
static func _ring() -> AudioStreamWAV:
	var rate := 11025
	var n := int(rate * 2.4)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / rate
		if t < 1.0 or (t > 1.3 and t < 2.3):
			s[i] = 0.35 * (sin(TAU * 440.0 * t) + sin(TAU * 480.0 * t)) * (0.6 + 0.4 * sin(TAU * 20.0 * t))
	return _wav(s, rate, false)


static func _click() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.08)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / rate
		s[i] = randf_range(-1.0, 1.0) * exp(-t * 80.0) * 0.6 + sin(TAU * 1800.0 * t) * exp(-t * 120.0) * 0.5
	return _wav(s, rate, false)


static func _creak() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 1.8)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		ph += TAU * (110.0 + 90.0 * t + 25.0 * sin(TAU * 3.0 * t)) / rate
		var saw := fmod(ph, TAU) / PI - 1.0
		var env := minf(t * 4.0, 1.0) * clampf((1.8 - t) * 2.0, 0.0, 1.0)
		s[i] = saw * 0.3 * (0.5 + 0.5 * sin(TAU * 7.0 * t)) * env + randf_range(-1.0, 1.0) * 0.04 * env
	return _wav(s, rate, false)


static func _slam() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.9)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / rate
		s[i] = randf_range(-1.0, 1.0) * exp(-t * 9.0) * 0.8 + sin(TAU * 45.0 * t) * exp(-t * 6.0)
	return _wav(s, rate, false)


static func _static() -> AudioStreamWAV:
	var rate := 11025
	var n := int(rate * 1.2)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / rate
		s[i] = randf_range(-1.0, 1.0) * 0.35 * (0.6 + 0.4 * sin(TAU * 30.0 * t))
	return _wav(s, rate, false)
