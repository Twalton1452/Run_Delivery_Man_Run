extends Node
class_name PlayerInput

@export var x := 0.0
@export var y := 0.0
@export var jumping := 0
@export var sequence_number := 0

@onready var player : Player = get_parent()

var pending_inputs_buffer := CircularBuffer.new(16)

func _ready() -> void:
	if not is_multiplayer_authority():
		return
	
	setup.call_deferred()

func setup() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.camera.current = true

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return
	
	# Only used to exit the game currently
	if event.is_action_pressed("unlock_cursor"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * player.look_speed)
		player.camera.rotate_x(-event.relative.y * player.look_speed)
		player.camera.rotation.x = clamp(player.camera.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	
	jumping = Input.is_action_pressed("jump")

	x = Input.get_axis("left", "right")
	y = Input.get_axis("up", "down")
	
	var player_didnt_press_anything = jumping == 0 and x == 0 and y == 0
	if player_didnt_press_anything:
		# Simulate gravity when client doesn't press anything
		# to keep client-side falling looking smooth
		if not multiplayer.is_server():
			player.apply_idle_gravity()
		return
	
	# Capture direction during input because we let the player have authority
	# over their own rotation
	var direction = (player.transform.basis * Vector3(x, 0, y)).normalized()
	
	if multiplayer.is_server():
		player.queue_input(direction, jumping, delta, sequence_number)
		sequence_number += 1
		return
	
	# Hold onto the input until its acknowledged by the server
	var pending_input = PendingInput.new(direction, jumping, delta, sequence_number)
	pending_inputs_buffer.insert_item(sequence_number, pending_input)
	player.send_input_to_server.rpc_id(1, direction, jumping, delta, sequence_number)
	sequence_number += 1
	
	# Clientside Prediction - Simulate player movement
	player.move(direction, jumping, delta)
#	print("[Client Seq# %d] Velocity %s" % [sequence_number - 1, str(player.velocity)])
	pending_input.set_result(player.position)
	
## Find the input the server just processed and check if our results match within reason
## If they do match within reason then simply continue on as normal
## If they do not match then set our position to the server's position and resimulate our inputs
func server_reconciliation(last_processed_sequence: int, server_resulting_position: Vector3) -> void:
	player.position = server_resulting_position
	resimulate_inputs(last_processed_sequence)

## Reapplying our inputs since the last server reconciliation
func resimulate_inputs(last_processed_sequence: int) -> void:
	var i = last_processed_sequence + 1 # Need to resimulate the unprocessed inputs
	while i < sequence_number:
		var pi = pending_inputs_buffer.get_item(i)
		if pi == null:
			break
		
		player.move(pi.direction, pi.jump, pi.delta)
		pi.set_result(player.position)
		i += 1
