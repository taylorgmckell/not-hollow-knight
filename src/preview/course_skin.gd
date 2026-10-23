class_name CourseSkin
extends Node2D
## Draws a BlockCourse with preview art: autotiled terrain, spikes, grass and
## vines, plus a gradient sky and a parallax layer of stalactites. Visual only.
##
## Whole-tile blocks are merged into one grid so touching blocks join up.
## Blocks with fractional sizes (e.g. the graybox ledge) are drawn on their
## own, anchored at the top so the walkable edge lines up with collision.

const PARALLAX_REPEAT := 64

var _course: BlockCourse
var _solid: Dictionary[Vector2i, bool] = {}
var _sky := CanvasLayer.new()


func _init(course: BlockCourse) -> void:
	_course = course
	name = "CourseSkin"
	# Behind the course's own drawing (labels), in front of the parallax.
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	for rect: Rect2 in _course.blocks:
		if _is_whole(rect):
			for y: int in range(int(rect.position.y), int(rect.end.y)):
				for x: int in range(int(rect.position.x), int(rect.end.x)):
					_solid[Vector2i(x, y)] = true
	_build_sky()
	_build_parallax(0.25, PreviewArt.FAR_TINT)
	PreviewArt.changed.connect(_on_preview_changed)
	_on_preview_changed(PreviewArt.enabled)


func _on_preview_changed(enabled: bool) -> void:
	visible = enabled
	_sky.visible = enabled
	for child: Node in get_children():
		if child is Parallax2D:
			(child as Parallax2D).visible = enabled
	_course.queue_redraw()


func _draw() -> void:
	var tile := float(BlockCourse.TILE)
	var sheet := PreviewArt.tilesheet
	# The tiles are outlines with transparent insides: fill the rock first.
	for rect: Rect2 in _course.blocks:
		draw_rect(Rect2(rect.position * tile, rect.size * tile), PreviewArt.ROCK_FILL)
	for cell: Vector2i in _solid:
		var t := PreviewArt.terrain_tile(_is_solid(cell + Vector2i.UP), _is_solid(cell + Vector2i.DOWN),
				_is_solid(cell + Vector2i.LEFT), _is_solid(cell + Vector2i.RIGHT))
		draw_texture_rect_region(sheet, Rect2(Vector2(cell) * tile, Vector2(tile, tile)),
				PreviewArt.region(t), PreviewArt.TERRAIN_TINT)
	for rect: Rect2 in _course.blocks:
		if not _is_whole(rect):
			_draw_loose_block(rect)
	_draw_decorations()
	for rect: Rect2 in _course.hazards:
		for x: int in range(floori(rect.position.x), ceili(rect.end.x)):
			# Spike art sits in the bottom of its tile; align that with the hazard's base.
			var dest := Rect2(Vector2(x, rect.end.y - 1.0) * tile, Vector2(tile, tile))
			draw_texture_rect_region(sheet, dest, PreviewArt.region(PreviewArt.SPIKES), PreviewArt.HAZARD_TINT)


func _draw_decorations() -> void:
	var tile := float(BlockCourse.TILE)
	var sheet := PreviewArt.tilesheet
	for cell: Vector2i in _solid:
		var above := cell + Vector2i.UP
		var below := cell + Vector2i.DOWN
		var roll := _hash(cell)
		if not _is_solid(above) and roll % 100 < 28 and not _near_hazard(above) and not _inside_loose_block(above):
			var grass: Vector2i = PreviewArt.GRASS[roll % PreviewArt.GRASS.size()]
			draw_texture_rect_region(sheet, Rect2(Vector2(above) * tile, Vector2(tile, tile)),
					PreviewArt.region(grass), PreviewArt.DECOR_TINT)
		# Vines only under ceilings above the floor line, with room to spare,
		# so they never dangle into pits or hide a tight squeeze.
		if (cell.y < BlockCourse.GROUND_ROW and not _is_solid(below) and roll % 100 > 84
				and not _is_solid(below + Vector2i.DOWN) and not _is_solid(below + Vector2i.DOWN * 2)):
			var vine: Vector2i = PreviewArt.VINES[roll % PreviewArt.VINES.size()]
			draw_texture_rect_region(sheet, Rect2(Vector2(below) * tile, Vector2(tile, tile)),
					PreviewArt.region(vine), PreviewArt.DECOR_TINT)


