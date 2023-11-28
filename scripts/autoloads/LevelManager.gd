extends Node

## Autoloaded

var level_store : LevelStore = load("res://resources/StandardLevels.tres")

@onready var level_parent : Node = $Level
@onready var level_spawner : MultiplayerSpawner = $LevelSpawner
@onready var level_change_audio_player : AudioStreamPlayer = $LevelChangeSFX

var current_level_index = 0
var current_level: Node = null
var is_changing_levels = false

func _ready():
	# when exporting, make sure it has the correct levels
	if OS.has_feature("standalone"):
		level_store = load("res://resources/StandardLevels.tres")
	
	# Avoid needing to set the MultiplayerSpawner scenes manually
	var level_spawn_paths = []
	for level in level_store.levels:
		level_spawn_paths.push_back(level.resource_path)
	level_spawner._spawnable_scenes = level_spawn_paths

func go_to_first_level() -> void:
	current_level_index = 0
	change_level.call_deferred(level_store.levels[current_level_index])

func go_to_next_level() -> void:
	if current_level_index < level_store.levels.size() - 1:
		current_level_index += 1
		change_level.call_deferred(level_store.levels[current_level_index])
	else:
		go_to_first_level()

func go_to_previous_level() -> void:
	if current_level_index == 0:
		current_level_index = level_store.levels.size() - 1
	else:
		current_level_index -= 1
	change_level.call_deferred(level_store.levels[current_level_index])

func reset_level() -> void:
	change_level.call_deferred(level_store.levels[current_level_index])

func _on_finished_level() -> void:
	go_to_next_level()

# Call this function deferred and only on the main authority (server).
func change_level(scene: PackedScene):
	if not is_multiplayer_authority():
		return
	
	notify_everyone_changing_level.rpc()
	is_changing_levels = true
	level_change_audio_player.play()
	
	await Transition.fade_out()
	
	if not scene.resource_path in level_spawner._spawnable_scenes:
		push_warning("You forgot to add ", scene.resource_path, " to the list of spawnable scenes on the LevelSpawner")
	
	# Remove old level if any.
	if current_level != null:
		current_level.process_mode = Node.PROCESS_MODE_DISABLED
		
		if current_level.has_signal("finished_level") and current_level.finished_level.is_connected(_on_finished_level):
			current_level.finished_level.disconnect(_on_finished_level)
		
		for c in level_parent.get_children():
			remove_child(c)
			c.queue_free()
	
		current_level.queue_free()
	
	# Let the game world clean up
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Add new level.
	current_level = scene.instantiate()
	level_parent.add_child(current_level)
	current_level.show()
	
	Transition.fade_in()
	
	# Wait for players to complete the level
	if current_level.has_signal("finished_level") and !current_level.finished_level.is_connected(_on_finished_level):
		current_level.finished_level.connect(_on_finished_level)
	is_changing_levels = false

# The server can restart the level by pressing Home. Mostly for debugging
func _input(event):
	if not is_multiplayer_authority() or is_changing_levels:
		return
	
	if event.is_action_pressed("restart_level"):
		reset_level()
	elif event.is_action_pressed("next_level"):
		go_to_next_level()
	elif event.is_action_pressed("previous_level"):
		go_to_previous_level()

func _on_level_spawner_spawned(node):
	current_level = node
	current_level_index += 1 # unlikely to always work
	level_change_audio_player.play()
	
	# If the level is loaded in faster than we can fade out, hide it
	if Transition.in_progress:
		current_level.hide()
		await Transition.finished
	
	# Show the level since the screen should be faded out by this point
	current_level.show()
	Transition.fade_in()

func disable_player_syncing() -> void:
	pass

@rpc("authority", "call_local")
func notify_everyone_changing_level() -> void:
	disable_player_syncing()
