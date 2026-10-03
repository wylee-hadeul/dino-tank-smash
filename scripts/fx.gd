extends Node2D
## 간단한 CPU 파티클 시스템: 폭발, 연기, 파편, 충격파, 떠오르는 텍스트.

enum { CIRCLE, DEBRIS, RING, TEXT }

const MAX_PARTS := 420  # 모바일 성능을 위한 상한

var main
var parts: Array = []


func clear() -> void:
	parts.clear()


func _add(p: Dictionary) -> void:
	if parts.size() >= MAX_PARTS:
		parts.pop_front()
	p["age"] = 0.0
	parts.append(p)


func _rand_dir() -> Vector2:
	return Vector2.RIGHT.rotated(randf() * TAU)


func puff(pos: Vector2, col: Color, size: float) -> void:
	_add({"k": CIRCLE, "pos": pos, "vel": Vector2.ZERO, "life": 0.35, "size": size, "grow": 14.0,
		"col": col, "col2": Color(col, 0.0), "grav": -20.0, "drag": 0.0})


func explosion(pos: Vector2, s: float) -> void:
	_add({"k": CIRCLE, "pos": pos, "vel": Vector2.ZERO, "life": 0.14, "size": 70.0 * s, "grow": 200.0 * s,
		"col": Color(1, 1, 0.85, 0.95), "col2": Color(1, 0.8, 0.3, 0.0), "grav": 0.0, "drag": 0.0})
	ring(pos, 160.0 * s, Color(1, 0.9, 0.6, 0.8))
	for i in int(10 * s) + 3:
		_add({"k": CIRCLE, "pos": pos + _rand_dir() * randf() * 20.0 * s, "vel": _rand_dir() * randf_range(80, 420) * s,
			"life": randf_range(0.35, 0.7), "size": randf_range(14, 30) * s, "grow": -10.0,
			"col": Color(1, 0.95, 0.4), "col2": Color(0.9, 0.2, 0.05, 0.0), "grav": -120.0, "drag": 3.5})
	for i in int(6 * s) + 2:
		_add({"k": CIRCLE, "pos": pos + _rand_dir() * 15.0 * s, "vel": Vector2(randf_range(-80, 80), randf_range(-160, -40)) * s,
			"life": randf_range(0.9, 1.7), "size": randf_range(16, 30) * s, "grow": 26.0 * s,
			"col": Color(0.35, 0.33, 0.32, 0.75), "col2": Color(0.55, 0.55, 0.55, 0.0), "grav": -40.0, "drag": 1.5})
	for i in int(6 * s) + 2:
		_add({"k": DEBRIS, "pos": pos, "vel": Vector2(randf_range(-350, 350), randf_range(-650, -200)) * s,
			"life": randf_range(0.8, 1.3), "size": randf_range(4, 9) * s, "grow": 0.0, "rot": randf() * TAU,
			"spin": randf_range(-14, 14), "col": Color(0.15, 0.13, 0.1), "col2": Color(0.15, 0.13, 0.1, 0.0), "grav": 1500.0, "drag": 0.0})


func debris(pos: Vector2, col: Color, count: int) -> void:
	for i in count:
		_add({"k": DEBRIS, "pos": pos + Vector2(randf_range(-30, 30), randf_range(-15, 15)),
			"vel": Vector2(randf_range(-420, 420), randf_range(-850, -300)), "life": randf_range(1.0, 1.8),
			"size": randf_range(6, 15), "grow": 0.0, "rot": randf() * TAU, "spin": randf_range(-12, 12),
			"col": col.darkened(randf() * 0.4), "col2": Color(col, 0.0), "grav": 1600.0, "drag": 0.0, "bounce": true})


func sparks(pos: Vector2) -> void:
	for i in 12:
		_add({"k": DEBRIS, "pos": pos, "vel": _rand_dir() * randf_range(200, 520), "life": randf_range(0.2, 0.45),
			"size": randf_range(3, 6), "grow": -6.0, "rot": randf() * TAU, "spin": 20.0,
			"col": Color(1, 0.95, 0.5), "col2": Color(1, 0.5, 0.1, 0.0), "grav": 900.0, "drag": 1.0})


