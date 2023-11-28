extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var main_menu_audio_player = $CanvasLayer/MainMenu/AudioStreamPlayer
@onready var address_entry = $CanvasLayer/MainMenu/PanelContainer/MarginContainer/VBoxContainer/IPAddressEntry

const PORT = 9998

func _ready():
	$CanvasLayer/MainMenu/PanelContainer/MarginContainer/VBoxContainer/HostButton.grab_focus()

func _unhandled_input(event):
	if event.is_action_pressed("options"):
		# show menu instead
		_on_quit_button_pressed()

func _on_host_button_pressed():
	var enet_peer = ENetMultiplayerPeer.new()
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	if OS.has_feature("standalone"):
		upnp_setup()
	
	host_or_join()

func _valid_ip_address() -> bool:
	if OS.has_feature("standalone"):
		return address_entry.text.length() > 0
	return true

func _valid_server() -> bool:
	# TODO: Check if the ipaddress entered has a server running
	return true

func _on_join_button_pressed():
	if not _valid_ip_address() or not _valid_server():
		return
	
	var enet_peer = ENetMultiplayerPeer.new()
	
	if OS.has_feature("standalone"):
		enet_peer.create_client(address_entry.text, PORT)
	else:
		enet_peer.create_client("localhost", PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.server_disconnected.connect(server_disconnect)
	host_or_join()

func server_disconnect():
	get_tree().quit()

func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discover Failed! Error %s" % discover_result)
	
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")
	
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Success! Join Address: %s" % upnp.query_external_address())

func cleanup_main_menu() -> void:
	pass

func host_or_join():
	main_menu_audio_player.play()
	main_menu.hide()
	cleanup_main_menu()
	
	# Only change level on the server.
	# Clients will instantiate the level via the spawner.
	if multiplayer.is_server():
		LevelManager.go_to_first_level()
	else:
		Transition.fade_out()

func _on_quit_button_pressed():
	get_tree().quit.call_deferred()

