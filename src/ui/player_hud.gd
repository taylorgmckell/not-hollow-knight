class_name PlayerHud
extends CanvasLayer
## Top-left HUD: the Soul vessel and a row of masks. The vessel shows the
## Soul draining while focusing. A lost mask flashes; a healed mask pops
## (grows and glows) so it's clear which one came back.

const ORIGIN := Vector2(28, 24)
const VESSEL_RADIUS := 40.0
const MASK_SIZE := Vector2(34, 44)
const MASK_GAP := 12.0
const FULL_COLOR := Color(0.95, 0.96, 1.0)
const EMPTY_COLOR := Color(1, 1, 1, 0.18)
const SOUL_COLOR := Color(0.9, 0.93, 1.0)
const OUTLINE := Color(0.05, 0.06, 0.08)
const FLASH_TIME := 0.25
const POP_TIME := 0.5
const POP_COLOR := Color(0.75, 0.95, 1.0)

var _player: Player
var _canvas := Control.new()
var _flash := 0.0
## Index of the mask that was just healed, and how long its pop has run.
var _pop_index := -1
var _pop_age := INF


func _init(player: Player) -> void:
	_player = player
	layer = 45
	name = "PlayerHud"


func _ready() -> void:
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	_player.health.damaged.connect(func(_a: int, _f: Vector2) -> void: _flash = FLASH_TIME)
	_player.health.healed.connect(func() -> void:
		_pop_index = _player.health.masks - 1
		_pop_age = 0.0)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_pop_age += delta
	_canvas.queue_redraw()


func _draw_hud() -> void:
	var health := _player.health
	var center := ORIGIN + Vector2(VESSEL_RADIUS, VESSEL_RADIUS)
	# Soul vessel: fill rises with Soul; while focusing, the part being spent fades.
	var fraction := float(health.soul) / PlayerHealth.SOUL_MAX
	var draining := float(_player.tuning.focus_cost) / PlayerHealth.SOUL_MAX * health.focus_progress
	_canvas.draw_circle(center, VESSEL_RADIUS + 3.0, OUTLINE)
	_fill_circle(center, VESSEL_RADIUS, fraction, SOUL_COLOR * Color(1, 1, 1, 0.35))
	_fill_circle(center, VESSEL_RADIUS, maxf(fraction - draining, 0.0), SOUL_COLOR)
	_canvas.draw_arc(center, VESSEL_RADIUS, 0.0, TAU, 32, FULL_COLOR, 2.0)
	# Masks.
	var x := ORIGIN.x + VESSEL_RADIUS * 2.0 + 16.0
	var flash := _flash > 0.0
	for i: int in health.max_masks():
		var full := i < health.masks
		var color := FULL_COLOR if full else EMPTY_COLOR
		if flash and full:
			color = Color(1.0, 0.95, 0.7)
		var top_left := Vector2(x, ORIGIN.y + VESSEL_RADIUS - MASK_SIZE.y / 2.0)
		if i == _pop_index and _pop_age < POP_TIME:
			var t := _pop_age / POP_TIME
			# Glow behind it, and a scale that overshoots then settles.
			var glow := POP_COLOR
			glow.a = 0.6 * (1.0 - t)
			_canvas.draw_circle(top_left + MASK_SIZE / 2.0, MASK_SIZE.y * (0.7 + 0.5 * t), glow)
			var scale := 1.0 + 0.5 * (1.0 - t) * (1.0 - t)
			_draw_mask(top_left - MASK_SIZE * (scale - 1.0) / 2.0, color.lerp(POP_COLOR, 1.0 - t), scale)
		else:
			_draw_mask(top_left, color)
		x += MASK_SIZE.x + MASK_GAP


## A circle filled from the bottom up to `fraction` of its height.
func _fill_circle(center: Vector2, radius: float, fraction: float, color: Color) -> void:
	if fraction <= 0.0:
		return
	var top := center.y + radius - fraction * radius * 2.0
	for row: int in range(int(top), int(center.y + radius)):
		var dy := row + 0.5 - center.y
		var half := sqrt(maxf(radius * radius - dy * dy, 0.0))
		_canvas.draw_line(Vector2(center.x - half, row + 0.5), Vector2(center.x + half, row + 0.5), color, 1.0)


## A simple mask: rounded top, pointed chin, two eye holes.
func _draw_mask(top_left: Vector2, color: Color, scale := 1.0) -> void:
	var w := MASK_SIZE.x * scale
	var h := MASK_SIZE.y * scale
	var points := PackedVector2Array([
		top_left + Vector2(w * 0.5, 0), top_left + Vector2(w, h * 0.2),
		top_left + Vector2(w, h * 0.6), top_left + Vector2(w * 0.5, h),
		top_left + Vector2(0, h * 0.6), top_left + Vector2(0, h * 0.2),
	])
	_canvas.draw_colored_polygon(points, color)
	if color.a > 0.5:
		var eye := Vector2(6, 9) * scale
		_canvas.draw_rect(Rect2(top_left + Vector2(w * 0.28 - eye.x / 2, h * 0.38), eye), OUTLINE)
		_canvas.draw_rect(Rect2(top_left + Vector2(w * 0.72 - eye.x / 2, h * 0.38), eye), OUTLINE)
