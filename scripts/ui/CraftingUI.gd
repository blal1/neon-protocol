# ==============================================================================
# CraftingUI.gd - Interface de crafting
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Affiche les recettes disponibles et permet de crafter des items
# ==============================================================================

extends CanvasLayer

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal closed

# ==============================================================================
# CONSTANTES
# ==============================================================================
const CATEGORY_ICONS := {
	"consumables": "💊",
	"ammo": "🔫",
	"upgrades": "⚡",
	"hacking": "💻",
	"equipment": "🛡️",
	"special": "⭐"
}

# ==============================================================================
# VARIABLES
# ==============================================================================
var _panel: PanelContainer
var _category_container: HBoxContainer
var _recipe_list: VBoxContainer
var _detail_panel: VBoxContainer
var _selected_recipe_id: String = ""
var _current_category: String = "consumables"

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Crée l'interface de crafting."""
	process_mode = PROCESS_MODE_ALWAYS
	layer = 100
	
	_create_ui()
	_connect_signals()
	_refresh_recipes()
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Menu de crafting ouvert")


func _input(event: InputEvent) -> void:
	"""Gestion des inputs."""
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()


# ==============================================================================
# CRÉATION UI
# ==============================================================================

func _create_ui() -> void:
	"""Construit l'interface dynamiquement."""
	# Background sombre
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Panel principal
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(800, 500)
	_panel.position = Vector2(-400, -250)
	add_child(_panel)
	
	# Style cyberpunk
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	style.border_color = Color(0, 1, 1, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	_panel.add_child(main_vbox)
	
	# Titre
	var title := Label.new()
	title.text = "🔧 ATELIER DE CRAFTING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0, 1, 1))
	main_vbox.add_child(title)
	
	# Catégories
	_category_container = HBoxContainer.new()
	_category_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_category_container.add_theme_constant_override("separation", 10)
	main_vbox.add_child(_category_container)
	
	_create_category_buttons()
	
	# Contenu principal (liste + détails)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content)
	
	# Liste des recettes
	var recipe_scroll := ScrollContainer.new()
	recipe_scroll.custom_minimum_size = Vector2(350, 350)
	content.add_child(recipe_scroll)
	
	_recipe_list = VBoxContainer.new()
	_recipe_list.add_theme_constant_override("separation", 8)
	recipe_scroll.add_child(_recipe_list)
	
	# Panel de détails
	_detail_panel = VBoxContainer.new()
	_detail_panel.custom_minimum_size = Vector2(380, 350)
	_detail_panel.add_theme_constant_override("separation", 10)
	content.add_child(_detail_panel)
	
	# Bouton fermer
	var close_btn := Button.new()
	close_btn.text = "FERMER [ESC]"
	close_btn.pressed.connect(close)
	_style_button(close_btn, Color(0.8, 0.2, 0.2))
	main_vbox.add_child(close_btn)


func _create_category_buttons() -> void:
	"""Crée les boutons de catégorie."""
	for cat_id in CATEGORY_ICONS:
		var btn := Button.new()
		btn.text = CATEGORY_ICONS[cat_id] + " " + cat_id.capitalize()
		btn.pressed.connect(_on_category_selected.bind(cat_id))
		_style_button(btn, Color(0.1, 0.3, 0.4) if cat_id != _current_category else Color(0, 0.6, 0.6))
		btn.name = cat_id
		_category_container.add_child(btn)


func _style_button(btn: Button, color: Color) -> void:
	"""Applique le style cyberpunk à un bouton."""
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0, 1, 1, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover)
	
	var pressed := style.duplicate()
	pressed.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed)


# ==============================================================================
# RECETTES
# ==============================================================================

func _refresh_recipes() -> void:
	"""Rafraîchit la liste des recettes."""
	# Effacer l'ancienne liste
	for child in _recipe_list.get_children():
		child.queue_free()
	
	var crafting = get_node_or_null("/root/CraftingSystem")
	if not crafting:
		return
	
	var recipes: Array = crafting.get_recipes_by_category(_current_category)
	
	if recipes.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Aucune recette dans cette catégorie"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_recipe_list.add_child(empty_label)
		return
	
	for recipe in recipes:
		_add_recipe_button(recipe)
	
	# Mettre à jour les boutons de catégorie
	for child in _category_container.get_children():
		if child is Button:
			var is_selected := child.name == _current_category
			_style_button(child, Color(0, 0.6, 0.6) if is_selected else Color(0.1, 0.3, 0.4))


func _add_recipe_button(recipe) -> void:
	"""Ajoute un bouton de recette."""
	var crafting = get_node_or_null("/root/CraftingSystem")
	if not crafting:
		return
	
	var item_info: Dictionary = crafting.get_item_info(recipe.result_item)
	var item_name: String = item_info.get("name", recipe.result_item)
	var can_craft: bool = crafting.can_craft(recipe.id)
	
	var btn := Button.new()
	btn.text = "%s x%d" % [item_name, recipe.result_quantity]
	btn.text += " ✓" if can_craft else " ✗"
	btn.pressed.connect(_on_recipe_selected.bind(recipe.id))
	
	var color := Color(0.1, 0.4, 0.3) if can_craft else Color(0.3, 0.2, 0.2)
	_style_button(btn, color)
	btn.custom_minimum_size = Vector2(320, 40)
	
	_recipe_list.add_child(btn)


