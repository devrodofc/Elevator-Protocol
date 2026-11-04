extends Node
## Procedural ambience of the 3D reception (no audio files): fluorescent hum, crackles when the lights
## flicker, heartbeat while Marta is around, knocks in the elevator shaft and a low drone on the last day.
## Everything is synthesized into an AudioStreamGenerator on the SFX bus.

const MIX_RATE: float = 22050.0

## 0..1 levels, changed by the horror director (smoothed per sample).
var hum_level: float = 0.0
var drone_level: float = 0.0
var heartbeat_level: float = 0.0
var heartbeat_bpm: float = 62.0
## Master gain of the generator in dB (on top of the SFX bus).
var volume_db: float = -8.0:
	set(value):
		volume_db = value
		if _player:
			_player.volume_db = value

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _t: float = 0.0
var _hum: float = 0.0
var _drone: float = 0.0
var _beat: float = 0.0
var _beat_phase: float = 0.0
var _crackle: float = 0.0
var _knocks: Array[float] = [] # seconds until each queued knock
var _knock_env: float = 0.0
var _thump_env: float = 0.0
var _thump_t: float = 0.0
var _noise_lp: float = 0.0
## Desk phone ringing (double ring of an old office phone).
var ringing: bool = false
var _ring_t: float = 0.0
## Alarm siren seconds left / static (camera feed cut) seconds left.
var _alarm: float = 0.0
var _static: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.2
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.bus = &"SFX"
	_player.volume_db = volume_db
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


## Short electric crackle (lights flickering).
func crackle(strength: float = 1.0) -> void:
	_crackle = maxf(_crackle, clampf(strength, 0.0, 1.5))


## Muffled knocks from inside the shaft.
func knock(count: int = 3, spacing: float = 0.42) -> void:
	_knocks.clear()
	for i in count:
		_knocks.append(i * spacing + _rng.randf_range(-0.04, 0.06))


## Emergency alarm of the elevator (loud, alternating tones).
func alarm(seconds: float = 1.6) -> void:
	_alarm = maxf(_alarm, seconds)


## Burst of TV static (the elevator camera losing signal).
func static_burst(seconds: float = 0.6) -> void:
	_static = maxf(_static, seconds)


## A single deep impact (jump scares, the basement).
func thump(strength: float = 1.0) -> void:
	_thump_env = clampf(strength, 0.0, 1.5)
	_thump_t = 0.0


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var dt := 1.0 / MIX_RATE
	for i in frames:
		_t += dt
		_hum = lerpf(_hum, hum_level, 0.0004)
		_drone = lerpf(_drone, drone_level, 0.0002)
		_beat = lerpf(_beat, heartbeat_level, 0.0003)
		var s := 0.0
		# Fluorescent hum: 60 Hz and harmonics, with a slow wobble.
		if _hum > 0.001:
			var wobble := 1.0 + 0.15 * sin(TAU * 0.31 * _t)
			s += _hum * wobble * (0.05 * sin(TAU * 60.0 * _t) + 0.03 * sin(TAU * 120.0 * _t) \
				+ 0.018 * sin(TAU * 180.0 * _t + 0.4) + 0.008 * sin(TAU * 240.0 * _t))
		# Low drone: two detuned sines and dark noise.
		var noise := _rng.randf_range(-1.0, 1.0)
		_noise_lp = lerpf(_noise_lp, noise, 0.02)
		if _drone > 0.001:
			s += _drone * (0.07 * sin(TAU * 41.0 * _t) + 0.05 * sin(TAU * 43.3 * _t) + 0.35 * _noise_lp)
		# Electric crackle bursts.
		if _crackle > 0.001:
			if _rng.randf() < 0.08 * _crackle:
				s += _rng.randf_range(-0.3, 0.3) * _crackle
			s += noise * 0.04 * _crackle
			_crackle *= 0.99985
		# Heartbeat: "lub-dub" low thumps.
		if _beat > 0.001:
			_beat_phase += dt * heartbeat_bpm / 60.0
			if _beat_phase >= 1.0:
				_beat_phase -= 1.0
			s += _beat * (_heart(_beat_phase) + 0.6 * _heart(_beat_phase - 0.16))
		# Shaft knocks.
		for k in _knocks.size():
			_knocks[k] -= dt
			if _knocks[k] <= 0.0 and _knocks[k] > -dt * 1.5:
				_knock_env = 1.0
		if _knock_env > 0.0005:
			s += _knock_env * (0.5 * sin(TAU * 95.0 * _t) + 0.25 * _noise_lp * 3.0)
			_knock_env *= 0.9985
		# Phone: 0.4 s ring, 0.2 s pause, 0.4 s ring, 2 s silence; bell = two tones with a fast tremolo.
		if ringing:
			_ring_t += dt
			var r := fmod(_ring_t, 3.0)
			if r < 0.4 or (r > 0.6 and r < 1.0):
				var trem := 0.5 + 0.5 * sin(TAU * 22.0 * _t)
				s += 0.16 * trem * (sin(TAU * 440.0 * _t) + sin(TAU * 480.0 * _t))
		else:
			_ring_t = 0.0
		if _alarm > 0.0:
			_alarm -= dt
			var tone := 880.0 if fmod(_alarm, 0.36) < 0.18 else 660.0
			s += 0.13 * signf(sin(TAU * tone * _t)) * minf(_alarm * 4.0, 1.0)
		if _static > 0.0:
			_static -= dt
			s += noise * 0.22 * minf(_static * 5.0, 1.0)
		# Deep impact.
		if _thump_env > 0.0005:
			_thump_t += dt
			var f := lerpf(70.0, 32.0, minf(_thump_t * 2.0, 1.0))
			s += _thump_env * (0.8 * sin(TAU * f * _thump_t) + 0.3 * _noise_lp * 4.0)
			_thump_env *= 0.99975
		s = clampf(s, -0.95, 0.95)
		_playback.push_frame(Vector2(s, s))
	if not _knocks.is_empty() and _knocks.back() < -0.5:
		_knocks.clear()


## One heartbeat pulse at phase p (0..1): a short low sine with a fast decay.
func _heart(p: float) -> float:
	if p < 0.0 or p > 0.18:
		return 0.0
	var env := exp(-p * 38.0)
	return 0.55 * env * sin(TAU * 48.0 * p)


func stop() -> void:
	hum_level = 0.0
	drone_level = 0.0
	heartbeat_level = 0.0
	_knocks.clear()
	if _player:
		_player.stop()
