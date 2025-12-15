# ==============================================================================
# DebugConsole.gd - Console de debug in-game
# ==============================================================================
# Toggle avec F12 pendant le jeu
# Commandes: help, tp, spawn, give, god, heal, kill, reload, fps
# ==============================================================================

extends CanvasLayer

# ==============================================================================
# VARIABLES
# ==============================================================================
var _visible := false
var _command_history: Array[String] = []
var _history_index := -1

@onready var console_panel: PanelContainer = $ConsolePanel
@onready var output: RichTextLabel = $ConsolePanel/VBox/Output
@onready var input_line: LineEdit = $ConsolePanel/VBox/InputBar/Input

# ==============================================================================
# COMMANDES DISPONIBLES
# ==============================================================================
var _commands := {
	"help": "_cmd_help",
	"tp": "_cmd_teleport",
	"spawn": "_cmd_spawn",
	"give": "_cmd_give",
	"god": "_cmd_god",
	"heal": "_cmd_heal",
	"kill": "_cmd_kill",
	"reload": "_cmd_reload",
	"fps": "_cmd_fps",
	"clear": "_cmd_clear",
	"quit": "_cmd_quit",
	"pos": "_cmd_position",
	"skills": "_cmd_skills",
	"money": "_cmd_money"
}

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	layer = 99
	console_panel.visible = false
	
	_log("[color=cyan]═══════════════════════════════════════[/color]")
	_log("[color=cyan]   NEON PROTOCOL - DEBUG CONSOLE[/color]")
	_log("[color=cyan]═══════════════════════════════════════[/color]")
	_log("Tapez [color=yellow]help[/color] pour la liste des commandes.")
	_log("")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12:
			_toggle_console()
		elif event.keycode == KEY_ESCAPE and _visible:
			_hide_console()


func _toggle_console() -> void:
	_visible = not _visible
	console_panel.visible = _visible
	
	if _visible:
		input_line.grab_focus()
		get_tree().paused = true
	else:
		get_tree().paused = false


func _hide_console() -> void:
	_visible = false
	console_panel.visible = false
	get_tree().paused = false


# ==============================================================================
# INPUT HANDLING
# ==============================================================================

func _on_input_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	
	# Ajouter à l'historique
	_command_history.append(text)
	_history_index = _command_history.size()
	
	# Afficher la commande
	_log("[color=gray]> " + text + "[/color]")
	
	# Parser et exécuter
	var parts := text.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	
	var cmd := parts[0].to_lower()
	var args := parts.slice(1)
	
	if _commands.has(cmd):
		call(_commands[cmd], args)
	else:
		_log("[color=red]Commande inconnue: " + cmd + "[/color]")
	
	input_line.clear()


func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP:
			_history_up()
		elif event.keycode == KEY_DOWN:
			_history_down()


func _history_up() -> void:
	if _command_history.is_empty():
		return
	_history_index = max(0, _history_index - 1)
	input_line.text = _command_history[_history_index]
	input_line.caret_column = input_line.text.length()


func _history_down() -> void:
	if _command_history.is_empty():
		return
	_history_index = min(_command_history.size(), _history_index + 1)
	if _history_index >= _command_history.size():
		input_line.clear()
	else:
		input_line.text = _command_history[_history_index]
		input_line.caret_column = input_line.text.length()


# ==============================================================================
# COMMANDES
# ==============================================================================

func _cmd_help(_args: Array) -> void:
	_log("[color=yellow]═══ COMMANDES DISPONIBLES ═══[/color]")
	_log("  [color=cyan]help[/color] - Affiche cette aide")
	_log("  [color=cyan]tp x y z[/color] - Téléporte le joueur")
	_log("  [color=cyan]spawn enemy[/color] - Fait apparaître un ennemi")
	_log("  [color=cyan]give item[/color] - Donne un item")
	_log("  [color=cyan]god[/color] - Toggle mode invincible")
	_log("  [color=cyan]heal[/color] - Soigne le joueur à 100%")
	_log("  [color=cyan]kill[/color] - Tue le joueur")
	_log("  [color=cyan]money amount[/color] - Donne de l'argent")
	_log("  [color=cyan]skills points[/color] - Donne des points de talent")
	_log("  [color=cyan]pos[/color] - Affiche la position du joueur")
	_log("  [color=cyan]fps[/color] - Affiche le FPS actuel")
	_log("  [color=cyan]reload[/color] - Recharge la scène actuelle")
	_log("  [color=cyan]clear[/color] - Efface la console")
	_log("  [color=cyan]quit[/color] - Quitte le jeu")


