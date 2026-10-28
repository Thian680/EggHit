extends Control

# --- Settings ---
const GAP: float = 6.0
const LENGTH: float = 10.0
const THICKNESS: float = 2.0
const OUTLINE: float = 1.0
const DOT_RADIUS: float = 1.5
const COLOR: Color = Color.WHITE
const OUTLINE_COLOR: Color = Color(0, 0, 0, 0.8)


# --- Drawing ---
func _draw() -> void:
	_draw_ticks(OUTLINE_COLOR, THICKNESS + OUTLINE * 2.0, OUTLINE)
	_draw_ticks(COLOR, THICKNESS, 0.0)
	draw_circle(Vector2.ZERO, DOT_RADIUS + OUTLINE, OUTLINE_COLOR)
	draw_circle(Vector2.ZERO, DOT_RADIUS, COLOR)


func _draw_ticks(color: Color, width: float, pad: float) -> void:
	var inner := GAP - pad
	var outer := GAP + LENGTH + pad
	draw_line(Vector2(inner, 0), Vector2(outer, 0), color, width)
	draw_line(Vector2(-inner, 0), Vector2(-outer, 0), color, width)
	draw_line(Vector2(0, inner), Vector2(0, outer), color, width)
	draw_line(Vector2(0, -inner), Vector2(0, -outer), color, width)