func muzzle(pos: Vector2, dir: Vector2) -> void:
	_add({"k": CIRCLE, "pos": pos + dir * 10.0, "vel": dir * 60.0, "life": 0.1, "size": 22.0, "grow": 60.0,
		"col": Color(1, 0.95, 0.6), "col2": Color(1, 0.5, 0.1, 0.0), "grav": 0.0, "drag": 0.0})
	for i in 5:
		_add({"k": CIRCLE, "pos": pos, "vel": dir.rotated(randf_range(-0.5, 0.5)) * randf_range(60, 180), "life": randf_range(0.5, 0.9),
			"size": randf_range(8, 14), "grow": 18.0, "col": Color(0.8, 0.8, 0.8, 0.6), "col2": Color(0.8, 0.8, 0.8, 0.0), "grav": -30.0, "drag": 2.0})


func dust(pos: Vector2, s: float) -> void:
	for i in int(10 * s):
		var side := -1.0 if i % 2 == 0 else 1.0
		_add({"k": CIRCLE, "pos": pos + Vector2(side * randf_range(10, 40), -4), "vel": Vector2(side * randf_range(80, 260), randf_range(-60, -10)) * s,
			"life": randf_range(0.4, 0.7), "size": randf_range(8, 16) * s, "grow": 20.0,
			"col": Color(0.78, 0.66, 0.5, 0.8), "col2": Color(0.78, 0.66, 0.5, 0.0), "grav": 0.0, "drag": 3.0})


func ring(pos: Vector2, radius: float, col: Color) -> void:
	_add({"k": RING, "pos": pos, "vel": Vector2.ZERO, "life": 0.45, "size": 10.0, "grow": radius / 0.45,
		"col": col, "col2": Color(col, 0.0), "grav": 0.0, "drag": 0.0})


func text(pos: Vector2, s: String, col: Color) -> void:
	_add({"k": TEXT, "pos": pos, "vel": Vector2(0, -70), "life": 1.1, "size": 30.0, "grow": 0.0, "txt": s,
		"col": col, "col2": Color(col, 0.0), "grav": 0.0, "drag": 1.0})


func update(delta: float) -> void:
	var ground: float = main.ground_y
	for i in range(parts.size() - 1, -1, -1):
		var p: Dictionary = parts[i]
		p.age += delta
		if p.age >= p.life:
			parts.remove_at(i)
			continue
		var vel: Vector2 = p.vel
		var pos: Vector2 = p.pos
		vel.y += p.grav * delta
		if p.drag > 0.0:
			vel *= max(0.0, 1.0 - p.drag * delta)
		pos += vel * delta
		p.size = max(p.size + p.grow * delta, 0.0)
		if p.k == DEBRIS:
			p.rot += p.spin * delta
			if pos.y > ground and vel.y > 0.0:
				pos.y = ground
				if p.get("bounce", false) and vel.y > 200.0:
					vel = Vector2(vel.x * 0.5, -vel.y * 0.35)
				else:
					vel = Vector2(vel.x * 0.6, 0.0)
					p.spin *= 0.5
		p.vel = vel
		p.pos = pos
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for p in parts:
		var k: float = p.age / p.life
		var col: Color = p.col.lerp(p.col2, k * k)
		match p.k:
			CIRCLE:
				draw_circle(p.pos, p.size, col)
			DEBRIS:
				var s: float = p.size
				var xf := Transform2D(p.rot, p.pos)
				draw_colored_polygon(xf * PackedVector2Array([Vector2(-s, -s * 0.6), Vector2(s, -s * 0.6), Vector2(s * 0.7, s * 0.6), Vector2(-s, s * 0.6)]), col)
			RING:
				draw_arc(p.pos, p.size, 0.0, TAU, 48, col, 8.0 * (1.0 - k) + 2.0)
			TEXT:
				var sz := int(p.size * (1.0 + 0.25 * max(0.0, 1.0 - k * 6.0)))
				var w := font.get_string_size(p.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
				var pos: Vector2 = p.pos - Vector2(w * 0.5, 0)
				pos.x = clamp(pos.x, 8.0, main.view.x - w - 8.0)  # 화면 밖으로 잘리지 않게
				draw_string_outline(font, pos, p.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 8, Color(0, 0, 0, col.a))
				draw_string(font, pos, p.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
