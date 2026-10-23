extends Node
## Preview-art toggle (F7): placeholder grey boxes vs. CC0 art from Kenney's
## 1-Bit Platformer Pack (see CREDITS.md). Visual only; collision and tuning
## never change. The real art pass is M8.
##
## The tilesheet is 20x20 tiles of 16 px, white on transparent, so everything
## is tinted with the palette below and drawn at 2x (32 px = one course tile).

signal changed(enabled: bool)

const TILESHEET_PATH := "res://assets/preview/kenney_1bit/tilemap.png"
const SOURCE_TILE := 16

## Palette: cool, dim cave tones.
const TERRAIN_TINT := Color(0.70, 0.76, 0.88)
const DECOR_TINT := Color(0.50, 0.58, 0.68)
const HAZARD_TINT := Color(0.92, 0.42, 0.42)
const PLAYER_TINT := Color(0.96, 0.97, 1.0)
const FAR_TINT := Color(0.16, 0.18, 0.25)
const FAR_FILL := Color(0.07, 0.08, 0.12)
const ROCK_FILL := Color(0.08, 0.09, 0.13)
const SKY_TOP := Color(0.04, 0.05, 0.08)
const SKY_BOTTOM := Color(0.11, 0.13, 0.19)

## Terrain autotile: rows are top/middle/bottom/single-row, columns are
## left/middle/right/single-column (sheet columns 15-18, rows 5-8).
const TERRAIN_COL := [15, 16, 17, 18]
const TERRAIN_ROW := [5, 6, 7, 8]
const SPIKES := Vector2i(2, 6)
const GRASS: Array[Vector2i] = [
	Vector2i(16, 0), Vector2i(17, 0), Vector2i(18, 0),
	Vector2i(16, 1), Vector2i(17, 1), Vector2i(18, 1),
]
const VINES: Array[Vector2i] = [Vector2i(19, 0), Vector2i(19, 1)]
## Player: the horned creature (row 17). Frames 0-3 walk, 4 is squashed.
const PLAYER_ROW := 17

var enabled := true
## Loaded at runtime (not preloaded) so a fresh checkout can import the PNG
## before anything needs it.
var tilesheet: Texture2D = load(TILESHEET_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_preview_art"):
		enabled = not enabled
		changed.emit(enabled)


static func region(tile: Vector2i) -> Rect2:
	return Rect2(tile * SOURCE_TILE, Vector2(SOURCE_TILE, SOURCE_TILE))


## Terrain tile for a cell given which of its four neighbours are solid.
static func terrain_tile(up: bool, down: bool, left: bool, right: bool) -> Vector2i:
	var row: int = TERRAIN_ROW[3] if not up and not down else (
			TERRAIN_ROW[0] if not up else (TERRAIN_ROW[2] if not down else TERRAIN_ROW[1]))
	var col: int = TERRAIN_COL[3] if not left and not right else (
			TERRAIN_COL[0] if not left else (TERRAIN_COL[2] if not right else TERRAIN_COL[1]))
	return Vector2i(col, row)
