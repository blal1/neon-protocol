# ==============================================================================
# DebugConsole.gd - Console de Debug In-Game
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Console pour tester les quêtes, spawn items, modifier états.
# Indispensable pour un jeu avec narration non-linéaire.
# ==============================================================================

extends CanvasLayer
class_name DebugConsole

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal command_executed(command: String, result: String)
signal console_opened()
signal console_closed()

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Visuals")
@export var console_height_ratio: float = 0.4
@export var background_color: Color = Color(0.05, 0.05, 0.1, 0.9)
@export var text_color: Color = Color(0.0, 1.0, 0.5)
@export var error_color: Color = Color(1.0, 0.3, 0.3)
@export var warning_color: Color = Color(1.0, 0.8, 0.2)

@export_group("Toggle")
@export var toggle_key: Key = KEY_QUOTELEFT  # ` (backtick)
@export var enabled_in_release: bool = false

# ==============================================================================
# VARIABLES
# ==============================================================================

var _is_open: bool = false
var _command_history: Array[String] = []
var _history_index: int = 0
var _commands: Dictionary = {}  # command_name -> Callable

## UI Elements
var _panel: Panel
var _output: RichTextLabel
var _input: LineEdit
var _scroll: ScrollContainer

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	if not OS.is_debug_build() and not enabled_in_release:
		queue_free()
		return
	
	_create_ui()
	_register_default_commands()
	_hide_console()


func _create_ui() -> void:
	"""Crée l'interface de la console."""
	var viewport_size := get_viewport().get_visible_rect().size
	var console_height := viewport_size.y * console_height_ratio
	
	# Panel principal
	_panel = Panel.new()
	_panel.name = "ConsolePanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.size = Vector2(viewport_size.x, console_height)
	
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_width_bottom = 2
	style.border_color = text_color
	_panel.add_theme_stylebox_override("panel", style)
	
	add_child(_panel)
	
	# VBox container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)
	
	# Scroll + Output
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)
	
	_output = RichTextLabel.new()
	_output.name = "Output"
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_color_override("default_color", text_color)
	_output.add_theme_font_size_override("normal_font_size", 14)
	_scroll.add_child(_output)
	
	# Input
	_input = LineEdit.new()
	_input.name = "Input"
	_input.placeholder_text = "Entrez une commande (help pour la liste)"
	_input.add_theme_color_override("font_color", text_color)
	_input.add_theme_color_override("caret_color", text_color)
	
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	input_style.border_width_all = 1
	input_style.border_color = text_color.darkened(0.5)
	_input.add_theme_stylebox_override("normal", input_style)
	
	_input.text_submitted.connect(_on_command_submitted)
	vbox.add_child(_input)
	
	# Message de bienvenue
	_print_line("[b]NEON PROTOCOL DEBUG CONSOLE[/b]")
	_print_line("Tapez 'help' pour la liste des commandes")
	_print_line("")


