@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

func get_commands() -> Dictionary:
	return {
		"setup_multiplayer":            _setup_multiplayer,
		"setup_enet_peer":              _setup_enet_peer,
		"setup_websocket_peer":         _setup_websocket_peer,
		"get_multiplayer_info":         _get_multiplayer_info,
		"rpc_config":                   _rpc_config,
		"setup_multiplayer_spawner":    _setup_multiplayer_spawner,
		"setup_multiplayer_synchronizer": _setup_multiplayer_synchronizer,
		"http_request":                 _http_request,
		"get_network_stats":            _get_network_stats,
		"disconnect_peer":              _disconnect_peer,
		"get_socket_state":             _get_socket_state,
		"list_multiplayer_peers":       _list_multiplayer_peers,
	}

func _v3(p: Dictionary, k: String, d: Vector3) -> Vector3:
	if not p.has(k): return d
	var v=p[k]
	if v is Dictionary: return Vector3(float(v.get("x",d.x)),float(v.get("y",d.y)),float(v.get("z",d.z)))
	return d

func _add(node: Node, parent: Node, root: Node, label: String) -> void:
	var ur := get_undo_redo()
	ur.create_action(label)
	ur.add_do_method(parent,"add_child",node)
	ur.add_do_method(node,"set_owner",root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent,"remove_child",node)
	ur.commit_action()

func _pr(params: Dictionary) -> Array:
	var root := get_edited_root()
	if root == null: return [null,null,error_no_scene()]
	var pp: String = optional_string(params,"parent_path",".")
	var parent := find_node_by_path(pp)
	if parent == null: return [null,null,error_not_found("Parent '%s'" % pp)]
	return [parent,root,null]

## 1. setup_multiplayer — configure MultiplayerAPI role on a node
func _setup_multiplayer(params: Dictionary) -> Dictionary:
	var res := require_string(params,"node_path"); if res[1]: return res[1]
	var node := find_node_by_path(res[0])
	if node == null: return error_not_found("Node '%s'" % res[0])
	var role: String = optional_string(params,"role","none")
	# MultiplayerPeer roles are set at runtime; store as metadata for guidance
	node.set_meta("mcp_mp_role", role)
	node.set_meta("mcp_mp_port", optional_int(params,"port",7777))
	node.set_meta("mcp_mp_max_peers", optional_int(params,"max_peers",32))
	return success({
		"node_path": res[0],
		"role": role,
		"note": "Multiplayer peers are initialized at runtime. Attach a script using ENetMultiplayerPeer/WebSocketMultiplayerPeer and call multiplayer.multiplayer_peer = peer."
	})

