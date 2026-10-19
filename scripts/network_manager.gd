extends Node
## Minimal ENet lobby for 2-4 players (host = server, runs the monster AI).

signal player_list_changed
signal connection_failed

const PORT := 7777
const MAX_PLAYERS := 4

var names: Dictionary = {}   # peer_id -> display name


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): connection_failed.emit())
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	names = {1: Game.player_name}
	player_list_changed.emit()
	return OK


func join(ip: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	multiplayer.multiplayer_peer = null
	names.clear()


func start_match() -> void:
	if multiplayer.is_server():
		_begin.rpc()


func _on_connected() -> void:
	register_name.rpc_id(1, Game.player_name)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		names.erase(id)
		_sync_names.rpc(names)


@rpc("any_peer", "reliable")
func register_name(n: String) -> void:
	if not multiplayer.is_server():
		return
	names[multiplayer.get_remote_sender_id()] = n.left(20)
	_sync_names.rpc(names)


@rpc("authority", "call_local", "reliable")
func _sync_names(d: Dictionary) -> void:
	names = d
	player_list_changed.emit()


@rpc("authority", "call_local", "reliable")
func _begin() -> void:
	Game.start_game(false)
