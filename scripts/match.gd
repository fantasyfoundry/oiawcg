extends Node2D
## All positions are on the ice plane; rendering adds height to each skater.
const RINK := Rect2(80, 210, 1840, 500)
const CENTER := Vector2(1000, 460)
const GOAL_TOP := 408.0
const GOAL_BOTTOM := 512.0
const SPEED := 205.0
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
var camera_x := CENTER.x
var kit_frames: Array[Array] = [[], []]
var kit_idle: Array[Texture2D] = []
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	for team in ["boston", "montreal"]:
		var team_index := 0 if team == "boston" else 1
		kit_idle.append(load("res://art/skaters/%s_idle.svg" % team))
		for frame in range(8):
			kit_frames[team_index].append(load("res://art/skaters/%s_%02d.svg" % [team, frame]))
	reset_faceoff()

func reset_faceoff() -> void:
	skaters.clear()
	for team in range(2):
		for slot in range(4):
			var x := 835.0 if team == 0 else 1165.0
			var y := 300.0 + slot * 160.0
			if slot == 3:
				x = 125.0 if team == 0 else 1875.0
				y = CENTER.y
			skaters.append({"pos": Vector2(x, y), "vel": Vector2.ZERO,
				"phase": 0.0, "effort": 0.0, "team": team, "slot": slot, "face": Vector2.RIGHT if team == 0 else Vector2.LEFT})
	selected = 1
	puck = CENTER
	puck_velocity = Vector2.ZERO
	holder = -1
	pickup_delay = 0.6
	ai_timer = 0.0
	camera_x = CENTER.x

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
	puck = skaters[index].pos + direction.normalized() * 45.0
	puck_velocity = direction.normalized() * power
	holder = -1
	pickup_delay = 0.18

func shoot(index: int) -> void:
	if holder != index:
		return
	var target := Vector2(RINK.end.x + 12 if skaters[index].team == 0 else RINK.position.x - 12, CENTER.y)
	release_puck(index, target - skaters[index].pos, 780.0)

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
		release_puck(index, skaters[target].pos - skaters[index].pos, 500.0)
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
	if mode == "play":
		update_camera(delta)
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
				target = Vector2(125 if s.team == 0 else 1875, clampf(puck.y, GOAL_TOP + 10, GOAL_BOTTOM - 10))
			elif holder == i:
				target = Vector2(1720 if s.team == 0 else 280, CENTER.y)
				if absf(s.pos.x - target.x) < 170 and ai_timer > 0.8:
					shoot(i)
					ai_timer = 0.0
			elif holder < 0 or skaters[holder].team != s.team:
				var nearest := nearest_skater(s.team, puck)
				if nearest == i:
					target = puck
				else:
					target = Vector2(clampf(puck.x - attack * 190, 240, 1760), 300 + s.slot * 160)
			else:
				target = Vector2(clampf(puck.x + attack * 190, 240, 1760), 300 + s.slot * 160)
			if s.pos.distance_to(target) > 6:
				direction = s.pos.direction_to(target)
		var speed := SPEED if i == selected else SPEED * 0.83
		s.vel = s.vel.move_toward(direction * speed, (480.0 if direction != Vector2.ZERO else 220.0) * delta)
		s.pos += s.vel * delta
		s.pos.x = clampf(s.pos.x, RINK.position.x + 17, RINK.end.x - 17)
		s.pos.y = clampf(s.pos.y, RINK.position.y + 18, RINK.end.y - 12)
		# One push/glide cycle takes about 1.1–1.8 seconds, based on speed.
		var effort_target := 1.0 if direction != Vector2.ZERO and s.vel.length() > 18 else 0.0
		s.effort = move_toward(s.effort, effort_target, delta * 3.0)
		if s.effort > 0.15:
			s.phase = fmod(s.phase + delta * lerpf(0.55, 0.90, clampf(s.vel.length() / SPEED, 0, 1)), 1.0)
		if absf(direction.x) > 0.1:
			s.face = Vector2(signf(direction.x), 0)
	# Separate bodies on the ice plane, independently of sprite height.
	for i in range(skaters.size()):
		for j in range(i + 1, skaters.size()):
			var offset: Vector2 = skaters[j].pos - skaters[i].pos
			if offset.length() < 32:
				var push := offset.normalized() * (32 - offset.length()) * 0.5
				skaters[i].pos -= push
				skaters[j].pos += push
	if holder >= 0:
		puck = skaters[holder].pos + skaters[holder].face * 38
	else:
		advance_puck(delta)
		if pickup_delay <= 0:
			var nearest := -1
			var best := 32.0
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

