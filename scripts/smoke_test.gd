extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var match_scene = load("res://main.tscn").instantiate()
	root.add_child(match_scene)
	match_scene.set_physics_process(false)
	match_scene.start_match()
	# The side camera preserves the long axis but compresses rink depth.
	var far_left: Vector2 = match_scene.ice_to_screen(Vector2(80, 210))
	var far_right: Vector2 = match_scene.ice_to_screen(Vector2(880, 210))
	var near_left: Vector2 = match_scene.ice_to_screen(Vector2(80, 490))
	var near_right: Vector2 = match_scene.ice_to_screen(Vector2(880, 490))
	assert(far_left.y == far_right.y and near_left.y == near_right.y, "Rink axis stays horizontal")
	assert(near_left.y > far_left.y and near_left.y - far_left.y < 150, "Low side camera compresses depth")
	assert(near_right.x - near_left.x > far_right.x - far_left.x, "Perspective narrows the far side")
	assert(match_scene.skaters.size() == 8, "Both teams must spawn")
	match_scene.holder = 1
	match_scene.puck = match_scene.skaters[1].pos
	match_scene.shoot(1)
	assert(match_scene.holder == -1 and match_scene.puck_velocity.x > 0, "Boston shot heads right")
	match_scene.holder = 1
	match_scene.pass_puck(1)
	assert(match_scene.holder == -1 and match_scene.selected != 1, "Pass changes controlled teammate")
	match_scene.reset_faceoff()
	match_scene.puck = Vector2(879, 350)
	match_scene.puck_velocity = Vector2(620, 0)
	match_scene.advance_puck(0.03)
	assert(match_scene.scores == [1, 0], "Right net counts Boston goal")
	match_scene.puck = Vector2(81, 350)
	match_scene.puck_velocity = Vector2(-620, 0)
	match_scene.advance_puck(0.03)
	assert(match_scene.scores == [1, 1], "Left net counts Montreal goal")
	match_scene.puck = Vector2(879, 260)
	match_scene.puck_velocity = Vector2(620, 0)
	match_scene.advance_puck(0.03)
	assert(match_scene.puck_velocity.x < 0 and match_scene.scores == [1, 1], "Outside net bounces")
	match_scene.reset_faceoff()
	match_scene.pickup_delay = 0
	match_scene.puck = match_scene.skaters[0].pos
	match_scene.step_match(1.0 / 60)
	assert(match_scene.holder == 0 and match_scene.selected == 0, "Pickup selects Boston carrier")
	match_scene.mode = "paused"
	var time_before: float = match_scene.remaining
	match_scene._physics_process(1)
	assert(match_scene.remaining == time_before, "Pause freezes clock")
	match_scene.mode = "play"
	match_scene.remaining = 0.01
	match_scene._physics_process(0.02)
	assert(match_scene.mode == "over", "Clock ends match")
	match_scene.start_match()
	for tick in range(3600):
		match_scene._physics_process(1.0 / 60)
		assert(is_finite(match_scene.puck.x) and is_finite(match_scene.puck.y), "Finite puck state")
	print("PASS: spawn, shooting, passing, both goals, boards, pickup, pause, clock and 60-second simulation")
	quit()
