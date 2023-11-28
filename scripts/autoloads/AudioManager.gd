extends Node

## Autoloaded

@onready var music_player : AudioStreamPlayer = $Music

func _ready():
	# Unmute by default when exported
	# Adjust based on player settings
	if OS.has_feature("standalone"):
		for i in AudioServer.bus_count:
			AudioServer.set_bus_mute(i, false)

func change_to(music_clip: AudioStream) -> void:
	music_player.stream = music_clip
	music_player.play()

func play_one_shot(sfx: AudioStream) -> void:
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	sfx_player.stream = sfx
	add_child(sfx_player)
	sfx_player.play()
	await sfx_player.finished
	sfx_player.queue_free()
