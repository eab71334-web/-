extends Node
## Minimal ENet lobby for 2-4 players (host = server, runs the monster AI).

signal player_list_changed
signal connection_failed
signal games_changed

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
	stop_broadcast()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
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
	stop_broadcast()
	stop_listen()
	Game.start_game(false)


# ------------------------------------------------------------------ LAN discovery (UDP broadcast)
const DISCOVERY_PORT := 7778

var found: Dictionary = {}      # ip -> {host, players, max, t}
var broadcasting := false
var listening := false
var _bc: PacketPeerUDP
var _ls: PacketPeerUDP
var _bc_t := 0.0


func local_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		var parts: PackedStringArray = a.split(".")
		if parts.size() != 4:
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or (parts[0] == "172" and int(parts[1]) >= 16 and int(parts[1]) <= 31):
			out.append(a)
	return out


func start_broadcast() -> void:
	stop_broadcast()
	_bc = PacketPeerUDP.new()
	_bc.set_broadcast_enabled(true)
	broadcasting = true
	_bc_t = 0.0


func stop_broadcast() -> void:
	if _bc != null:
		_bc.close()
		_bc = null
	broadcasting = false


func start_listen() -> void:
	stop_listen()
	_ls = PacketPeerUDP.new()
	if _ls.bind(DISCOVERY_PORT) == OK:
		listening = true
	else:
		_ls = null


func stop_listen() -> void:
	if _ls != null:
		_ls.close()
		_ls = null
	listening = false
	found.clear()


func _process(delta: float) -> void:
	if broadcasting and _bc != null:
		_bc_t -= delta
		if _bc_t <= 0.0:
			_bc_t = 1.0
			var msg := JSON.stringify({"g": "SKS1", "host": Game.player_name, "players": names.size(), "max": MAX_PLAYERS})
			var targets: Array = ["255.255.255.255"]
			for ip in local_ips():
				var p: PackedStringArray = ip.split(".")
				targets.append("%s.%s.%s.255" % [p[0], p[1], p[2]])
			for t in targets:
				_bc.set_dest_address(t, DISCOVERY_PORT)
				_bc.put_packet(msg.to_utf8_buffer())
	if listening and _ls != null:
		var changed := false
		var now := Time.get_ticks_msec()
		while _ls.get_available_packet_count() > 0:
			var raw := _ls.get_packet()
			var ip := _ls.get_packet_ip()
			var j = JSON.parse_string(raw.get_string_from_utf8())
			if j is Dictionary and j.get("g", "") == "SKS1":
				found[ip] = {"host": str(j.get("host", "?")), "players": int(j.get("players", 1)), "max": int(j.get("max", MAX_PLAYERS)), "t": now}
				changed = true
		for ip in found.keys():
			if now - int(found[ip]["t"]) > 4000:
				found.erase(ip)
				changed = true
		if changed:
			games_changed.emit()