func _register_default_commands() -> void:
	"""Enregistre les commandes par défaut."""
	
	# Aide
	register_command("help", _cmd_help, "Affiche la liste des commandes")
	register_command("clear", _cmd_clear, "Efface la console")
	
	# Joueur
	register_command("god", _cmd_god_mode, "Active/désactive le mode invincible")
	register_command("heal", _cmd_heal, "Soigne le joueur à 100%")
	register_command("kill", _cmd_kill, "Tue le joueur")
	register_command("set_health", _cmd_set_health, "set_health <amount> - Définit la vie")
	register_command("add_credits", _cmd_add_credits, "add_credits <amount> - Ajoute des crédits")
	
	# Items
	register_command("spawn_item", _cmd_spawn_item, "spawn_item <item_id> [quantity] - Spawn un item")
	register_command("give_weapon", _cmd_give_weapon, "give_weapon <weapon_id> - Donne une arme")
	register_command("give_all", _cmd_give_all, "Donne tous les items de test")
	
	# Quêtes
	register_command("quest_list", _cmd_quest_list, "Liste les quêtes actives")
	register_command("quest_complete", _cmd_quest_complete, "quest_complete <quest_id> - Complete une quête")
	register_command("quest_fail", _cmd_quest_fail, "quest_fail <quest_id> - Échoue une quête")
	register_command("quest_start", _cmd_quest_start, "quest_start <quest_id> - Démarre une quête")
	
	# Réputation
	register_command("set_rep", _cmd_set_reputation, "set_rep <faction> <value> - Définit la réputation")
	register_command("show_rep", _cmd_show_reputation, "Affiche toutes les réputations")
	
	# Monde
	register_command("teleport", _cmd_teleport, "teleport <x> <y> <z> - Téléporte le joueur")
	register_command("goto", _cmd_goto_district, "goto <district> - Téléporte vers un district")
	register_command("time", _cmd_set_time, "time <0-24> - Définit l'heure")
	register_command("spawn_enemy", _cmd_spawn_enemy, "spawn_enemy <type> - Spawn un ennemi")
	
	# Systèmes
	register_command("slowmo", _cmd_slowmo, "slowmo <factor> - Active le ralenti (0.1-1.0)")
	register_command("instability", _cmd_instability, "instability <0-100> - Définit l'instabilité cyber")
	register_command("skip_tutorial", _cmd_skip_tutorial, "Skip le tutoriel")
	
	# Debug
	register_command("fps", _cmd_show_fps, "Affiche/masque le compteur FPS")
	register_command("reload", _cmd_reload_scene, "Recharge la scène actuelle")
	register_command("stats", _cmd_show_stats, "Affiche les statistiques système")


