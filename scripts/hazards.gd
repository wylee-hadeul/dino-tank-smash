extends Node2D
## 보스 패턴용 위험 지대: 지면을 따라 퍼지는 지진파, 수평 레이저. 점프로 피한다.

var main
var items: Array = []


func clear() -> void:
	items.clear()


## 지면을 따라 dir 방향으로 이동하는 지진파
func add_quake(x: float, dir: float, damage: float, speed := 520.0) -> void:
	items.append({"k": "quake", "x": x, "dir": dir, "speed": speed, "dmg": damage, "hit": false, "t": 0.0})


## y 높이의 수평 레이저. warn초 경고 후 active초 동안 판정.
func add_laser(x0: float, x1: float, y: float, damage: float, warn := 0.9, active := 0.6) -> void:
	items.append({"k": "laser", "x0": min(x0, x1), "x1": max(x0, x1), "y": y, "dmg": damage,
		"warn": warn, "active": active, "hit": false, "t": 0.0})


## 경고 중이거나 다가오는 위험 (오토플레이 봇이 점프 판단에 사용)
func threat_for(px: float) -> String:
	for h in items:
		if h.k == "quake":
			var dx: float = px - h.x
			if sign(dx) == h.dir and abs(dx) < 170.0:
				return "quake"
		elif h.k == "laser" and px >= h.x0 and px <= h.x1:
			if h.t < h.warn and h.warn - h.t < 0.18:
				return "laser"
	return ""


func update(delta: float) -> void:
	var d = main.dino
	for i in range(items.size() - 1, -1, -1):
		var h: Dictionary = items[i]
		h.t += delta
		if h.k == "quake":
			h.x += h.dir * h.speed * delta
			if fmod(h.t, 0.05) < delta:
				main.fx.dust(Vector2(h.x, main.ground_y), 0.5)
			if not h.hit and not d.dead and abs(d.position.x - h.x) < 45.0 and d.position.y > main.ground_y - 40.0:
				h.hit = true
				d.hurt(h.dmg)
				d.knockback(Vector2(h.dir * 300.0, -600.0), 0.35)
			if h.x < -100.0 or h.x > main.view.x + 100.0:
				items.remove_at(i)
		elif h.k == "laser":
			if h.t >= h.warn and not h.hit and not d.dead:
				var beam := Rect2(h.x0, h.y - 16.0, h.x1 - h.x0, 32.0)
				if beam.intersects(d.get_rect()):
					h.hit = true
					d.hurt(h.dmg)
			if h.t >= h.warn + h.active:
				items.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var g: float = main.ground_y
	for h in items:
		if h.k == "quake":
			var x: float = h.x
			var pts := PackedVector2Array()
			for j in 7:
				var o := (j - 3) * 9.0
				pts.append(Vector2(x + o, g - (24.0 - abs(o) * 0.6) * (0.6 + 0.4 * sin(h.t * 40.0 + j))))
			pts.append(Vector2(x + 30, g + 2))
			pts.append(Vector2(x - 30, g + 2))
			draw_colored_polygon(pts, Color("8d6e4a"))
			draw_polyline(pts, Color("4e342e"), 3.0)
			draw_circle(Vector2(x, g - 30), 18.0, Color(1, 0.6, 0.2, 0.25))
		elif h.k == "laser":
			if h.t < h.warn:
				var blink: float = 0.35 + 0.35 * sin(h.t * 30.0)
				draw_line(Vector2(h.x0, h.y), Vector2(h.x1, h.y), Color(1, 0.1, 0.1, blink), 3.0)
				draw_rect(Rect2(h.x0, h.y - 16.0, h.x1 - h.x0, 32.0), Color(1, 0, 0, 0.08 + blink * 0.1))
			else:
				var k: float = (h.t - h.warn) / h.active
				var w: float = 34.0 * (1.0 - k * 0.6)
				draw_line(Vector2(h.x0, h.y), Vector2(h.x1, h.y), Color(1, 0.2, 0.1, 0.5), w + 16.0)
				draw_line(Vector2(h.x0, h.y), Vector2(h.x1, h.y), Color(1, 0.6, 0.3), w)
				draw_line(Vector2(h.x0, h.y), Vector2(h.x1, h.y), Color(1, 1, 0.9), w * 0.35)