func _cmd_teleport(args: Array) -> void:
	if args.size() < 3:
		_log("[color=orange]Usage: tp x y z[/color]")
		return
	
	var player := _get_player()
	if not player:
		_log("[color=red]Joueur non trouvé[/color]")
		return
	
	var pos := Vector3(
		float(args[0]),
		float(args[1]),
		float(args[2])
	)
	player.global_position = pos
	_log("[color=green]Téléporté à " + str(pos) + "[/color]")


func _cmd_spawn(args: Array) -> void:
	_log("[color=orange]Fonction spawn non implémentée[/color]")


func _cmd_give(args: Array) -> void:
	if args.is_empty():
		_log("[color=orange]Usage: give item_id [amount][/color]")
		return
	
	var inventory = get_node_or_null("/root/InventoryManager")
	if not inventory:
		_log("[color=red]InventoryManager non trouvé[/color]")
		return
	
	var item_id := args[0]
	var amount := int(args[1]) if args.size() > 1 else 1
	
	if inventory.has_method("add_item"):
		inventory.add_item(item_id, amount)
		_log("[color=green]Ajouté " + str(amount) + "x " + item_id + "[/color]")
	else:
		_log("[color=red]Méthode add_item non disponible[/color]")


func _cmd_god(_args: Array) -> void:
	var player := _get_player()
	if not player:
		_log("[color=red]Joueur non trouvé[/color]")
		return
	
	if "_is_invincible" in player:
		player._is_invincible = not player._is_invincible
		var status := "activé" if player._is_invincible else "désactivé"
		_log("[color=green]Mode Dieu " + status + "[/color]")
	else:
		_log("[color=orange]Mode Dieu non supporté[/color]")


func _cmd_heal(_args: Array) -> void:
	var player := _get_player()
	if not player:
		_log("[color=red]Joueur non trouvé[/color]")
		return
	
	var health = player.get_node_or_null("HealthComponent")
	if health and health.has_method("heal"):
		health.heal(999)
		_log("[color=green]Joueur soigné à 100%[/color]")
	else:
		_log("[color=orange]HealthComponent non trouvé[/color]")


func _cmd_kill(_args: Array) -> void:
	var player := _get_player()
	if not player:
		_log("[color=red]Joueur non trouvé[/color]")
		return
	
	var health = player.get_node_or_null("HealthComponent")
	if health and health.has_method("take_damage"):
		health.take_damage(999, null)
		_log("[color=red]Joueur tué[/color]")
	else:
		_log("[color=orange]HealthComponent non trouvé[/color]")


func _cmd_money(args: Array) -> void:
	var amount := 1000
	if args.size() > 0:
		amount = int(args[0])
	
	var inventory = get_node_or_null("/root/InventoryManager")
	if inventory and inventory.has_method("add_currency"):
		inventory.add_currency(amount)
		_log("[color=green]Ajouté " + str(amount) + " crédits[/color]")
	else:
		_log("[color=red]InventoryManager.add_currency non disponible[/color]")


func _cmd_skills(args: Array) -> void:
	var amount := 10
	if args.size() > 0:
		amount = int(args[0])
	
	var skill_tree = get_node_or_null("/root/SkillTreeManager")
	if skill_tree and skill_tree.has_method("add_skill_points"):
		skill_tree.add_skill_points(amount)
		_log("[color=green]Ajouté " + str(amount) + " points de talent[/color]")
	else:
		_log("[color=red]SkillTreeManager.add_skill_points non disponible[/color]")


func _cmd_position(_args: Array) -> void:
	var player := _get_player()
	if not player:
		_log("[color=red]Joueur non trouvé[/color]")
		return
	
	_log("Position: " + str(player.global_position))
	_log("Rotation: " + str(player.rotation_degrees))


func _cmd_fps(_args: Array) -> void:
	var fps := Engine.get_frames_per_second()
	_log("FPS: " + str(fps))


func _cmd_reload(_args: Array) -> void:
	_log("[color=yellow]Rechargement de la scène...[/color]")
	get_tree().paused = false
	get_tree().reload_current_scene()


func _cmd_clear(_args: Array) -> void:
	output.clear()


func _cmd_quit(_args: Array) -> void:
	_log("[color=yellow]Au revoir![/color]")
	get_tree().quit()


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _get_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null


func _log(text: String) -> void:
	output.append_text(text + "\n")