func _show_recipe_details(recipe_id: String) -> void:
	"""Affiche les détails d'une recette."""
	# Effacer les anciens détails
	for child in _detail_panel.get_children():
		child.queue_free()
	
	var crafting = get_node_or_null("/root/CraftingSystem")
	if not crafting:
		return
	
	var recipe = crafting.get_recipe(recipe_id)
	if not recipe:
		return
	
	var item_info: Dictionary = crafting.get_item_info(recipe.result_item)
	var item_name: String = item_info.get("name", recipe.result_item)
	
	# Titre
	var title := Label.new()
	title.text = "📦 " + item_name
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0))
	_detail_panel.add_child(title)
	
	# Quantité
	var qty := Label.new()
	qty.text = "Quantité: x%d" % recipe.result_quantity
	_detail_panel.add_child(qty)
	
	# Ingrédients
	var ing_title := Label.new()
	ing_title.text = "\n⚙️ INGRÉDIENTS:"
	ing_title.add_theme_color_override("font_color", Color(0, 1, 1))
	_detail_panel.add_child(ing_title)
	
	var inventory = get_node_or_null("/root/InventoryManager")
	
	for item_id in recipe.ingredients:
		var required: int = recipe.ingredients[item_id]
		var available: int = 0
		if inventory and inventory.has_method("get_item_count"):
			available = inventory.get_item_count(item_id)
		
		var ing_info: Dictionary = crafting.get_item_info(item_id)
		var ing_name: String = ing_info.get("name", item_id)
		
		var ing_label := Label.new()
		ing_label.text = "  • %s: %d/%d" % [ing_name, available, required]
		ing_label.add_theme_color_override("font_color", Color(0, 1, 0) if available >= required else Color(1, 0.3, 0.3))
		_detail_panel.add_child(ing_label)
	
	# Station requise
	if not recipe.required_station.is_empty():
		var station_label := Label.new()
		var near_station := crafting.is_near_station(recipe.required_station)
		station_label.text = "\n🏭 Station: %s %s" % [recipe.required_station, "✓" if near_station else "✗"]
		station_label.add_theme_color_override("font_color", Color(0, 1, 0) if near_station else Color(1, 0.5, 0))
		_detail_panel.add_child(station_label)
	
	# Skill requis
	if not recipe.required_skill.is_empty():
		var skill_label := Label.new()
		skill_label.text = "📊 Skill requis: %s Lvl %d" % [recipe.required_skill, recipe.required_skill_level]
		_detail_panel.add_child(skill_label)
	
	# Bouton crafter
	var craft_btn := Button.new()
	craft_btn.text = "🔨 CRAFTER"
	craft_btn.custom_minimum_size = Vector2(200, 50)
	craft_btn.pressed.connect(_on_craft_pressed.bind(recipe_id))
	
	var can_craft: bool = crafting.can_craft(recipe_id)
	if not recipe.required_station.is_empty():
		can_craft = can_craft and crafting.is_near_station(recipe.required_station)
	
	_style_button(craft_btn, Color(0, 0.6, 0.3) if can_craft else Color(0.4, 0.4, 0.4))
	craft_btn.disabled = not can_craft
	
	_detail_panel.add_child(craft_btn)


# ==============================================================================
# CALLBACKS
# ==============================================================================

func _on_category_selected(category: String) -> void:
	"""Callback sélection catégorie."""
	_current_category = category
	_refresh_recipes()
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Catégorie: " + category)


func _on_recipe_selected(recipe_id: String) -> void:
	"""Callback sélection recette."""
	_selected_recipe_id = recipe_id
	_show_recipe_details(recipe_id)
	
	var crafting = get_node_or_null("/root/CraftingSystem")
	if crafting:
		var recipe = crafting.get_recipe(recipe_id)
		if recipe:
			var item_info: Dictionary = crafting.get_item_info(recipe.result_item)
			var tts = get_node_or_null("/root/TTSManager")
			if tts:
				tts.speak(item_info.get("name", recipe_id))


func _on_craft_pressed(recipe_id: String) -> void:
	"""Callback bouton crafter."""
	var crafting = get_node_or_null("/root/CraftingSystem")
	if crafting:
		crafting.craft(recipe_id)
		
		# Rafraîchir après un délai (temps de craft)
		var recipe = crafting.get_recipe(recipe_id)
		if recipe:
			await get_tree().create_timer(recipe.craft_time + 0.1).timeout
		
		_refresh_recipes()
		_show_recipe_details(recipe_id)


func _connect_signals() -> void:
	"""Connecte les signaux du CraftingSystem."""
	var crafting = get_node_or_null("/root/CraftingSystem")
	if crafting:
		if not crafting.item_crafted.is_connected(_on_item_crafted):
			crafting.item_crafted.connect(_on_item_crafted)
		if not crafting.crafting_failed.is_connected(_on_crafting_failed):
			crafting.crafting_failed.connect(_on_crafting_failed)


func _on_item_crafted(_item_id: String, _quantity: int) -> void:
	"""Callback craft réussi."""
	_refresh_recipes()
	if not _selected_recipe_id.is_empty():
		_show_recipe_details(_selected_recipe_id)


func _on_crafting_failed(reason: String) -> void:
	"""Callback craft échoué."""
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show_error("❌ " + reason)


# ==============================================================================
# PUBLIQUES
# ==============================================================================

func close() -> void:
	"""Ferme le menu de crafting."""
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Menu fermé")
	
	closed.emit()
	queue_free()


func open_to_category(category: String) -> void:
	"""Ouvre directement sur une catégorie."""
	_current_category = category
	_refresh_recipes()