# ==============================================================================
# INPUT
# ==============================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			_toggle_console()
			get_viewport().set_input_as_handled()
		
		elif _is_open:
			if event.keycode == KEY_UP:
				_navigate_history(-1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN:
				_navigate_history(1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_ESCAPE:
				_hide_console()
				get_viewport().set_input_as_handled()


func _toggle_console() -> void:
	"""Bascule l'affichage de la console."""
	if _is_open:
		_hide_console()
	else:
		_show_console()


func _show_console() -> void:
	"""Affiche la console."""
	_panel.visible = true
	_is_open = true
	_input.grab_focus()
	get_tree().paused = true
	console_opened.emit()


func _hide_console() -> void:
	"""Masque la console."""
	_panel.visible = false
	_is_open = false
	get_tree().paused = false
	console_closed.emit()


func _navigate_history(direction: int) -> void:
	"""Navigue dans l'historique des commandes."""
	if _command_history.is_empty():
		return
	
	_history_index = clampi(_history_index + direction, 0, _command_history.size() - 1)
	_input.text = _command_history[_history_index]
	_input.caret_column = _input.text.length()


# ==============================================================================
# EXÉCUTION DE COMMANDES
# ==============================================================================

func _on_command_submitted(text: String) -> void:
	"""Exécute une commande."""
	text = text.strip_edges()
	if text.is_empty():
		return
	
	# Ajouter à l'historique
	_command_history.append(text)
	_history_index = _command_history.size()
	
	# Afficher la commande
	_print_line("> " + text)
	
	# Parser la commande
	var parts := text.split(" ", false)
	var command_name := parts[0].to_lower()
	var args := parts.slice(1)
	
	# Exécuter
	if _commands.has(command_name):
		var command: Dictionary = _commands[command_name]
		var result := command.callable.call(args)
		if result and result is String and not result.is_empty():
			_print_line(result)
	else:
		_print_error("Commande inconnue: " + command_name)
	
	# Vider l'input
	_input.clear()
	
	command_executed.emit(text, "")


func register_command(name: String, callable: Callable, description: String = "") -> void:
	"""Enregistre une nouvelle commande."""
	_commands[name.to_lower()] = {
		"callable": callable,
		"description": description
	}


# ==============================================================================
# OUTPUT
# ==============================================================================

func _print_line(text: String, color: Color = Color.WHITE) -> void:
	"""Affiche une ligne dans la console."""
	if color == Color.WHITE:
		_output.append_text(text + "\n")
	else:
		_output.push_color(color)
		_output.append_text(text + "\n")
		_output.pop()


func _print_error(text: String) -> void:
	"""Affiche une erreur."""
	_print_line("[ERROR] " + text, error_color)


func _print_warning(text: String) -> void:
	"""Affiche un avertissement."""
	_print_line("[WARN] " + text, warning_color)


func _print_success(text: String) -> void:
	"""Affiche un succès."""
	_print_line("[OK] " + text, Color.GREEN)


# ==============================================================================
# COMMANDES - AIDE
# ==============================================================================

func _cmd_help(_args: Array) -> String:
	_print_line("\n[b]COMMANDES DISPONIBLES:[/b]")
	
	var sorted_commands := _commands.keys()
	sorted_commands.sort()
	
	for cmd_name in sorted_commands:
		var desc: String = _commands[cmd_name].description
		_print_line("  [color=#00ff88]%s[/color] - %s" % [cmd_name, desc])
	
	return ""


func _cmd_clear(_args: Array) -> String:
	_output.clear()
	return ""


# ==============================================================================
# COMMANDES - JOUEUR
# ==============================================================================

func _cmd_god_mode(_args: Array) -> String:
	var player := _get_player()
	if not player:
		return "Joueur non trouvé"
	
	if player.has_method("toggle_god_mode"):
		player.toggle_god_mode()
		return "God mode toggled"
	
	# Fallback
	if player.has_meta("god_mode"):
		player.set_meta("god_mode", not player.get_meta("god_mode"))
	else:
		player.set_meta("god_mode", true)
	
	return "God mode: " + str(player.get_meta("god_mode", false))


func _cmd_heal(_args: Array) -> String:
	var player := _get_player()
	if not player:
		return "Joueur non trouvé"
	
	if player.has_method("heal"):
		player.heal(9999)
	elif player.has_method("set_health"):
		player.set_health(player.get("max_health", 100))
	
	return "Joueur soigné"


func _cmd_kill(_args: Array) -> String:
	var player := _get_player()
	if not player:
		return "Joueur non trouvé"
	
	if player.has_method("die"):
		player.die()
	elif player.has_method("take_damage"):
		player.take_damage(9999)
	
	return "Joueur tué"


func _cmd_set_health(args: Array) -> String:
	if args.is_empty():
		return "Usage: set_health <amount>"
	
	var amount := args[0].to_int()
	var player := _get_player()
	
	if player and player.has_method("set_health"):
		player.set_health(amount)
		return "Vie définie à %d" % amount
	
	return "Impossible de définir la vie"


func _cmd_add_credits(args: Array) -> String:
	if args.is_empty():
		return "Usage: add_credits <amount>"
	
	var amount := args[0].to_int()
	var player := _get_player()
	
	if player and player.has_method("add_credits"):
		player.add_credits(amount)
		return "+%d crédits" % amount
	elif InventoryManager:
		InventoryManager.add_credits(amount)
		return "+%d crédits" % amount
	
	return "Impossible d'ajouter des crédits"


# ==============================================================================
# COMMANDES - ITEMS
# ==============================================================================

func _cmd_spawn_item(args: Array) -> String:
	if args.is_empty():
		return "Usage: spawn_item <item_id> [quantity]"
	
	var item_id: String = args[0]
	var quantity := args[1].to_int() if args.size() > 1 else 1
	
	if InventoryManager and InventoryManager.has_method("add_item"):
		InventoryManager.add_item(item_id, quantity)
		return "Ajouté: %s x%d" % [item_id, quantity]
	
	return "InventoryManager non disponible"


func _cmd_give_weapon(args: Array) -> String:
	if args.is_empty():
		return "Usage: give_weapon <weapon_id>"
	
	var weapon_id: String = args[0]
	
	if InventoryManager and InventoryManager.has_method("add_weapon"):
		InventoryManager.add_weapon(weapon_id)
		return "Arme ajoutée: " + weapon_id
	
	return "Impossible d'ajouter l'arme"


func _cmd_give_all(_args: Array) -> String:
	# Items de test
	var test_items := ["medkit", "stim_pack", "emp_grenade", "hacking_chip", "credits_chip"]
	
	for item in test_items:
		if InventoryManager and InventoryManager.has_method("add_item"):
			InventoryManager.add_item(item, 5)
	
	return "Tous les items de test ajoutés"


# ==============================================================================
# COMMANDES - QUÊTES
# ==============================================================================

func _cmd_quest_list(_args: Array) -> String:
	if not MissionManager:
		return "MissionManager non disponible"
	
	if MissionManager.has_method("get_active_quests"):
		var quests: Array = MissionManager.get_active_quests()
		if quests.is_empty():
			return "Aucune quête active"
		
		_print_line("\n[b]QUÊTES ACTIVES:[/b]")
		for quest in quests:
			_print_line("  - " + str(quest))
	
	return ""


func _cmd_quest_complete(args: Array) -> String:
	if args.is_empty():
		return "Usage: quest_complete <quest_id>"
	
	var quest_id: String = args[0]
	
	if MissionManager and MissionManager.has_method("complete_quest"):
		MissionManager.complete_quest(quest_id)
		return "Quête complétée: " + quest_id
	
	return "Impossible de compléter la quête"


func _cmd_quest_fail(args: Array) -> String:
	if args.is_empty():
		return "Usage: quest_fail <quest_id>"
	
	var quest_id: String = args[0]
	
	if MissionManager and MissionManager.has_method("fail_quest"):
		MissionManager.fail_quest(quest_id)
		return "Quête échouée: " + quest_id
	
	return "Impossible d'échouer la quête"


func _cmd_quest_start(args: Array) -> String:
	if args.is_empty():
		return "Usage: quest_start <quest_id>"
	
	var quest_id: String = args[0]
	
	if MissionManager and MissionManager.has_method("start_quest"):
		MissionManager.start_quest(quest_id)
		return "Quête démarrée: " + quest_id
	
	return "Impossible de démarrer la quête"


# ==============================================================================
# COMMANDES - RÉPUTATION
# ==============================================================================

func _cmd_set_reputation(args: Array) -> String:
	if args.size() < 2:
		return "Usage: set_rep <faction> <value>"
	
	var faction: String = args[0]
	var value := args[1].to_int()
	
	if FactionManager and FactionManager.has_method("set_reputation"):
		FactionManager.set_reputation(faction, value)
		return "Réputation %s = %d" % [faction, value]
	
	return "FactionManager non disponible"


func _cmd_show_reputation(_args: Array) -> String:
	if FactionManager and FactionManager.has_method("get_all_reputations"):
		var reps: Dictionary = FactionManager.get_all_reputations()
		
		_print_line("\n[b]RÉPUTATIONS:[/b]")
		for faction in reps.keys():
			var value: int = reps[faction]
			var color := "green" if value > 0 else ("red" if value < 0 else "white")
			_print_line("  [color=%s]%s: %d[/color]" % [color, faction, value])
	
	return ""


# ==============================================================================
# COMMANDES - MONDE
# ==============================================================================

func _cmd_teleport(args: Array) -> String:
	if args.size() < 3:
		return "Usage: teleport <x> <y> <z>"
	
	var pos := Vector3(args[0].to_float(), args[1].to_float(), args[2].to_float())
	var player := _get_player()
	
	if player:
		player.global_position = pos
		return "Téléporté à (%s)" % str(pos)
	
	return "Joueur non trouvé"


func _cmd_goto_district(args: Array) -> String:
	if args.is_empty():
		return "Usage: goto <district>\nDistricts: corpo, sprawl, rust, dead_end, wastes, depths, neon"
	
	var district: String = args[0].to_lower()
	var positions := {
		"corpo": Vector3(0, 100, 0),
		"sprawl": Vector3(0, 50, 0),
		"rust": Vector3(200, 30, 0),
		"dead_end": Vector3(-200, 10, 0),
		"wastes": Vector3(0, 5, 200),
		"depths": Vector3(0, -20, 0),
		"neon": Vector3(100, 40, 100)
	}
	
	if positions.has(district):
		var player := _get_player()
		if player:
			player.global_position = positions[district]
			return "Téléporté vers " + district
	
	return "District inconnu: " + district


func _cmd_set_time(args: Array) -> String:
	if args.is_empty():
		return "Usage: time <0-24>"
	
	var hour := args[0].to_float()
	
	var day_night := get_tree().get_first_node_in_group("day_night_cycle")
	if day_night and day_night.has_method("set_time"):
		day_night.set_time(hour)
		return "Heure définie: %d:00" % int(hour)
	
	return "DayNightCycle non trouvé"


func _cmd_spawn_enemy(args: Array) -> String:
	if args.is_empty():
		return "Usage: spawn_enemy <type>\nTypes: robot, drone, turret, boss"
	
	# TODO: Implémenter le spawn
	return "Spawn ennemi: " + args[0]


# ==============================================================================
# COMMANDES - SYSTÈMES
# ==============================================================================

func _cmd_slowmo(args: Array) -> String:
	if args.is_empty():
		return "Usage: slowmo <factor> (0.1-1.0)"
	
	var factor := clampf(args[0].to_float(), 0.1, 1.0)
	Engine.time_scale = factor
	return "Time scale: " + str(factor)


func _cmd_instability(args: Array) -> String:
	if args.is_empty():
		return "Usage: instability <0-100>"
	
	var value := clampi(args[0].to_int(), 0, 100)
	
	# Chercher le système d'instabilité
	var instability_system := get_tree().get_first_node_in_group("instability_system")
	if instability_system and instability_system.has_method("set_instability"):
		instability_system.set_instability(value / 100.0)
		return "Instabilité: %d%%" % value
	
	return "Système d'instabilité non trouvé"


func _cmd_skip_tutorial(_args: Array) -> String:
	if TutorialManager and TutorialManager.has_method("skip_all"):
		TutorialManager.skip_all()
		return "Tutoriel skippé"
	
	return "TutorialManager non disponible"


# ==============================================================================
# COMMANDES - DEBUG
# ==============================================================================

func _cmd_show_fps(_args: Array) -> String:
	# Toggle FPS display
	var existing := get_tree().get_first_node_in_group("fps_counter")
	if existing:
		existing.visible = not existing.visible
		return "FPS: " + ("visible" if existing.visible else "masqué")
	
	return "Compteur FPS non configuré"


func _cmd_reload_scene(_args: Array) -> String:
	get_tree().reload_current_scene()
	return "Rechargement..."


func _cmd_show_stats(_args: Array) -> String:
	_print_line("\n[b]STATISTIQUES SYSTÈME:[/b]")
	_print_line("  FPS: %d" % Engine.get_frames_per_second())
	_print_line("  Objects: %d" % Performance.get_monitor(Performance.OBJECT_COUNT))
	_print_line("  Nodes: %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_print_line("  Memory: %.2f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	_print_line("  VRAM: %.2f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	return ""


# ==============================================================================
# HELPERS
# ==============================================================================

func _get_player() -> Node:
	"""Récupère le joueur."""
	return get_tree().get_first_node_in_group("player")


func is_console_open() -> bool:
	"""Vérifie si la console est ouverte."""
	return _is_open
