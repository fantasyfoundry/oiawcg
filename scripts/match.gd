extends Node2D
## All positions are on the ice plane; rendering adds height to each skater.
const RINK := Rect2(80, 210, 800, 280)
const CENTER := Vector2(480, 350)
const GOAL_TOP := 318.0
const GOAL_BOTTOM := 382.0
const SPEED := 150.0
const MATCH_LENGTH := 180.0
var skaters: Array[Dictionary] = []
var puck := CENTER
var puck_velocity := Vector2.ZERO
var holder := -1
var selected := 0
var pickup_delay := 0.0
var ai_timer := 0.0
var scores := [0, 0]
var remaining := MATCH_LENGTH
var mode := "menu"
var banner := ""
var banner_time := 0.0
var elapsed := 0.0
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	reset_faceoff()

func reset_faceoff() -> void:
	skaters.clear()
	for team in range(2):
		for slot in range(4):
			var x := 355.0 if team == 0 else 605.0
			var y := 265.0 + slot * 75.0
			if slot == 3:
				x = 113.0 if team == 0 else 847.0
				y = 350.0
			skaters.append({"pos": Vector2(x, y), "vel": Vector2.ZERO,
				"team": team, "slot": slot, "face": Vector2.RIGHT if team == 0 else Vector2.LEFT})
	selected = 1
	puck = CENTER
	puck_velocity = Vector2.ZERO
	holder = -1
	pickup_delay = 0.6
	ai_timer = 0.0

func start_match() -> void:
	scores = [0, 0]
	remaining = MATCH_LENGTH
	mode = "play"
	banner = "Vhadzovanie"
	banner_time = 1.2
	reset_faceoff()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event.keycode as Key
	if key == KEY_ENTER and mode in ["menu", "over"]:
		start_match()
	elif key == KEY_ESCAPE and mode in ["play", "paused"]:
		mode = "paused" if mode == "play" else "play"
	elif key == KEY_R and mode in ["play", "paused", "over"]:
		start_match()
	elif mode == "play":
		if key == KEY_SPACE:
			shoot(selected)
		elif key == KEY_C:
			if holder == selected:
				pass_puck(selected)
			else:
				switch_player()
		elif key == KEY_X:
			poke_check()

func switch_player() -> void:
	var previous := selected
	var best := INF
	for i in range(3):
		var distance: float = skaters[i].pos.distance_squared_to(puck)
		if i != previous and distance < best:
			best = distance
			selected = i

func release_puck(index: int, direction: Vector2, power: float) -> void:
	if holder != index:
		return
	puck = skaters[index].pos + direction.normalized() * 23.0
	puck_velocity = direction.normalized() * power
	holder = -1
	pickup_delay = 0.18

func shoot(index: int) -> void:
	if holder != index:
		return
	var target := Vector2(891 if skaters[index].team == 0 else 69, 350)
	release_puck(index, target - skaters[index].pos, 620.0)

func pass_puck(index: int) -> void:
	if holder != index:
		return
	var target := -1
	var best := INF
	for i in range(skaters.size()):
		if i == index or skaters[i].team != skaters[index].team or skaters[i].slot == 3:
			continue
		var distance: float = skaters[index].pos.distance_squared_to(skaters[i].pos)
		if distance < best:
			best = distance
			target = i
	if target >= 0:
		release_puck(index, skaters[target].pos - skaters[index].pos, 370.0)
		if skaters[index].team == 0:
			selected = target

func poke_check() -> void:
	if holder >= 0 and skaters[holder].team == 1 and skaters[selected].pos.distance_to(puck) < 43:
		var direction: Vector2 = (puck - skaters[selected].pos).normalized()
		release_puck(holder, direction, 190.0)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if mode == "play":
		remaining = maxf(0, remaining - delta)
		banner_time = maxf(0, banner_time - delta)
		if remaining <= 0:
			mode = "over"
		else:
			step_match(delta)
	queue_redraw()

