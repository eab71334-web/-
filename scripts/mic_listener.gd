extends Node
## Measures microphone loudness (0..1) locally and detects "you spoke" segments.
## Nothing is recorded or sent anywhere; only duration + peak loudness of an utterance are used.

signal utterance(duration: float, peak: float)

var loudness := 0.0
var enabled := false
var _bus := -1
var _speaking := false
var _t := 0.0
var _peak := 0.0
var _gap := 0.0


func _ready() -> void:
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		return
	var sink := AudioServer.bus_count
	AudioServer.add_bus(sink)
	AudioServer.set_bus_name(sink, "MicSink")
	AudioServer.set_bus_volume_db(sink, -80.0)   # silent: avoids feedback
	AudioServer.add_bus(sink + 1)
	AudioServer.set_bus_name(sink + 1, "Mic")
	AudioServer.set_bus_send(sink + 1, "MicSink")
	var p := AudioStreamPlayer.new()
	p.stream = AudioStreamMicrophone.new()
	p.bus = "Mic"
	add_child(p)
	p.play()
	_bus = sink + 1
	enabled = true


func _process(delta: float) -> void:
	if not enabled or not Game.use_mic:
		loudness = 0.0
		return
	var db := maxf(AudioServer.get_bus_peak_volume_left_db(_bus, 0), AudioServer.get_bus_peak_volume_right_db(_bus, 0))
	var target := clampf(inverse_lerp(-45.0, -10.0, db), 0.0, 1.0)   # noise gate at -45 dB
	loudness = lerpf(loudness, target, 0.3)
	# speech segmentation (ignored while the monster itself is talking, to avoid hearing its own voice)
	if Time.get_ticks_msec() < Game.mute_mic_until:
		_speaking = false
		return
	if loudness > 0.22:
		_gap = 0.0
		if not _speaking:
			_speaking = true
			_t = 0.0
			_peak = 0.0
		_t += delta
		_peak = maxf(_peak, loudness)
	elif _speaking:
		_gap += delta
		_t += delta
		if _gap > 0.5:
			_speaking = false
			if _t > 0.45 and _t < 8.0:
				utterance.emit(_t, _peak)
