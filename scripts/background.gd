extends Node2D
## 선사시대 배경: 하늘 그라데이션, 화산, 산, 야자수, 구름, 땅.

var main
var t := 0.0
var clouds: Array = []
var smoke: Array = []


func _ready() -> void:
	for i in 6:
		clouds.append({"x": randf() * 1600.0, "y": randf_range(50, 230), "s": randf_range(0.7, 1.4), "v": randf_range(8, 22)})


func update(delta: float) -> void:
	t += delta
	var w: float = main.view.x
	for c in clouds:
		c.x += c.v * delta
		if c.x > w + 200.0:
			c.x = -200.0
	if randf() < delta * 3.0:
		smoke.append({"p": Vector2(w * 0.78 + randf_range(-10, 10), main.ground_y - 330.0), "age": 0.0})
	for i in range(smoke.size() - 1, -1, -1):
		smoke[i].age += delta
		smoke[i].p += Vector2(14.0, -30.0) * delta
		if smoke[i].age > 6.0:
			smoke.remove_at(i)
	queue_redraw()


func _draw() -> void:
	var v: Vector2 = main.view
	var g: float = main.ground_y
	var pad := 40.0
	# 하늘
	draw_polygon(PackedVector2Array([Vector2(-pad, -pad), Vector2(v.x + pad, -pad), Vector2(v.x + pad, g), Vector2(-pad, g)]),
		PackedColorArray([Color("4fb3ff"), Color("4fb3ff"), Color("ffe3b0"), Color("ffe3b0")]))
	# 해
	draw_circle(Vector2(v.x * 0.18, g * 0.28), 70.0, Color(1, 0.95, 0.7, 0.35))
	draw_circle(Vector2(v.x * 0.18, g * 0.28), 48.0, Color("fff3c4"))
	# 구름
	for c in clouds:
		var p := Vector2(c.x, c.y)
		var s: float = c.s
		for o in [Vector2(0, 0), Vector2(38, -14), Vector2(76, 0), Vector2(36, 10)]:
			draw_circle(p + o * s, 30.0 * s, Color(1, 1, 1, 0.85))
	# 먼 산
	var far := PackedVector2Array([Vector2(-pad, g)])
	var n := 9
	for i in n + 1:
		var x := -pad + (v.x + pad * 2.0) * i / float(n)
		var y := g - 170.0 - (sin(i * 1.7) * 0.5 + 0.5) * 120.0
		far.append(Vector2(x, y))
	far.append(Vector2(v.x + pad, g))
	draw_colored_polygon(far, Color("9cb6d8"))
	# 화산
	var vx := v.x * 0.78
	draw_colored_polygon(PackedVector2Array([Vector2(vx - 280, g), Vector2(vx - 40, g - 330), Vector2(vx + 40, g - 330), Vector2(vx + 300, g)]), Color("6d5a52"))
	draw_colored_polygon(PackedVector2Array([Vector2(vx - 40, g - 330), Vector2(vx + 40, g - 330), Vector2(vx + 22, g - 290), Vector2(vx + 6, g - 250), Vector2(vx - 12, g - 300), Vector2(vx - 30, g - 285)]), Color("ff6a2b"))
	draw_circle(Vector2(vx, g - 332), 30.0 + sin(t * 3.0) * 4.0, Color(1, 0.5, 0.1, 0.35))
	for s in smoke:
		var k: float = s.age / 6.0
		draw_circle(s.p, 20.0 + k * 50.0, Color(0.4, 0.37, 0.36, 0.5 * (1.0 - k)))
	# 가까운 언덕
	var near := PackedVector2Array([Vector2(-pad, g)])
	for i in 15:
		var x := -pad + (v.x + pad * 2.0) * i / 14.0
		near.append(Vector2(x, g - 60.0 - (sin(i * 2.3 + 1.0) * 0.5 + 0.5) * 60.0))
	near.append(Vector2(v.x + pad, g))
	draw_colored_polygon(near, Color("5f9e4c"))
	# 야자수
	for i in 5:
		var px := v.x * (0.08 + i * 0.22) + sin(i * 3.3) * 40.0
		_palm(Vector2(px, g), 0.8 + fmod(i * 0.37, 0.5))
	# 땅
	draw_rect(Rect2(-pad, g, v.x + pad * 2.0, v.y - g + pad), Color("9a7650"))
	draw_rect(Rect2(-pad, g, v.x + pad * 2.0, 14), Color("6aa84f"))
	draw_rect(Rect2(-pad, g + 14, v.x + pad * 2.0, 5), Color("4e8a3a"))
	for i in int(v.x / 90.0) + 1:
		var rx := i * 90.0 + fmod(i * 37.0, 50.0)
		var ry := g + 40.0 + fmod(i * 53.0, 50.0)
		draw_circle(Vector2(rx, ry), 4.0 + fmod(i * 7.0, 5.0), Color("7d5e3f"))


func _palm(base: Vector2, s: float) -> void:
	var sway := sin(t * 1.3 + base.x) * 4.0
	var top := base + Vector2(18 * s + sway, -150 * s)
	var mid := base + Vector2(4 * s, -80 * s)
	draw_polyline(PackedVector2Array([base, mid, top]), Color("6b4a2e"), 9.0 * s)
	for i in 6:
		var a := -PI * 0.5 + (i - 2.5) * 0.55
		var tip := top + Vector2(cos(a), sin(a) * 0.5 + 0.55).normalized() * 70.0 * s
		var ctrl := top + (tip - top) * 0.5 + Vector2(0, -18 * s)
		draw_polyline(PackedVector2Array([top, ctrl, tip]), Color("2f7d32"), 10.0 * s)
