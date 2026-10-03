extends Node2D
## 포탄/폭탄. 물기로 받아치면 reflected가 되어 적에게 날아간다.

const GRAVITY := 900.0

var main
var vel := Vector2.ZERO
var damage := 10.0
var big := false
var reflected := false
var dead := false
var trail_t := 0.0


func update(delta: float) -> void:
	vel.y += GRAVITY * delta
	position += vel * delta
	rotation = vel.angle()
	trail_t -= delta
	if trail_t <= 0.0:
		trail_t = 0.03
		var col := Color(0.6, 1, 1, 0.5) if reflected else Color(0.75, 0.75, 0.75, 0.45)
		main.fx.puff(position, col, 7.0 if big else 5.0)
	queue_redraw()


func _draw() -> void:
	var r := 9.0 if big else 6.5
	var glow := Color(0.4, 1, 1, 0.45) if reflected else Color(1, 0.6, 0.2, 0.4)
	draw_circle(Vector2.ZERO, r * 2.0, glow)
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 1.4, -r * 0.7), Vector2(r * 0.6, -r * 0.7), Vector2(r * 1.6, 0), Vector2(r * 0.6, r * 0.7), Vector2(-r * 1.4, r * 0.7)]), Color("2b2b2b"))
	draw_circle(Vector2(r * 0.4, -r * 0.25), r * 0.25, Color(1, 1, 1, 0.5))
