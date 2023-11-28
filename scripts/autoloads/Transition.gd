extends Node

## Autoloaded

signal finished

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var transition_texture: TextureRect = $CanvasLayer/TextureRect

const FADE_OUT_DURATION_SECONDS = 0.33
const FADE_IN_DURATION_SECONDS = 0.15

var in_progress = false : set = _set_inprogress

func _set_inprogress(value: bool):
	in_progress = value
	if !in_progress:
		finished.emit()

func _ready():
	canvas_layer.hide()
	transition_texture.modulate = Color(0,0,0,0)

func fade_out() -> Signal:
	if in_progress:
		await finished
	in_progress = true
	var tween = create_tween()
	transition_texture.modulate = Color(0,0,0,0)
	canvas_layer.show()
	tween.tween_property(transition_texture, "modulate", Color(0,0,0,1.0), FADE_OUT_DURATION_SECONDS).set_ease(Tween.EASE_IN)
	if multiplayer.is_server():
		notify_peers_of_fade_out.rpc()
	wait_for_fade_out_finish(tween)
	return tween.finished

func wait_for_fade_out_finish(tween: Tween) -> void:
	await tween.finished
	in_progress = false

func fade_in() -> void:
	if in_progress:
		await finished
	in_progress = true
	var tween = create_tween()
	transition_texture.modulate = Color(0,0,0,1.0)
	canvas_layer.show()
	tween.tween_property(transition_texture, "modulate", Color(0,0,0,0.0), FADE_IN_DURATION_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	canvas_layer.hide()
	in_progress = false

@rpc("authority", "call_remote")
func notify_peers_of_fade_out() -> void:
	fade_out()
