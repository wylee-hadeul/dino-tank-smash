extends Node2D
## 포탄/로켓/총알/폭탄. 물기로 받아치면 reflected가 되어 적에게 날아간다.

const GRAVITY := 900.0

enum { SHELL, ROCKET, BULLET, BOMB }

var main
var vel := Vector2.ZERO
var damage := 10.0
var big := false
var style := SHELL
var grav := 1.0  # 중력 배율
var reflected := false
var dead := false
var trail_t := 0.0


func update(delta: float) -> void:
	if has_meta("puppet"):
		vel.y += GRAVITY * grav * delta
		position += vel * delta
		position = position.lerp(get_meta("net_pos", position), min(1.0, delta * 6.0))
		rotation = vel.angle()
		queue_redraw()
		return
	vel.y += GRAVITY * grav * delta
	position += vel * delta
	rotation = vel.angle()
	trail_t -= delta
	if trail_t <= 0.0 and style != BULLET:
		trail_t = 0.05
		var col := Color(0.6, 1, 1, 0.5) if reflected else Color(0.75, 0.75, 0.75, 0.45)
		if style == ROCKET and not reflected:
			col = Color(1, 0.7, 0.3, 0.6)
		main.fx.puff(position, col, 7.0 if big else 5.0)
	queue_redraw()


func _draw() -> void:
	var r := 9.0 if big else 6.5
	var glow := Color(0.4, 1, 1, 0.45) if reflected else Color(1, 0.6, 0.2, 0.4)
	match style:
		BULLET:
			draw_circle(Vector2.ZERO, 7.0, glow)
			draw_line(Vector2(-8, 0), Vector2(5, 0), Color("ffe082"), 4.0)
		ROCKET:
			draw_circle(Vector2(-14, 0), 9.0, Color(1, 0.6, 0.1, 0.6))
			draw_colored_polygon(PackedVector2Array([Vector2(-12, -4), Vector2(8, -4), Vector2(15, 0), Vector2(8, 4), Vector2(-12, 4)]), Color("e0e0e0"))
			draw_colored_polygon(PackedVector2Array([Vector2(8, -4), Vector2(15, 0), Vector2(8, 4)]), Color("e53935"))
			draw_colored_polygon(PackedVector2Array([Vector2(-12, -4), Vector2(-16, -8), Vector2(-8, -4)]), Color("757575"))
			draw_colored_polygon(PackedVector2Array([Vector2(-12, 4), Vector2(-16, 8), Vector2(-8, 4)]), Color("757575"))
			if reflected:
				draw_circle(Vector2.ZERO, 14.0, glow)
		BOMB:
			draw_circle(Vector2.ZERO, r * 1.8, glow)
			draw_circle(Vector2.ZERO, r * 1.1, Color("37474f"))
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 1.0, -r * 0.4), Vector2(-r * 2.0, -r), Vector2(-r * 2.0, r), Vector2(-r * 1.0, r * 0.4)]), Color("546e7a"))
		_:
			draw_circle(Vector2.ZERO, r * 2.0, glow)
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 1.4, -r * 0.7), Vector2(r * 0.6, -r * 0.7), Vector2(r * 1.6, 0), Vector2(r * 0.6, r * 0.7), Vector2(-r * 1.4, r * 0.7)]), Color("2b2b2b"))
			draw_circle(Vector2(r * 0.4, -r * 0.25), r * 0.25, Color(1, 1, 1, 0.5))