# The camera scrolls along the rink; HUD coordinates never enter this projection.
func camera_limits() -> Vector2:
	return Vector2(RINK.position.x + 360, RINK.end.x - 360)

func update_camera(delta: float) -> void:
	var focus := puck.x
	if holder < 0:
		focus += clampf(puck_velocity.x * 0.18, -125, 125)
	# Keep some context around the controlled player without losing fast shots.
	var target := lerpf(focus, skaters[selected].pos.x, 0.18)
	var limits := camera_limits()
	target = clampf(target, limits.x, limits.y)
	camera_x = lerpf(camera_x, target, 1.0 - exp(-5.5 * delta))
	camera_x = clampf(camera_x, limits.x, limits.y)

func ice_to_screen(point: Vector2) -> Vector2:
	var depth := (point.y - RINK.position.y) / RINK.size.y
	var width_scale := lerpf(0.96, 1.0, depth)
	return Vector2(480 + (point.x - camera_x) * width_scale, 295 + depth * 198)

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
	var height := Vector2(0, -59)
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
	for i in range(12):
		var x := float(i * 110 - 100 - int(camera_x * 0.18) % 110)
		var height := 50.0 + float((i * 17) % 65)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 245), Vector2(x + 50, 245 - height), Vector2(x + 100, 245)]), Color("365752"))
	draw_rect(Rect2(0, 240, 960, 280), Color("bdcec5"))
	for row in range(3):
		var row_y := 213 + row * 15
		draw_rect(Rect2(44, row_y + 16, 872, 6), Color("6d5746"))
		for i in range(58):
			var x := 52 + i * 15 + (row % 2) * 5 - int(camera_x * 0.35) % 15
			draw_rect(Rect2(x, row_y, 9, 17), Color("4b5150") if i % 3 else Color("785b46"))
			draw_rect(Rect2(x + 2, row_y - 7, 6, 7), Color("c09b79"))
			draw_rect(Rect2(x + 1, row_y - 9, 8, 3), Color("3f4038"))
	var far_left := ice_to_screen(RINK.position)
	var far_right := ice_to_screen(Vector2(RINK.end.x, RINK.position.y))
	var near_left := ice_to_screen(Vector2(RINK.position.x, RINK.end.y))
	var near_right := ice_to_screen(RINK.end)
	draw_colored_polygon(PackedVector2Array([far_left, far_right, near_right, near_left]), Color("d9e8de"))
	# Far boards rise above the ice instead of looking like a flat border.
	draw_colored_polygon(PackedVector2Array([far_left, far_right, far_right - Vector2(0, 28), far_left - Vector2(0, 28)]), Color("b9a988"))
	draw_line(far_left - Vector2(0, 28), far_right - Vector2(0, 28), Color("6a5039"), 4)
	for i in range(65):
		var post := far_left.lerp(far_right, float(i) / 64)
		draw_line(post, post - Vector2(0, 27), Color("8f7d5e"), 1)
	for i in range(100):
		var point := Vector2(100 + (i * 97) % 1800, 225 + (i * 43) % 465)
		ice_line(point, point + Vector2(24, -3), Color("bdd3c9"))
	ice_line(Vector2(CENTER.x, RINK.position.y), Vector2(CENTER.x, RINK.end.y), Color("ad7770"), 2)
	ice_circle(CENTER, 78, Color("ad7770"))
	draw_circle(ice_to_screen(CENTER), 2, Color("ad7770"))
	for x in [420, 1580]:
		for y in [330, 590]:
			ice_circle(Vector2(x, y), 58, Color("a3bfb2"))
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
	draw_colored_polygon(PackedVector2Array([near_left + Vector2(0, 8), near_right + Vector2(0, 8), near_right + Vector2(0, 24), near_left + Vector2(0, 24)]), Color("897252"))
	draw_line(near_left + Vector2(0, 8), near_right + Vector2(0, 8), Color("e0d1ad"), 4)
	draw_rect(Rect2(0, 520, 960, 80), Color("142831"))
	draw_rect(Rect2(0, 0, 960, 112), Color("101f27"))
	text_at("ON ICE", Vector2(30, 40), 29)
	text_at("A WINTER CLASSIC", Vector2(32, 64), 11, Color("a9bdb6"))
	text_at("1924 — 1927  /  PROTOTYP 0.3", Vector2(32, 88), 10, Color("d1ae68"))
	centered("BOSTON    %d  :  %d    MONTREAL" % [scores[0], scores[1]], 47, 24)
	var seconds := ceili(remaining)
	centered("TRÉNING  •  %02d:%02d" % [seconds / 60, seconds % 60], 78, 14, Color("a9bdb6"))
	text_at("3 + BRANKÁR", Vector2(805, 43), 13)
	text_at("ÚTOK  →", Vector2(812, 69), 13, Color("d1ae68"))
	centered("ŠÍPKY  pohyb     C  prihrávka / zmena hráča     MEDZERNÍK  strela     X  vypichnutie", 551, 14)
	centered("ESC  pauza     R  nový zápas   •   Dobové pravidlá a plné zostavy pripravujeme", 578, 12, Color("9aafa9"))
	draw_rink_map()
	if banner_time > 0 and mode == "play":
		centered(banner, 183, 22, Color("f0cf84"))
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

