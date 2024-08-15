extends Node

# this is best thought of as managing the client with our player on it
# while also communicating with other clients

# main menu and address bar controls
@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry

# HUD
@onready var hud = $CanvasLayer/HUD
@onready var health_bar = $CanvasLayer/HUD/HealthBar


# port to host the server on
const PORT = 9999
# ENET
var enet_peer = ENetMultiplayerPeer.new()

# reference to the player scene so we can instantiate it
const Player = preload("res://Scenes/player.tscn")

# to let us quit at any time by pressing Escape (the quit action we defined in the input map)
func _unhandled_input(event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	
# when the player clicks the host button
func _on_host_button_pressed():
	# hide the main menu (or you could change scenes?)
	main_menu.hide()
	
	# create local server on port PORT
	enet_peer.create_server(PORT)
	# built-in stuff to set the multiplayer peer to the enet peer we've instantiated
	multiplayer.multiplayer_peer = enet_peer
	# now the server's running, once a client connects, we should call add_player
	# connect the peer_connected signal to add_player to do this
	multiplayer.peer_connected.connect(add_player)
	# also connect up peer_disconnected so we can track if a player quits
	multiplayer.peer_disconnected.connect(remove_player)
	
	# add the host as a player
	add_player(multiplayer.get_unique_id())
	
	# setup UPNP on the server side
	upnp_setup()
	
	# show HUD
	hud.show()

# when the player clicks the join button:
func _on_join_button_pressed():
	# hide the main menu (or you could change scenes?)
	main_menu.hide()
	
	# create client to join server at address and port
	enet_peer.create_client(address_entry.text, PORT)
	# built-in stuff to set the multiplayer peer to the enet peer we've instantiated
	multiplayer.multiplayer_peer = enet_peer
	
	add_player(multiplayer.get_unique_id())
	
	# show HUD
	hud.show()
	
	
# method for the world to spawn a player
func add_player(peer_id):
	var player = Player.instantiate()
	# players have a unique peer_id for authority purposes
	player.name = str(peer_id)
	# add to world tree
	add_child(player)
	# if this is the player's own client, connect the health bar up
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)
	
# method for the world to despawn a player	
func remove_player(peer_id):
	# identify player node by peer_id
	var player = get_node_or_null(str(peer_id))
	# if the player node is not null
	if player:
		# delete the player node
		player.queue_free()
		
# function to update the health bar on this client
func update_health_bar(health_value):
	health_bar.value = health_value

# connect health bar up on spawn for our client
func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)

# Universal Plug and Play for internet play
# your router might need to enable this
func upnp_setup():
	var upnp = UPNP.new()
	
	# look for UPNP-enabled router
	
	var discover_result = upnp.discover()
	# assert that it's successful - if it's not, print an error code
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Discover Failed! Error %s" % discover_result)
	# check valid gateway
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), "UPNP Invalid Gateway!")
	
	# UPNP does automatic port forwarding. We want to get the port mapping, and if it doesn't work, print an error
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Port Mapping Failed! Error %s" % map_result)
	# print server's external facing IP address - be careful
	print("Success! Join Address: %s" % upnp.query_external_address())
