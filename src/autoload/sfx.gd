extends Node
## Placeholder sound effects synthesized at startup (no audio files yet; real
## sounds come with the polish pass, M8). Each play gets a random pitch so
## repeated hits don't sound identical.

const MIX_RATE := 22050
const VOICES := 6
const PITCH_JITTER := 0.08

var _streams: Dictionary[StringName, AudioStreamWAV] = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_streams = {
		&"swing": _make(0.09, _swing),
		&"hit": _make(0.08, _hit),
		&"pogo": _make(0.12, _pogo),
	}
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)


func play(sound: StringName, volume_db := 0.0) -> void:
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
	player.play()


## Renders `duration` seconds of `voice(t, duration) -> float` to 16-bit mono.
func _make(duration: float, voice: Callable) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t := float(i) / MIX_RATE
		var sample := clampf(voice.call(t, duration), -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## Airy whoosh: noise swelling then fading.
func _swing(t: float, duration: float) -> float:
	var envelope := sin(PI * t / duration) * 0.35
	return _rng.randf_range(-1.0, 1.0) * envelope


## Thwack: a noise crack over a low thump, both decaying fast.
func _hit(t: float, _duration: float) -> float:
	var crack := _rng.randf_range(-1.0, 1.0) * exp(-t * 70.0)
	var thump := sin(TAU * 150.0 * t) * exp(-t * 35.0)
	return (crack * 0.6 + thump * 0.8)


## Pogo: the thwack plus a quick rising blip.
func _pogo(t: float, duration: float) -> float:
	var blip := sin(TAU * (500.0 + 900.0 * t / duration) * t) * exp(-t * 18.0) * 0.35
	return _hit(t, duration) * 0.8 + blip
