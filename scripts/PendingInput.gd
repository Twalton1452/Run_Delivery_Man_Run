class_name PendingInput

## Class to store input data for a given frame for Server Reconciliation
## Player will hold onto this until the server acknowledges it
## Until the server acknowledges this instance then the Client replays every
## PendingInput performed after resetting their position
## If structs were a thing this would be a struct.

# Info about Delta time and why it isn't being stored:
# Holding onto the Delta inbetween frames of input is useful for consistency
# in replaying the actions, but  since we're grabbing input during physics ticks
# and simulating movement in the same tick on the client and the server is 
# processing movement in the physics_process, the rate should always be consistent
# 1/physics_ticks as long as the physics server doesn't waver it should work

var direction : Vector3
var jump : int
var delta: float
var sequence_number : int
var resulting_position : Vector3

func _init(_direction: Vector3, _jump: int, _delta: float, _sequence_number: int):
	direction = _direction
	jump = _jump
	delta = _delta
	sequence_number = _sequence_number

func set_result(pos: Vector3) -> void:
	resulting_position = pos
