extends TestCase
## A gamepad drives the menus (A presses, B backs out), and the right stick
## swings the lamp round quickly but smoothly, over the top when it turns
## right about.


func test_a_presses_and_b_backs_out() -> void:
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	check(a.is_action(&"ui_accept"), "A presses the focused button")
	check(b.is_action(&"ui_cancel"), "B backs out")


func test_the_lamp_swings_round_smoothly() -> void:
	var aim := Vector2(1.0, 0.0)
	var target := Vector2(-1.0, 0.0)
	var dt := 1.0 / 60.0
	var steps := 0
	var went_over_the_top := false
	while aim.dot(target) < 0.999 and steps < 120:
		aim = Submarine.turn_towards(aim, target, Submarine.AIM_TURN_RATE * dt)
		went_over_the_top = went_over_the_top or aim.y > 0.5
		steps += 1
	check(steps > 5, "it does not jump (%d frames)" % steps)
	check(steps * dt < 0.4, "but it is quick (%.2f s)" % (steps * dt))
	check(went_over_the_top, "and sweeps over the top of the cave")
	# Back the other way, it swings over the top again.
	went_over_the_top = false
	for i in 60:
		aim = Submarine.turn_towards(aim, Vector2(1.0, 0.0), Submarine.AIM_TURN_RATE * dt)
		went_over_the_top = went_over_the_top or aim.y > 0.5
	check(went_over_the_top, "both ways")
