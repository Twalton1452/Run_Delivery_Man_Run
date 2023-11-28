extends MultiplayerSpawner

@onready var parent_node = get_node(spawn_path)

var player_scene : PackedScene = preload("res://scenes/Player.tscn")

func _ready() -> void:
	spawn_function = spawn_player
	
	if not is_multiplayer_authority():
		return
	
	spawn_already_connected_players()
	spawn(multiplayer.get_unique_id()) # Spawn self
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func spawn_player(id: int) -> Node:
	var player : Player = player_scene.instantiate()
	player.name = str(id)
	player.get_node("PlayerInput").set_multiplayer_authority(id)
	player.position = Vector3(0, 0.5, 0)
	return player

func spawn_already_connected_players() -> void:
	for peer_id in multiplayer.get_peers():
		spawn(peer_id)

func _on_peer_connected(id: int) -> void:
	spawn(id)

func _on_peer_disconnected(id: int) -> void:
	var player = parent_node.find_child(str(id))
	if player == null:
		return
	
	player.queue_free()