func step_match(delta: float) -> void:
	pickup_delay = maxf(0, pickup_delay - delta)
	ai_timer += delta
	var input_dir := Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))).normalized()
	for i in range(skaters.size()):
		var s: Dictionary = skaters[i]
		var direction := Vector2.ZERO
		if i == selected:
			direction = input_dir
		else:
			var target: Vector2 = s.pos
			var attack := 1.0 if s.team == 0 else -1.0
			if s.slot == 3:
				target = Vector2(113 if s.team == 0 else 847, clampf(puck.y, 324, 376))
			elif holder == i:
				target = Vector2(780 if s.team == 0 else 180, 350)
				if absf(s.pos.x - target.x) < 105 and ai_timer > 0.8:
					shoot(i)
					ai_timer = 0.0
			elif holder < 0 or skaters[holder].team != s.team:
				var nearest := nearest_skater(s.team, puck)
				if nearest == i:
					target = puck
				else:
					target = Vector2(clampf(puck.x - attack * 110, 180, 780), 265 + s.slot * 80)
			else:
				target = Vector2(clampf(puck.x + attack * 110, 180, 780), 265 + s.slot * 80)
			if s.pos.distance_to(target) > 6:
				direction = s.pos.direction_to(target)
		var speed := SPEED if i == selected else SPEED * 0.83
		s.vel = s.vel.move_toward(direction * speed, (480.0 if direction != Vector2.ZERO else 220.0) * delta)
		s.pos += s.vel * delta
		s.pos.x = clampf(s.pos.x, RINK.position.x + 17, RINK.end.x - 17)
		s.pos.y = clampf(s.pos.y, RINK.position.y + 18, RINK.end.y - 12)
		if direction != Vector2.ZERO:
			s.face = direction
	# Separate bodies on the ice plane, independently of sprite height.
	for i in range(skaters.size()):
		for j in range(i + 1, skaters.size()):
			var offset: Vector2 = skaters[j].pos - skaters[i].pos
			if offset.length() < 19:
				var push := offset.normalized() * (19 - offset.length()) * 0.5
				skaters[i].pos -= push
				skaters[j].pos += push
	if holder >= 0:
		puck = skaters[holder].pos + skaters[holder].face * 16
	else:
		advance_puck(delta)
		if pickup_delay <= 0:
			var nearest := -1
			var best := 22.0
			for i in range(skaters.size()):
				var distance: float = skaters[i].pos.distance_to(puck)
				if distance < best:
					best = distance
					nearest = i
			if nearest >= 0:
				holder = nearest
				puck_velocity = Vector2.ZERO
				if skaters[nearest].team == 0 and skaters[nearest].slot != 3:
					selected = nearest
				elif skaters[nearest].slot == 3:
					# Goalies clear immediately; the player controls outfield skaters.
					release_puck(nearest, Vector2(1 if skaters[nearest].team == 0 else -1, 0.5), 280)

func nearest_skater(team: int, point: Vector2) -> int:
	var result := -1
	var distance := INF
	for i in range(skaters.size()):
		if skaters[i].team == team and skaters[i].slot != 3:
			var d: float = skaters[i].pos.distance_squared_to(point)
			if d < distance:
				distance = d
				result = i
	return result

func advance_puck(delta: float) -> void:
	# Substeps keep fast shots from tunnelling through boards or goal mouths.
	var steps := maxi(1, ceili(puck_velocity.length() * delta / 5.0))
	for substep in range(steps):
		puck += puck_velocity * delta / steps
		if puck.y < RINK.position.y + 4 or puck.y > RINK.end.y - 4:
			puck.y = clampf(puck.y, RINK.position.y + 4, RINK.end.y - 4)
			puck_velocity.y *= -0.8
		if puck.x < RINK.position.x or puck.x > RINK.end.x:
			if puck.y > GOAL_TOP and puck.y < GOAL_BOTTOM:
				score_goal(0 if puck.x > CENTER.x else 1)
				return
			puck.x = clampf(puck.x, RINK.position.x, RINK.end.x)
			puck_velocity.x *= -0.8
	puck_velocity = puck_velocity.move_toward(Vector2.ZERO, 38 * delta)