func draw_rink_map() -> void:
	# The map shows offscreen teammates, both goals and the visible camera window.
	var map_rect := Rect2(340, 121, 280, 30)
	draw_rect(map_rect, Color("314941"))
	draw_rect(map_rect, Color("6f8a7c"), false, 1)
	var visible_left := clampf((camera_x - 480 - RINK.position.x) / RINK.size.x, 0, 1)
	var visible_right := clampf((camera_x + 480 - RINK.position.x) / RINK.size.x, 0, 1)
	draw_rect(Rect2(map_rect.position + Vector2(visible_left * 280, 0), Vector2((visible_right - visible_left) * 280, 30)), Color(0.8, 0.9, 0.8, 0.12))
	for i in range(skaters.size()):
		var normalized: Vector2 = (skaters[i].pos - RINK.position) / RINK.size
		var position := map_rect.position + normalized * map_rect.size
		draw_circle(position, 2.5 if i != selected else 3.5, Color("d4aa50") if skaters[i].team == 0 else Color("e16c5d"))
	var puck_point := map_rect.position + (puck - RINK.position) / RINK.size * map_rect.size
	draw_circle(puck_point, 2, Color("f2eedb"))

func draw_skater(index: int) -> void:
	var s: Dictionary = skaters[index]
	var p := ice_to_screen(s.pos).round()
	if p.x < -120 or p.x > 1080:
		return
	var depth: float = (s.pos.y - RINK.position.y) / RINK.size.y
	var scale_factor := lerpf(0.85, 1.05, depth)
	var facing := 1.0 if s.face.x >= 0 else -1.0
	if index == selected:
		draw_set_transform(p + Vector2(0, 4), 0, Vector2(2.7, 0.40))
		draw_arc(Vector2.ZERO, 10, 0, TAU, 24, Color("a87629"), 2)
		draw_set_transform(Vector2.ZERO)
		var marker_y := -105 * scale_factor
		draw_colored_polygon(PackedVector2Array([p + Vector2(-5, marker_y - 8), p + Vector2(5, marker_y - 8), p + Vector2(0, marker_y)]), Color("ba7b26"))
	draw_set_transform(p + Vector2(0, 4), 0, Vector2(2.2, 0.25))
	draw_circle(Vector2.ZERO, 10, Color(0.15, 0.26, 0.24, 0.22))
	draw_set_transform(p, 0, Vector2(facing * scale_factor, scale_factor))
	var texture: Texture2D = kit_idle[s.team]
	if s.effort > 0.2:
		texture = kit_frames[s.team][int(s.phase * 8) % 8]
	draw_texture(texture, Vector2(-42, -106))
	# Leather goalie pads are layered over the same editable uniform frames.
	if s.slot == 3:
		draw_rect(Rect2(-13, -28, 10, 26), Color("af9672"))
		draw_rect(Rect2(4, -28, 10, 26), Color("c8b18b"))
		for pad_y in [-23, -16, -9]:
			draw_line(Vector2(-12, pad_y), Vector2(-4, pad_y), Color("796c51"), 1)
			draw_line(Vector2(5, pad_y), Vector2(13, pad_y), Color("796c51"), 1)
	draw_set_transform(Vector2.ZERO)
	# Numbers stay readable on both facings, rather than mirroring the glyphs.
	var number_position := p + Vector2(-10 * facing - 3, -51) * scale_factor
	text_at(str(2 + s.slot + s.team * 5), number_position, int(10 * scale_factor), Color("efdfb7"))
