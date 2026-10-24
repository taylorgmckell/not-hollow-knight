class_name HealFx
extends Node2D
## Healing feedback on the player (playtest finding: a heal was hard to see).
##
## - While focusing: motes of light drift in towards the player and the glow
##   brightens as the focus fills.
## - When a mask is restored: a bright flash and an expanding ring.

const BURST_TIME := 0.45
const BURST_RADIUS := 70.0
const MOTES := 8
const GLOW_COLOR := Color(0.75, 0.95, 1.0)
## Centre of the player's body relative to the feet.
const CENTER := Vector2(0, -22)

## Seconds since the last heal landed; INF when none is playing.
var burst_age := INF
## Whether the most recent draw put anything on screen.
var showing := false

@onready var _player: Player = get_parent()
# Looked up directly: children are ready before the player sets its own @onready vars.
@onready var _health: PlayerHealth = get_parent().get_node(^"Health")


func _ready() -> void:
	z_index = 4
	_health.healed.connect(func() -> void:
		burst_age = 0.0
		queue_redraw())


func is_bursting() -> bool:
	return burst_age < BURST_TIME


func _process(delta: float) -> void:
	if is_bursting():
		burst_age += delta
	# Also redraw once after the effect ends, or its last frame (e.g. the glow
	# of a focus that was let go or hit) stays frozen on screen.
	if is_bursting() or _player.state_name == &"focus" or showing:
		queue_redraw()


func _draw() -> void:
	showing = _player.state_name == &"focus" or is_bursting()
	var progress := _health.focus_progress
	if _player.state_name == &"focus":
		_draw_gathering(progress)
	if is_bursting():
		_draw_burst(burst_age / BURST_TIME)


## Motes spiral in from a wide circle to the body as the focus fills.
func _draw_gathering(progress: float) -> void:
	var glow := GLOW_COLOR
	glow.a = 0.15 + 0.35 * progress
	draw_circle(CENTER, 18.0 + 10.0 * progress, glow)
	for i: int in MOTES:
		var angle := TAU * i / MOTES + progress * 2.5
		var radius := lerpf(56.0, 12.0, progress)
		var mote := GLOW_COLOR
		mote.a = 0.4 + 0.6 * progress
		draw_circle(CENTER + Vector2.from_angle(angle) * radius, 3.0, mote)


## A flash on the body and a ring racing outwards, both fading.
func _draw_burst(t: float) -> void:
	var fade := 1.0 - t
	var flash := Color(1, 1, 1, 0.8 * fade * fade)
	draw_circle(CENTER, 26.0, flash)
	var ring := GLOW_COLOR
	ring.a = fade
	draw_arc(CENTER, lerpf(20.0, BURST_RADIUS, t), 0.0, TAU, 32, ring, 6.0 * fade + 1.0)