func score_goal(team: int) -> void:
	scores[team] += 1
	banner = "GÓL!  " + ("BOSTON" if team == 0 else "MONTREAL")
	banner_time = 2.0
	reset_faceoff()

func text_at(value: String, point: Vector2, size: int, color := Color("efe5cb")) -> void:
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, y: float, size: int, color := Color("efe5cb")) -> void:
	text_at(value, Vector2((960 - font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) / 2, y), size, color)

# Simulation coordinates stay on the ice. Only drawing uses this low side camera.
# Depth compresses strongly; upright players keep their full vertical height.
func ice_to_screen(point: Vector2) -> Vector2:
	var depth := (point.y - RINK.position.y) / RINK.size.y
	var width_scale := lerpf(0.90, 1.0, depth)
	return Vector2(480 + (point.x - 480) * width_scale, 340 + depth * 126)

func ice_line(a: Vector2, b: Vector2, color: Color, width := 1.0) -> void:
	draw_line(ice_to_screen(a), ice_to_screen(b), color, width)

func ice_circle(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(49):
		points.append(ice_to_screen(center + Vector2(cos(i * TAU / 48), sin(i * TAU / 48)) * radius))
	draw_polyline(points, color, 1.5)

func draw_goal(left: bool) -> void:
	var mouth_x := RINK.position.x if left else RINK.end.x
	var back_x := mouth_x + (-24 if left else 24)
	var a := ice_to_screen(Vector2(mouth_x, GOAL_TOP))
	var b := ice_to_screen(Vector2(mouth_x, GOAL_BOTTOM))
	var c := ice_to_screen(Vector2(back_x, GOAL_TOP))
	var d := ice_to_screen(Vector2(back_x, GOAL_BOTTOM))
	var height := Vector2(0, -35)
	draw_colored_polygon(PackedVector2Array([c, d, d + height, c + height]), Color("789086"))
	for i in range(6):
		var f := float(i) / 5
		draw_line(c.lerp(d, f), c.lerp(d, f) + height, Color("c2cabc"), 1)
		draw_line(c + height * f, d + height * f, Color("c2cabc"), 1)
	draw_line(a + height, c + height, Color("a49371"), 2)
	draw_line(b + height, d + height, Color("a49371"), 2)
	draw_line(a, a + height, Color("79533b"), 3)
	draw_line(b, b + height, Color("79533b"), 3)
	draw_line(a + height, b + height, Color("79533b"), 3)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 600), Color("91aaa9"))
	# A low horizon, upright trees and spectators establish a rink-side viewpoint.
	for i in range(26):
		var x := float(i * 41 - 25)
		var height := 50.0 + float((i * 17) % 65)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 286), Vector2(x + 21, 286 - height), Vector2(x + 42, 286)]), Color("365752"))
	draw_rect(Rect2(0, 285, 960, 236), Color("bdcec5"))
	for row in range(3):
		var row_y := 268 + row * 15
		draw_rect(Rect2(44, row_y + 16, 872, 6), Color("6d5746"))
		for i in range(58):
			var x := 52 + i * 15 + (row % 2) * 5
			draw_rect(Rect2(x, row_y, 9, 17), Color("4b5150") if i % 3 else Color("785b46"))
			draw_rect(Rect2(x + 2, row_y - 7, 6, 7), Color("c09b79"))
			draw_rect(Rect2(x + 1, row_y - 9, 8, 3), Color("3f4038"))
	var far_left := ice_to_screen(RINK.position)
	var far_right := ice_to_screen(Vector2(RINK.end.x, RINK.position.y))
	var near_left := ice_to_screen(Vector2(RINK.position.x, RINK.end.y))
	var near_right := ice_to_screen(RINK.end)
	draw_colored_polygon(PackedVector2Array([far_left, far_right, near_right, near_left]), Color("d9e8de"))
	# Far boards rise above the ice instead of looking like a flat border.
	draw_colored_polygon(PackedVector2Array([far_left, far_right, far_right - Vector2(0, 24), far_left - Vector2(0, 24)]), Color("b9a988"))
	draw_line(far_left - Vector2(0, 24), far_right - Vector2(0, 24), Color("6a5039"), 4)
	for i in range(29):
		var post := far_left.lerp(far_right, float(i) / 28)
		draw_line(post, post - Vector2(0, 23), Color("8f7d5e"), 1)
	for i in range(42):
		var point := Vector2(100 + (i * 97) % 760, 225 + (i * 43) % 245)
		ice_line(point, point + Vector2(24, -3), Color("bdd3c9"))
	ice_line(Vector2(480, 211), Vector2(480, 489), Color("ad7770"), 2)
	ice_circle(CENTER, 46, Color("ad7770"))
	draw_circle(ice_to_screen(CENTER), 2, Color("ad7770"))
	for x in [235, 725]:
		for y in [275, 425]:
			ice_circle(Vector2(x, y), 25, Color("a3bfb2"))
	draw_goal(true)
	draw_goal(false)
	# Draw far objects first. The puck participates in the same depth ordering.
	var order: Array[int] = [-1]
	for i in range(skaters.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ay: float = puck.y if a == -1 else skaters[a].pos.y
		var by: float = puck.y if b == -1 else skaters[b].pos.y
		return ay < by)
	for i in order:
		if i == -1:
			var screen_puck := ice_to_screen(puck).round()
			draw_rect(Rect2(screen_puck + Vector2(-5, 1), Vector2(10, 3)), Color("9bb4ab"))
			draw_rect(Rect2(screen_puck - Vector2(4, 2), Vector2(8, 4)), Color("182b30"))
		else:
			draw_skater(i)
	# Low foreground rail leaves feet and puck visible while framing the near side.
	draw_colored_polygon(PackedVector2Array([near_left + Vector2(0, 8), near_right + Vector2(0, 8), near_right + Vector2(0, 28), near_left + Vector2(0, 28)]), Color("897252"))
	draw_line(near_left + Vector2(0, 8), near_right + Vector2(0, 8), Color("e0d1ad"), 4)
	draw_rect(Rect2(0, 520, 960, 80), Color("142831"))
	draw_rect(Rect2(0, 0, 960, 112), Color("101f27"))
	text_at("ON ICE", Vector2(30, 40), 29)
	text_at("A WINTER CLASSIC", Vector2(32, 64), 11, Color("a9bdb6"))
	text_at("1924 — 1927  /  PROTOTYP 0.2", Vector2(32, 88), 10, Color("d1ae68"))
	centered("BOSTON    %d  :  %d    MONTREAL" % [scores[0], scores[1]], 47, 24)
	var seconds := ceili(remaining)
	centered("TRÉNING  •  %02d:%02d" % [seconds / 60, seconds % 60], 78, 14, Color("a9bdb6"))
	text_at("3 + BRANKÁR", Vector2(805, 43), 13)
	text_at("ÚTOK  →", Vector2(812, 69), 13, Color("d1ae68"))
	centered("ŠÍPKY  pohyb     C  prihrávka / zmena hráča     MEDZERNÍK  strela     X  vypichnutie", 551, 14)
	centered("ESC  pauza     R  nový zápas   •   Dobové pravidlá a plné zostavy pripravujeme", 578, 12, Color("9aafa9"))
	if banner_time > 0 and mode == "play":
		centered(banner, 143, 22, Color("f0cf84"))
	if mode != "play":
		draw_rect(Rect2(160, 245, 640, 194), Color(0.04, 0.10, 0.13, 0.96))
		var title := "ZIMNÁ KLASIKA"
		var subtitle := "Boston proti Montrealu • bočný pohľad • vonkajšie klzisko"
		var prompt := "ENTER  začať zápas"
		if mode == "paused":
			title = "PRESTÁVKA"
			subtitle = "Zápas je pozastavený"
			prompt = "ESC  pokračovať     R  nový zápas"
		elif mode == "over":
			title = "KONIEC ZÁPASU"
			subtitle = "Boston %d : %d Montreal" % [scores[0], scores[1]]
			prompt = "ENTER  odveta"
		centered(title, 294, 32)
		centered(subtitle, 334, 17, Color("a9bdb6"))
		centered(prompt, 386, 19, Color("f0cf84"))

