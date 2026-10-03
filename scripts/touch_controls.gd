extends Node2D
## 모바일 가상 버튼 (멀티터치). 손가락마다 버튼을 추적해 InputMap 액션을 누른다.

var main
var enabled := false
var fingers := {}  # touch index -> action
var held := {}     # action -> count


func _ready() -> void:
	enabled = DisplayServer.is_touchscreen_available()


func _buttons() -> Array:
	var v: Vector2 = main.view
	return [
		{"a": "left", "c": Vector2(105, v.y - 105), "r": 72.0},
		{"a": "right", "c": Vector2(270, v.y - 105), "r": 72.0},
		{"a": "bite", "c": Vector2(v.x - 115, v.y - 110), "r": 84.0},
		{"a": "jump", "c": Vector2(v.x - 290, v.y - 85), "r": 68.0},
		{"a": "roar", "c": Vector2(v.x - 150, v.y - 290), "r": 60.0},
	]


func _button_at(p: Vector2) -> String:
	var best := ""
	var best_d := INF
	for b in _buttons():
		var d: float = p.distance_to(b.c)
		if d < b.r * 1.3 and d < best_d:
			best_d = d
			best = b.a
	# 왼쪽 화면 하단의 방향키 영역은 넓게 잡는다
	if best == "" and p.x < 400.0 and p.y > main.view.y - 260.0:
		best = "left" if p.x < 187.0 else "right"
	return best


func _press(action: String) -> void:
	held[action] = held.get(action, 0) + 1
	if held[action] == 1:
		Input.action_press(action)


func _release(action: String) -> void:
	if not held.has(action):
		return
	held[action] -= 1
	if held[action] <= 0:
		held.erase(action)
		Input.action_release(action)


func release_all() -> void:
	for a in held.keys():
		Input.action_release(a)
	held.clear()
	fingers.clear()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		enabled = true
		if main.state != main.State.PLAYING:
			return
		if event.pressed:
			var b := _button_at(event.position)
			if b != "":
				fingers[event.index] = b
				_press(b)
				get_viewport().set_input_as_handled()
		elif fingers.has(event.index):
			_release(fingers[event.index])
			fingers.erase(event.index)
	elif event is InputEventScreenDrag and fingers.has(event.index):
		var cur: String = fingers[event.index]
		if cur != "left" and cur != "right":
			return
		var b := _button_at(event.position)
		if (b == "left" or b == "right") and b != cur:
			_release(cur)
			_press(b)
			fingers[event.index] = b


func _draw() -> void:
	if not enabled or main.state != main.State.PLAYING or main.is_portrait():
		return
	var font := ThemeDB.fallback_font
	for b in _buttons():
		var a: String = b.a
		var c: Vector2 = b.c
		var r: float = b.r
		var down := held.has(a)
		var col := Color(1, 1, 1, 0.32 if down else 0.16)
		var ready := true
		if a == "roar":
			ready = main.dino.roar_meter >= 100.0
			col = Color(1, 0.6, 0.15, (0.5 + sin(main.time * 8.0) * 0.15) if ready else 0.1)
		draw_circle(c, r, col)
		draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.55 if ready else 0.25), 3.0)
		var icon_col := Color(1, 1, 1, 0.9 if ready else 0.4)
		match a:
			"left":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-26, 0), c + Vector2(16, -26), c + Vector2(16, 26)]), icon_col)
			"right":
				draw_colored_polygon(PackedVector2Array([c + Vector2(26, 0), c + Vector2(-16, -26), c + Vector2(-16, 26)]), icon_col)
			_:
				var label: String = a.to_upper()
				var sz := 26 if a != "bite" else 30
				var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
				draw_string(font, c + Vector2(-w * 0.5, sz * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, icon_col)
		if a == "roar" and not ready:
			draw_arc(c, r - 6.0, -PI * 0.5, -PI * 0.5 + TAU * main.dino.roar_meter / 100.0, 40, Color(1, 0.6, 0.15, 0.8), 6.0)
