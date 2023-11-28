extends CharacterBody3D
class_name Player

const WALK_SPEED = 5.0
const JUMP_VELOCITY = 4.5
const BASE_FOV = 75.0
const FOV_CHANGE = 2.0

@onready var PHYSICS_DELTA = 1.0 / Engine.physics_ticks_per_second
@onready var player_input : PlayerInput = $PlayerInput
@onready var camera : Camera3D = $Camera3D

var look_speed = .005
var move_speed = WALK_SPEED

var pending_inputs_buffer := CircularBuffer.new(16)
var position_buffer : Array[Array] = []
var last_processed_sequence := -1
var to_process_sequence_upper_bound := -1

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@rpc("authority", "call_remote", "unreliable")
func notify_clients_of_new_position(last_processed_sequence_id: int, new_position: Vector3, y_velocity: float) -> void:
	# Clientside interpolation
	if not player_input.is_multiplayer_authority():
		position_buffer.push_back([Time.get_unix_time_from_system(), new_position])
	# Server Reconciliation
	else:
		# Gravity isn't deterministic in the [move] function, so for now I'm passing the y velocity
		# That way when we resimulate input, the y_velocity is correct and there
		# is no visual jitter because we're falling faster than before the simulation
		velocity.y = y_velocity
		player_input.server_reconciliation(last_processed_sequence_id, new_position)

## Received Input from Client Player
## To be processed during the next physics frame
@rpc("any_peer", "call_remote", "unreliable_ordered")
func send_input_to_server(direction: Vector3, jump: int, delta: float, sequence_number: int):
	if not is_correct_player(multiplayer.get_remote_sender_id()):
		return
	
	# Input Validation
	if !is_valid_direction(direction) or !is_valid_delta(delta):
		push_warning("Got invalid input from: ", multiplayer.get_remote_sender_id(), " | Direction: ", direction, " Delta: ", delta)
		return
	
	queue_input(direction, jump, delta, sequence_number)

## Server receives Input from clients and moves them
func _physics_process(delta):
	# Clientside interpolation
	if not player_input.is_multiplayer_authority():
		var timestamp = Time.get_unix_time_from_system() - delta
		
		# Drop older positions
		while position_buffer.size() >= 2 && position_buffer[1][0] <= timestamp:
			position_buffer.pop_front()
		
		if position_buffer.size() >= 2 && position_buffer[0][0] <= timestamp && timestamp <= position_buffer[1][0]:
			var pos0 = position_buffer[0][1]
			var pos1 = position_buffer[1][1]
			var t0 = position_buffer[0][0]
			var t1 = position_buffer[1][0]
			position = pos0 + (pos1 - pos0) * (timestamp - t0) / (t1 - t0);
	
	if not is_multiplayer_authority():
		return
	
	# Server Movement
	var processed_inputs = last_processed_sequence < to_process_sequence_upper_bound
	while last_processed_sequence < to_process_sequence_upper_bound:
		var pending_input = pending_inputs_buffer.get_item(last_processed_sequence + 1)
		# Lost a packet
		if pending_input == null:
			last_processed_sequence += 1
			push_warning("Server seems to have missed a packet for Sequence#: ", last_processed_sequence)
			break
		
		move(pending_input.direction, pending_input.jump, pending_input.delta)
#		print("[Server Seq# %d] Velocity %s" % [pending_input.sequence_number, str(velocity)])
		last_processed_sequence = pending_input.sequence_number
		pending_inputs_buffer.remove_at(last_processed_sequence)
	
	if processed_inputs:
		notify_clients_of_new_position.rpc(last_processed_sequence, position, velocity.y)
		return
	
	# Player isn't trying to influence their air direction
	if not is_on_floor():
		# Add the gravity.
		apply_idle_gravity()
		notify_clients_of_new_position.rpc(last_processed_sequence, position, velocity.y)

## Player isn't inputting anything, but they're airborne
func apply_idle_gravity() -> void:
	if not is_on_floor():
		velocity.y -= gravity * PHYSICS_DELTA
		move_and_slide()

## Based on the velocity, change the camera's FOV
## not used at the moment because the x,z velocity don't reset to 0
## so the fov never changes back once it gets modified unless hitting a wall
func movement_based_fov_change() -> void:
	var velocity_clamped = clamp(velocity.length(), 0.5, move_speed * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, PHYSICS_DELTA * 8.0)

func move(direction: Vector3, jump: int, delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle Jump.
	if jump > 0 and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if is_on_floor():
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		# After a jump, allow the player to influence the direction slightly
		if direction:
			velocity.x = lerp(velocity.x, direction.x * move_speed, delta * 2.0)
			velocity.z = lerp(velocity.z, direction.z * move_speed, delta * 2.0)
	
	move_and_slide()

## The player needs to give the server a normal vector and it will apply speeds
func is_valid_direction(direction: Vector3) -> bool:
	return direction == Vector3.ZERO or direction.is_normalized()

## Too large of a delta could move the player forward more than expected
func is_valid_delta(delta: float) -> bool:
	return delta < 0.5

## Ensure the sender can execute RPCs on this entity
## This could likely be spoofed, but it's an extra layer of obfuscation
func is_correct_player(sender_id: int) -> bool:
	return sender_id == player_input.get_multiplayer_authority()

func queue_input(direction: Vector3, jump: int, delta: float, sequence_number: int) -> void:
#	pending_inputs.push_back(PendingInput.new(direction, jump, delta, sequence_number))
	pending_inputs_buffer.insert_item(sequence_number, PendingInput.new(direction, jump, delta, sequence_number))
	# Take the largest sequence and we'll work forward from our last_processed_sequence
	to_process_sequence_upper_bound = max(to_process_sequence_upper_bound, sequence_number)
	# start seq = 