func draw_skater(index: int) -> void:
	var s: Dictionary = skaters[index]
	var p := ice_to_screen(s.pos).round()
	var depth: float = (s.pos.y - RINK.position.y) / RINK.size.y
	var scale_factor := lerpf(1.10, 1.35, depth)
	var facing := 1.0 if s.face.x >= 0 else -1.0
	var jersey := Color("b58b36") if s.team == 0 else Color("a53c38")
	var trim := Color("292c29") if s.team == 0 else Color("ebe0c6")
	if index == selected:
		draw_set_transform(p + Vector2(0, 3), 0, Vector2(1.6, 0.35))
		draw_arc(Vector2.ZERO, 10, 0, TAU, 24, Color("b58032"), 2)
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -63), p + Vector2(5, -63), p + Vector2(0, -56)]), Color("ba7b26"))
	draw_set_transform(p + Vector2(0, 3), 0, Vector2(1.6, 0.25))
	draw_circle(Vector2.ZERO, 10, Color(0.15, 0.26, 0.24, 0.22))
	# Mirrored profile: face and stick point along the rink's long axis.
	draw_set_transform(p, 0, Vector2(facing * scale_factor, scale_factor))
	var stride := sin(elapsed * 14 + index) * 5 if s.vel.length() > 15 else 1.0
	for side in [-1, 1]:
		var hip := Vector2(-2 + side * 3, -15)
		var knee := Vector2(-4 + side * stride, -8)
		var foot := Vector2(-5 + side * stride * 1.6, -1)
		draw_line(hip, knee, trim, 5)
		draw_line(knee, foot, jersey, 4)
		draw_line(foot + Vector2(-3, 0), foot + Vector2(5, 0), Color("303b36"), 4)
		draw_line(foot + Vector2(-4, 3), foot + Vector2(7, 3), Color("758a81"), 1)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -32), Vector2(3, -34), Vector2(8, -17), Vector2(-5, -15)]), jersey)
	draw_line(Vector2(-6, -20), Vector2(6, -22), trim, 4)
	draw_rect(Rect2(-4, -18, 12, 5), trim)
	# Bare head, hair and a visible nose: deliberately a side silhouette.
	draw_rect(Rect2(-2, -44, 10, 11), Color("cda17e"))
	draw_rect(Rect2(7, -40, 3, 4), Color("cda17e"))
	draw_rect(Rect2(-3, -45, 11, 4), Color("503e31"))
	draw_rect(Rect2(6, -40, 1, 1), Color("342e28"))
	draw_line(Vector2(1, -31), Vector2(9, -23), jersey, 6)
	draw_line(Vector2(9, -23), Vector2(15, -20), jersey, 5)
	draw_rect(Rect2(12, -22, 6, 6), Color("5c4937"))
	draw_line(Vector2(15, -19), Vector2(24, 2), Color("785638"), 2)
	draw_line(Vector2(24, 2), Vector2(33, 2), Color("785638"), 3)
	if s.slot == 3:
		draw_rect(Rect2(-7, -13, 5, 13), Color("b2a183"))
		draw_rect(Rect2(1, -13, 5, 13), Color("b2a183"))
	draw_set_transform(Vector2.ZERO)
