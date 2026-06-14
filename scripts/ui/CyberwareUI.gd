# ==============================================================================
# CyberwareUI.gd - Interface d'installation d'implants
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================

extends Control

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal closed

# ==============================================================================
# RÉFÉRENCES UI
# ==============================================================================
@export var implant_list: ItemList
@export var details_label: RichTextLabel
@export var install_button: Button
@export var credits_label: Label
@export var humanity_label: Label

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _available_implants: Array[Dictionary] = []
var _selected_implant_id: String = ""

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	_refresh_ui()
	
	# Connecter les signaux
	if implant_list:
		implant_list.item_selected.connect(_on_implant_selected)
	
	if install_button:
		install_button.pressed.connect(_on_install_pressed)
		
	# Connecter aux changements de crédits
	if InventoryManager:
		InventoryManager.credits_changed.connect(_on_credits_changed)


func open() -> void:
	"""Ouvre le menu."""
	show()
	_refresh_ui()
	_speak("Bienvenue chez le Ripperdoc. Choisissez votre amélioration.")


func close() -> void:
	"""Ferme le menu."""
	hide()
	closed.emit()


# ==============================================================================
# LOGIQUE UI
# ==============================================================================

func _refresh_ui() -> void:
	"""Met à jour toute l'interface."""
	_update_implant_list()
	_update_stats()
	_clear_details()


func _update_implant_list() -> void:
	"""Remplit la liste des implants."""
	if not implant_list or not CyberwareManager:
		return
		
	implant_list.clear()
	_available_implants = CyberwareManager.get_available_implants()
	
	var installed = CyberwareManager.get_installed_implants()
	var installed_ids = []
	for slot in installed:
		installed_ids.append(installed[slot].id)
	
	for implant in _available_implants:
		var index = implant_list.add_item(implant.name)
		var price = implant.visible_cost.credits
		
		# Marquer si déjà installé
		if implant.id in installed_ids:
			implant_list.set_item_text(index, implant.name + " [INSTALLÉ]")
			implant_list.set_item_disabled(index, true)
		elif price > InventoryManager.get_credits():
			implant_list.set_item_text(index, implant.name + " (" + str(price) + " ¥)")
			# On laisse activé pour voir les détails
	
	_available_implants = _available_implants # Store for index access


func _update_stats() -> void:
	"""Met à jour les labels de crédits et humanité."""
	if credits_label and InventoryManager:
		credits_label.text = "CRÉDITS: " + str(InventoryManager.get_credits()) + " ¥"
		
	if humanity_label and CyberwareManager:
		var status = CyberwareManager.get_humanity_status()
		humanity_label.text = "HUMANITÉ: %.0f%% (%s)" % [status.average, status.description]


func _on_implant_selected(index: int) -> void:
	"""Appelé quand un implant est cliqué."""
	var implant = _available_implants[index]
	_selected_implant_id = implant.id
	
	_show_details(implant)


func _show_details(implant: Dictionary) -> void:
	"""Affiche les détails d'un implant."""
	if not details_label:
		return
		
	var text = "[b][color=cyan]" + implant.name + "[/color][/b]\n\n"
	text += "[color=yellow]Bénéfices:[/color]\n"
	for b in implant.benefits:
		text += "- " + str(b).replace("_", " ").capitalize() + ": " + str(implant.benefits[b]) + "\n"
		
	text += "\n[color=orange]Coût de l'opération:[/color] " + str(implant.visible_cost.credits) + " ¥\n"
	text += "[color=red]Risque opératoire:[/color] " + str(int(implant.surgery_risk * 100)) + "%\n"
	
	details_label.text = text
	
	# Activer le bouton si abordable et non installé
	var installed = CyberwareManager.get_installed_implants()
	var installed_ids = []
	for slot in installed:
		installed_ids.append(installed[slot].id)
		
	var price = implant.visible_cost.credits
	var can_afford = price <= InventoryManager.get_credits()
	var is_installed = implant.id in installed_ids
	
	install_button.disabled = is_installed or not can_afford
	
	_speak(implant.name + ". Coût: " + str(price) + " crédits.")


func _clear_details() -> void:
	if details_label:
		details_label.text = "Sélectionnez un implant pour voir les détails."
	if install_button:
		install_button.disabled = true
	_selected_implant_id = ""


# ==============================================================================
# ACTIONS
# ==============================================================================

func _on_install_pressed() -> void:
	"""Tente d'installer l'implant sélectionné."""
	if _selected_implant_id == "":
		return
		
	var implant = CyberwareManager.IMPLANT_DATABASE[_selected_implant_id]
	var price = implant.visible_cost.credits
	
	# Retirer les crédits
	if InventoryManager.remove_credits(price):
		# Installer
		var result = CyberwareManager.install_implant(_selected_implant_id, CyberwareManager.SurgeryType.CLINIC)
		
		if result.success:
			_show_success(implant.name)
		else:
			_show_failure(result.reason, result.get("damage", 0))
			
		_refresh_ui()
	else:
		_speak("Crédits insuffisants.")


func _show_success(implant_name: String) -> void:
	var msg = "Installation réussie: " + implant_name
	_speak(msg)
	
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show_notification(msg, 0, 3.0) # SUCCESS type if defined, else 0


func _show_failure(reason: String, damage: int) -> void:
	var msg = "ÉCHEC DE L'OPÉRATION: " + reason
	if damage > 0:
		msg += " (-" + str(damage) + " HP)"
		
	_speak(msg)
	
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show_error(msg)
		
	# Appliquer les dégâts au joueur
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var health = players[0].get_node_or_null("HealthComponent")
		if health and health.has_method("take_damage"):
			health.take_damage(damage)


func _on_credits_changed(_amount: int) -> void:
	_update_stats()


func _speak(text: String) -> void:
	if TTSManager:
		TTSManager.speak(text)


func _on_back_pressed() -> void:
	close()