## 2. setup_enet_peer — add ENetMultiplayerPeer guidance node
func _setup_enet_peer(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var n := Node.new()
	n.name = optional_string(params,"name","ENetPeerConfig")
	n.set_meta("mcp_enet_host",   optional_string(params,"host","127.0.0.1"))
	n.set_meta("mcp_enet_port",   optional_int(params,"port",7777))
	n.set_meta("mcp_enet_role",   optional_string(params,"role","server"))
	n.set_meta("mcp_enet_peers",  optional_int(params,"max_peers",32))
	n.set_meta("mcp_enet_channels", optional_int(params,"max_channels",0))
	n.set_meta("mcp_enet_bandwidth_in",  optional_int(params,"bandwidth_in",0))
	n.set_meta("mcp_enet_bandwidth_out", optional_int(params,"bandwidth_out",0))
	_add(n,parent,root,"MCP: Add ENetPeerConfig")
	var role: String = n.get_meta("mcp_enet_role")
	var port: int    = n.get_meta("mcp_enet_port")
	var host: String = n.get_meta("mcp_enet_host")
	var code_hint: String
	if role == "server":
		code_hint = "var peer = ENetMultiplayerPeer.new()\npeer.create_server(%d)\nmultiplayer.multiplayer_peer = peer" % port
	else:
		code_hint = "var peer = ENetMultiplayerPeer.new()\npeer.create_client(\"%s\", %d)\nmultiplayer.multiplayer_peer = peer" % [host, port]
	return success({"node_path":str(root.get_path_to(n)),"role":role,"code_hint":code_hint})

## 3. setup_websocket_peer
func _setup_websocket_peer(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var n := Node.new()
	n.name = optional_string(params,"name","WebSocketPeerConfig")
	var role: String = optional_string(params,"role","client")
	var url: String  = optional_string(params,"url","ws://localhost:8080")
	n.set_meta("mcp_ws_role", role)
	n.set_meta("mcp_ws_url",  url)
	_add(n,parent,root,"MCP: Add WebSocketPeerConfig")
	var code_hint: String
	if role == "server":
		code_hint = "var peer = WebSocketMultiplayerPeer.new()\npeer.create_server(%d)\nmultiplayer.multiplayer_peer = peer" % optional_int(params,"port",8080)
	else:
		code_hint = "var peer = WebSocketMultiplayerPeer.new()\npeer.create_client(\"%s\")\nmultiplayer.multiplayer_peer = peer" % url
	return success({"node_path":str(root.get_path_to(n)),"code_hint":code_hint})

## 4. get_multiplayer_info — game-only, check if scene has mp nodes
func _get_multiplayer_info(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null: return error_no_scene()
	var spawners: Array = []; var syncs: Array = []
	var queue: Array = [root]
	while not queue.is_empty():
		var n: Node = queue.pop_front()
		if n is MultiplayerSpawner: spawners.append(str(root.get_path_to(n)))
		if n is MultiplayerSynchronizer: syncs.append(str(root.get_path_to(n)))
		for c in n.get_children(): queue.append(c)
	return success({"spawner_count":spawners.size(),"spawners":spawners,"synchronizer_count":syncs.size(),"synchronizers":syncs})

## 5. rpc_config — set rpc configuration metadata on a method
func _rpc_config(params: Dictionary) -> Dictionary:
	var res := require_string(params,"node_path"); if res[1]: return res[1]
	var method_res := require_string(params,"method"); if method_res[1]: return method_res[1]
	var node := find_node_by_path(res[0])
	if node == null: return error_not_found("Node '%s'" % res[0])
	var mode_str: String  = optional_string(params,"rpc_mode","authority")
	var sync_str: String  = optional_string(params,"transfer_mode","reliable")
	var call_local: bool  = optional_bool(params,"call_local",false)
	var channel: int      = optional_int(params,"channel",0)
	var code: String = "@rpc(\"%s\", \"%s\", %s, %d)\nfunc %s():\n\tpass" % [
		mode_str, sync_str,
		"call_local" if call_local else "no_local_call",
		channel, method_res[0]
	]
	return success({
		"node_path": res[0], "method": method_res[0],
		"rpc_mode": mode_str, "transfer_mode": sync_str,
		"call_local": call_local, "channel": channel,
		"code_hint": code
	})

## 6. setup_multiplayer_spawner
func _setup_multiplayer_spawner(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var ms := MultiplayerSpawner.new()
	ms.name = optional_string(params,"name","MultiplayerSpawner")
	if params.has("spawn_path"): ms.spawn_path = NodePath(str(params["spawn_path"]))
	for scene_path in params.get("spawn_limit_scenes",[]):
		if ResourceLoader.exists(str(scene_path)): ms.add_spawnable_scene(str(scene_path))
	ms.spawn_limit = optional_int(params,"spawn_limit",0)
	_add(ms,parent,root,"MCP: Add MultiplayerSpawner")
	return success({"node_path":str(root.get_path_to(ms)),"spawn_limit":ms.spawn_limit})

## 7. setup_multiplayer_synchronizer
func _setup_multiplayer_synchronizer(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var ms := MultiplayerSynchronizer.new()
	ms.name = optional_string(params,"name","MultiplayerSynchronizer")
	if params.has("root_path"): ms.root_path = NodePath(str(params["root_path"]))
	ms.replication_interval = float(params.get("replication_interval",0.0))
	ms.visibility_update_mode = MultiplayerSynchronizer.VISIBILITY_PROCESS_IDLE
	var properties: Array = params.get("properties",[])
	var sc := SceneReplicationConfig.new()
	for prop in properties:
		if prop is Dictionary:
			var np := NodePath(str(prop.get("path",".")))
			sc.add_property(np)
			var idx := sc.property_get_index(np)
			if idx >= 0:
				sc.property_set_sync(np, bool(prop.get("sync",true)))
				sc.property_set_watch(np, bool(prop.get("watch",false)))
	ms.replication_config = sc
	_add(ms,parent,root,"MCP: Add MultiplayerSynchronizer")
	return success({"node_path":str(root.get_path_to(ms)),"property_count":properties.size()})

## 8. http_request — add HTTPRequest node
func _http_request(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var hr := HTTPRequest.new()
	hr.name = optional_string(params,"name","HTTPRequest")
	hr.use_threads = optional_bool(params,"use_threads",true)
	hr.timeout = float(params.get("timeout",30.0))
	_add(hr,parent,root,"MCP: Add HTTPRequest")
	var url: String = optional_string(params,"url","")
	var code: String = ""
	if not url.is_empty():
		code = "$HTTPRequest.request(\"%s\")" % url
	return success({"node_path":str(root.get_path_to(hr)),"code_hint":code if not code.is_empty() else "Call $%s.request(url) to make a request." % hr.name})

## 9. get_network_stats — editor-side only checks scene tree
func _get_network_stats(_params: Dictionary) -> Dictionary:
	return success({
		"note": "Network stats (ping, packet loss) are only available at runtime via ENetConnection.get_peer() or multiplayer.multiplayer_peer.",
		"runtime_hint": "Use execute_game_script with: str(multiplayer.get_unique_id()) + ', peers: ' + str(multiplayer.get_peers())"
	})

## 10. disconnect_peer — returns script hint
func _disconnect_peer(params: Dictionary) -> Dictionary:
	var peer_id: int = optional_int(params,"peer_id",0)
	return success({
		"peer_id": peer_id,
		"code_hint": "multiplayer.multiplayer_peer.disconnect_peer(%d)" % peer_id,
		"note": "Run via execute_game_script while the game is running."
	})

## 11. get_socket_state — returns hint
func _get_socket_state(_params: Dictionary) -> Dictionary:
	return success({
		"note": "Socket state is a runtime value.",
		"code_hint": "str(multiplayer.multiplayer_peer.get_connection_status())"
	})

## 12. list_multiplayer_peers — scan scene for mp nodes
func _list_multiplayer_peers(_params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null: return error_no_scene()
	var mp_nodes: Array = []
	var queue: Array = [root]
	while not queue.is_empty():
		var n: Node = queue.pop_front()
		var info: Dictionary = {}
		if n is MultiplayerSpawner or n is MultiplayerSynchronizer:
			info = {"path":str(root.get_path_to(n)),"class":n.get_class()}
			if n.has_meta("mcp_mp_role"): info["role"] = n.get_meta("mcp_mp_role")
			mp_nodes.append(info)
		for c in n.get_children(): queue.append(c)
	return success({"mp_nodes":mp_nodes,"count":mp_nodes.size()})
