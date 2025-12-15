# ==============================================================================
# DebugOverlay.gd - Overlay de debug pour afficher infos en temps réel
# ==============================================================================
# Toggle avec F3 pendant le jeu
# ==============================================================================

extends CanvasLayer

# ==============================================================================
# VARIABLES
# ==============================================================================
var _visible := false
var _fps_history: Array[float] = []
const FPS_HISTORY_SIZE := 60

@onready var overlay: PanelContainer = $Overlay
@onready var info_label: RichTextLabel = $Overlay/VBox/Info

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	layer = 100  # Au-dessus de tout
	overlay.visible = false
	
	# Créer l'UI si pas déjà fait
	if not overlay:
		_create_ui()


func _create_ui() -> void:
	"""Crée l'UI du debug overlay."""
	overlay = PanelContainer.new()
	overlay.name = "Overlay"
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_color = Color(0, 0.8, 0.8, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	overlay.add_theme_stylebox_override("panel", style)
	
	overlay.position = Vector2(10, 10)
	overlay.size = Vector2(300, 200)
	
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	overlay.add_child(vbox)
	
	var title := Label.new()
	title.text = "🔧 DEBUG OVERLAY (F3)"
	title.add_theme_color_override("font_color", Color(0, 1, 1))
	vbox.add_child(title)
	
	info_label = RichTextLabel.new()
	info_label.name = "Info"
	info_label.bbcode_enabled = true
	info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(info_label)
	
	add_child(overlay)
	overlay.visible = false


# ==============================================================================
# MISE À JOUR
# ==============================================================================

func _process(delta: float) -> void:
	# Toggle avec F3
	if Input.is_action_just_pressed("ui_page_up") or Input.is_key_pressed(KEY_F3):
		_visible = not _visible
		overlay.visible = _visible
	
	if not _visible:
		return
	
	_update_fps(delta)
	_update_info()


func _update_fps(delta: float) -> void:
	"""Met à jour l'historique FPS."""
	var fps := 1.0 / delta if delta > 0 else 0.0
	_fps_history.append(fps)
	if _fps_history.size() > FPS_HISTORY_SIZE:
		_fps_history.pop_front()


func _get_avg_fps() -> float:
	"""Calcule le FPS moyen."""
	if _fps_history.is_empty():
		return 0.0
	var sum := 0.0
	for fps in _fps_history:
		sum += fps
	return sum / _fps_history.size()


func _update_info() -> void:
	"""Met à jour les informations affichées."""
	var text := ""
	
	# FPS
	var avg_fps := _get_avg_fps()
	var fps_color := "green" if avg_fps >= 55 else ("yellow" if avg_fps >= 30 else "red")
	text += "[color=" + fps_color + "]FPS: " + str(int(avg_fps)) + "[/color]\n"
	
	# Mémoire
	var mem := OS.get_static_memory_usage() / 1048576.0  # MB
	text += "Mémoire: " + str(int(mem)) + " MB\n"
	
	# Joueur
	var player := _get_player()
	if player:
		text += "\n[color=cyan]─── JOUEUR ───[/color]\n"
		text += "Position: " + _vec3_str(player.global_position) + "\n"
		text += "Vitesse: " + str(int(player.velocity.length())) + " m/s\n"
		
		if player.has_method("is_alive"):
			text += "En vie: " + str(player.is_alive()) + "\n"
		
		if player.has_method("get_health_percentage"):
			var hp := player.get_health_percentage() * 100
			text += "Santé: " + str(int(hp)) + "%\n"
	else:
		text += "\n[color=gray]Joueur non trouvé[/color]\n"
	
	# Autoloads
	text += "\n[color=cyan]─── AUTOLOADS ───[/color]\n"
	var autoloads := [
		["TTSManager", "/root/TTSManager"],
		["MusicManager", "/root/MusicManager"],
		["SaveManager", "/root/SaveManager"],
		["SkillTree", "/root/SkillTreeManager"]
	]
	
	for al in autoloads:
		var node = get_node_or_null(al[1])
		var status := "[color=green]✓[/color]" if node else "[color=red]✗[/color]"
		text += status + " " + al[0] + "\n"
	
	# Scène actuelle
	text += "\n[color=cyan]─── SCÈNE ───[/color]\n"
	var scene := get_tree().current_scene
	if scene:
		text += "Nom: " + scene.name + "\n"
		text += "Nodes: " + str(scene.get_child_count()) + "\n"
	
	info_label.text = text


func _get_player() -> Node:
	"""Récupère le joueur."""
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null


func _vec3_str(v: Vector3) -> String:
	"""Formate un Vector3."""
	return "(" + str(int(v.x)) + ", " + str(int(v.y)) + ", " + str(int(v.z)) + ")"


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func show_overlay() -> void:
	_visible = true
	overlay.visible = true


func hide_overlay() -> void:
	_visible = false
	overlay.visible = false


func toggle_overlay() -> void:
	_visible = not _visible
	overlay.visible = _visible
