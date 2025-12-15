# ==============================================================================
# ToastNotification.gd - Système de notifications toast
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Affiche des notifications temporaires pour achievements, events, etc.
# ==============================================================================

extends CanvasLayer

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal notification_shown(message: String)
signal notification_hidden

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum NotificationType {
	INFO,
	SUCCESS,
	WARNING,
	ERROR,
	ACHIEVEMENT,
	LEVEL_UP,
	ITEM
}

# ==============================================================================
# CONSTANTES
# ==============================================================================
const MAX_VISIBLE := 5
const DEFAULT_DURATION := 3.0
const SLIDE_DURATION := 0.3

# ==============================================================================
# VARIABLES
# ==============================================================================
var _notifications_container: VBoxContainer
var _notification_queue: Array[Dictionary] = []
var _active_notifications: Array[Control] = []

# Couleurs par type
var _colors: Dictionary = {
	NotificationType.INFO: Color(0.3, 0.6, 0.8),
	NotificationType.SUCCESS: Color(0.3, 0.8, 0.4),
	NotificationType.WARNING: Color(0.9, 0.7, 0.2),
	NotificationType.ERROR: Color(0.9, 0.3, 0.3),
	NotificationType.ACHIEVEMENT: Color(1.0, 0.8, 0.0),
	NotificationType.LEVEL_UP: Color(0.8, 0.5, 1.0),
	NotificationType.ITEM: Color(0.4, 0.8, 0.9)
}

# Icônes par type
var _icons: Dictionary = {
	NotificationType.INFO: "ℹ️",
	NotificationType.SUCCESS: "✓",
	NotificationType.WARNING: "⚠️",
	NotificationType.ERROR: "✕",
	NotificationType.ACHIEVEMENT: "🏆",
	NotificationType.LEVEL_UP: "⬆️",
	NotificationType.ITEM: "📦"
}

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	_create_container()


func _create_container() -> void:
	"""Crée le conteneur des notifications."""
	_notifications_container = VBoxContainer.new()
	_notifications_container.anchors_preset = Control.PRESET_TOP_RIGHT
	_notifications_container.anchor_left = 1.0
	_notifications_container.anchor_right = 1.0
	_notifications_container.offset_left = -320
	_notifications_container.offset_right = -20
	_notifications_container.offset_top = 80
	_notifications_container.add_theme_constant_override("separation", 10)
	add_child(_notifications_container)


# ==============================================================================
# AFFICHAGE DES NOTIFICATIONS
# ==============================================================================

func show_notification(message: String, type: NotificationType = NotificationType.INFO, duration: float = DEFAULT_DURATION) -> void:
	"""
	Affiche une notification.
	@param message: Le message à afficher
	@param type: Type de notification
	@param duration: Durée d'affichage en secondes
	"""
	var notification := _create_notification(message, type)
	
	# Ajouter au conteneur
	_notifications_container.add_child(notification)
	_active_notifications.append(notification)
	
	# Animation d'entrée (slide depuis la droite)
	notification.modulate.a = 0.0
	notification.position.x = 50
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 1.0, SLIDE_DURATION)
	tween.tween_property(notification, "position:x", 0.0, SLIDE_DURATION).set_ease(Tween.EASE_OUT)
	
	notification_shown.emit(message)
	
	# TTS (si activé)
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak(message)
	
	# Supprimer après le délai
	await get_tree().create_timer(duration).timeout
	_hide_notification(notification)


func show_achievement(title: String, description: String = "") -> void:
	"""Affiche une notification d'achievement."""
	var full_message := "🏆 " + title
	if description:
		full_message += "\n" + description
	show_notification(full_message, NotificationType.ACHIEVEMENT, 5.0)


func show_level_up(new_level: int) -> void:
	"""Affiche une notification de level up."""
	show_notification("⬆️ Niveau %d atteint!" % new_level, NotificationType.LEVEL_UP, 4.0)


func show_item_acquired(item_name: String, quantity: int = 1) -> void:
	"""Affiche une notification d'item obtenu."""
	var message := item_name
	if quantity > 1:
		message += " x%d" % quantity
	show_notification("📦 " + message, NotificationType.ITEM, 3.0)


func show_error(message: String) -> void:
	"""Affiche une notification d'erreur."""
	show_notification(message, NotificationType.ERROR, 4.0)


func show_success(message: String) -> void:
	"""Affiche une notification de succès."""
	show_notification(message, NotificationType.SUCCESS, 3.0)


# ==============================================================================
# CRÉATION DE NOTIFICATION
# ==============================================================================

func _create_notification(message: String, type: NotificationType) -> Control:
	"""Crée un widget de notification."""
	var panel := PanelContainer.new()
	
	# Style du panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.95)
	style.border_color = _colors[type]
	style.set_border_width_all(2)
	style.border_width_left = 4
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	
	# Contenu
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(hbox)
	panel.add_child(margin)
	
	# Icône
	var icon := Label.new()
	icon.text = _icons[type]
	icon.add_theme_font_size_override("font_size", 20)
	hbox.add_child(icon)
	
	# Message
	var label := Label.new()
	label.text = message
	label.add_theme_color_override("font_color", Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size.x = 220
	hbox.add_child(label)
	
	return panel


func _hide_notification(notification: Control) -> void:
	"""Cache et supprime une notification."""
	if not is_instance_valid(notification):
		return
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 0.0, SLIDE_DURATION)
	tween.tween_property(notification, "position:x", 50.0, SLIDE_DURATION)
	
	await tween.finished
	
	if _active_notifications.has(notification):
		_active_notifications.erase(notification)
	
	notification.queue_free()
	notification_hidden.emit()


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func clear_all() -> void:
	"""Supprime toutes les notifications."""
	for notification in _active_notifications:
		if is_instance_valid(notification):
			notification.queue_free()
	_active_notifications.clear()