## Fractional block: tile it from the top edge down; the last row is clipped.
func _draw_loose_block(rect: Rect2) -> void:
	var tile := float(BlockCourse.TILE)
	var cols := ceili(rect.size.x)
	var rows := ceili(rect.size.y)
	for r: int in rows:
		var fraction := minf(1.0, rect.size.y - r)
		for c: int in cols:
			var t := PreviewArt.terrain_tile(r > 0, r < rows - 1, c > 0, c < cols - 1)
			var src := PreviewArt.region(t)
			src.size.y *= fraction
			var dest := Rect2((rect.position + Vector2(c, r)) * tile, Vector2(tile, tile * fraction))
			draw_texture_rect_region(PreviewArt.tilesheet, dest, src, PreviewArt.TERRAIN_TINT)


func _build_sky() -> void:
	_sky.layer = -10
	var gradient := Gradient.new()
	gradient.set_color(0, PreviewArt.SKY_TOP)
	gradient.set_color(1, PreviewArt.SKY_BOTTOM)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.add_child(rect)
	add_child(_sky)


## A repeating strip of stalactites far behind the course.
func _build_parallax(scroll: float, tint: Color) -> void:
	var layer := Parallax2D.new()
	layer.scroll_scale = Vector2(scroll, scroll * 0.6)
	layer.repeat_size = Vector2(PARALLAX_REPEAT * BlockCourse.TILE, 0)
	layer.repeat_times = 3
	layer.z_index = -20
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var art := Node2D.new()
	art.draw.connect(_draw_stalactites.bind(art, tint))
	layer.add_child(art)
	add_child(layer)


func _draw_stalactites(art: Node2D, tint: Color) -> void:
	var tile := float(BlockCourse.TILE)
	var sheet := PreviewArt.tilesheet
	for i: int in range(0, PARALLAX_REPEAT, 9):
		var roll := _hash(Vector2i(i, 7))
		var x := i + roll % 3
		# Chunky columns (tiles drawn 2x) hanging from far above, with an end cap.
		# Bottoms land around the upper middle of the screen at this scroll rate.
		var segments := 10
		var top := float(2 + roll % 7 - 2 * segments)
		art.draw_rect(Rect2(Vector2(x, top) * tile, Vector2(2, 2 * segments) * tile), PreviewArt.FAR_FILL)
		for s: int in segments:
			var t := PreviewArt.terrain_tile(true, s < segments - 1, false, false)
			art.draw_texture_rect_region(sheet, Rect2(Vector2(x, top + 2 * s) * tile, Vector2(tile, tile) * 2.0),
					PreviewArt.region(t), tint)


func _inside_loose_block(cell: Vector2i) -> bool:
	for rect: Rect2 in _course.blocks:
		if not _is_whole(rect) and rect.has_point(Vector2(cell) + Vector2(0.5, 0.5)):
			return true
	return false


func _is_solid(cell: Vector2i) -> bool:
	return _solid.has(cell)


func _near_hazard(cell: Vector2i) -> bool:
	for rect: Rect2 in _course.hazards:
		if rect.grow(1.0).has_point(Vector2(cell) + Vector2(0.5, 0.5)):
			return true
	return false


static func _is_whole(rect: Rect2) -> bool:
	return (is_equal_approx(rect.position.x, roundf(rect.position.x)) and is_equal_approx(rect.position.y, roundf(rect.position.y))
			and is_equal_approx(rect.size.x, roundf(rect.size.x)) and is_equal_approx(rect.size.y, roundf(rect.size.y)))


## Stable per-cell pseudo-random number so decorations don't change between runs.
static func _hash(cell: Vector2i) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663)) % 1000
