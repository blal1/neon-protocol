# ==============================================================================
# LocalizationManager.gd - Système de localisation multi-langue
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les traductions et le changement de langue
# Utilise les fichiers CSV de Godot + support JSON personnalisé
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal language_changed(locale: String)
signal translation_loaded(locale: String)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const TRANSLATIONS_PATH := "res://localization/"
const SUPPORTED_LOCALES := ["fr", "en", "es", "pt", "de"]
const DEFAULT_LOCALE := "fr"
const SETTINGS_KEY := "locale"

# ==============================================================================
# VARIABLES
# ==============================================================================
var current_locale: String = DEFAULT_LOCALE
var _translations: Dictionary = {}  # locale -> Dictionary<key, value>
var _fallback_translations: Dictionary = {}  # Traductions par défaut (fr)

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du système de localisation."""
	_load_default_translations()
	_load_saved_locale()


# ==============================================================================
# CHARGEMENT DES TRADUCTIONS
# ==============================================================================

func _load_default_translations() -> void:
	"""Charge les traductions par défaut intégrées."""
	# Traductions françaises (par défaut)
	_fallback_translations = {
		# === MENUS ===
		"menu.play": "JOUER",
		"menu.options": "OPTIONS",
		"menu.accessibility": "ACCESSIBILITÉ",
		"menu.quit": "QUITTER",
		"menu.resume": "REPRENDRE",
		"menu.pause": "PAUSE",
		"menu.save": "SAUVEGARDER",
		"menu.load": "CHARGER",
		"menu.back": "RETOUR",
		
		# === OPTIONS ===
		"options.audio": "Audio",
		"options.graphics": "Graphismes",
		"options.accessibility": "Accessibilité",
		"options.master_volume": "Volume principal",
		"options.music_volume": "Musique",
		"options.sfx_volume": "Effets sonores",
		"options.text_size": "Taille du texte",
		"options.text_size.normal": "Normal",
		"options.text_size.large": "Grand",
		"options.text_size.extra_large": "Très grand",
		"options.colorblind": "Mode daltonien",
		"options.colorblind.none": "Désactivé",
		"options.colorblind.deuteranopia": "Deutéranopie",
		"options.colorblind.protanopia": "Protanopie",
		"options.colorblind.tritanopia": "Tritanopie",
		"options.dyslexia": "Police dyslexie",
		"options.blind_mode": "Mode accessibilité aveugle",
		"options.game_speed": "Vitesse du jeu",
		
		# === GAMEPLAY ===
		"gameplay.health": "Santé",
		"gameplay.credits": "Crédits",
		"gameplay.mission": "Mission",
		"gameplay.objective": "Objectif",
		"gameplay.completed": "Terminé",
		"gameplay.failed": "Échoué",
		"gameplay.new_mission": "Nouvelle mission",
		
		# === COMBAT ===
		"combat.attack": "Attaque",
		"combat.dash": "Esquive",
		"combat.enemy_detected": "Ennemi détecté",
		"combat.enemy_eliminated": "Ennemi éliminé",
		
		# === TUTORIEL ===
		"tutorial.welcome": "Bienvenue dans Neon Protocol",
		"tutorial.movement": "Déplacement",
		"tutorial.camera": "Caméra",
		"tutorial.combat": "Combat",
		"tutorial.skip": "Passer le tutoriel",
		
		# === INVENTAIRE ===
		"inventory.title": "Inventaire",
		"inventory.empty": "Inventaire vide",
		"inventory.use": "Utiliser",
		"inventory.equip": "Équiper",
		"inventory.drop": "Jeter",
		
		# === BOUTIQUE ===
		"shop.buy": "Acheter",
		"shop.sell": "Vendre",
		"shop.not_enough_credits": "Crédits insuffisants",
		"shop.out_of_stock": "Rupture de stock",
		"shop.inventory_full": "Inventaire plein",
		
		# === ACHIEVEMENTS ===
		"achievements.title": "Succès",
		"achievements.unlocked": "Succès débloqué !",
		"achievements.progress": "Progression",
		
		# === ACCESSIBILITÉ ===
		"accessibility.blind.enemy_ahead": "Ennemi devant",
		"accessibility.blind.enemy_left": "Ennemi à gauche",
		"accessibility.blind.enemy_right": "Ennemi à droite",
		"accessibility.blind.enemy_behind": "Ennemi derrière",
		"accessibility.blind.objective_ahead": "Objectif devant",
		"accessibility.blind.damage_received": "Dégâts reçus",
	}
	
	# Copier comme traductions FR
	_translations["fr"] = _fallback_translations.duplicate()
	
	# Traductions anglaises
	_translations["en"] = {
		"menu.play": "PLAY",
		"menu.options": "OPTIONS",
		"menu.accessibility": "ACCESSIBILITY",
		"menu.quit": "QUIT",
		"menu.resume": "RESUME",
		"menu.pause": "PAUSE",
		"menu.save": "SAVE",
		"menu.load": "LOAD",
		"menu.back": "BACK",
		
		"options.audio": "Audio",
		"options.graphics": "Graphics",
		"options.accessibility": "Accessibility",
		"options.master_volume": "Master Volume",
		"options.music_volume": "Music",
		"options.sfx_volume": "Sound Effects",
		"options.text_size": "Text Size",
		"options.text_size.normal": "Normal",
		"options.text_size.large": "Large",
		"options.text_size.extra_large": "Extra Large",
		"options.colorblind": "Colorblind Mode",
		"options.colorblind.none": "Off",
		"options.colorblind.deuteranopia": "Deuteranopia",
		"options.colorblind.protanopia": "Protanopia",
		"options.colorblind.tritanopia": "Tritanopia",
		"options.dyslexia": "Dyslexia Font",
		"options.blind_mode": "Blind Accessibility Mode",
		"options.game_speed": "Game Speed",
		
		"gameplay.health": "Health",
		"gameplay.credits": "Credits",
		"gameplay.mission": "Mission",
		"gameplay.objective": "Objective",
		"gameplay.completed": "Completed",
		"gameplay.failed": "Failed",
		"gameplay.new_mission": "New Mission",
		
		"combat.attack": "Attack",
		"combat.dash": "Dash",
		"combat.enemy_detected": "Enemy detected",
		"combat.enemy_eliminated": "Enemy eliminated",
		
		"tutorial.welcome": "Welcome to Neon Protocol",
		"tutorial.movement": "Movement",
		"tutorial.camera": "Camera",
		"tutorial.combat": "Combat",
		"tutorial.skip": "Skip tutorial",
		
		"inventory.title": "Inventory",
		"inventory.empty": "Inventory empty",
		"inventory.use": "Use",
		"inventory.equip": "Equip",
		"inventory.drop": "Drop",
		
		"shop.buy": "Buy",
		"shop.sell": "Sell",
		"shop.not_enough_credits": "Not enough credits",
		"shop.out_of_stock": "Out of stock",
		"shop.inventory_full": "Inventory full",
		
		"achievements.title": "Achievements",
		"achievements.unlocked": "Achievement unlocked!",
		"achievements.progress": "Progress",
		
		"accessibility.blind.enemy_ahead": "Enemy ahead",
		"accessibility.blind.enemy_left": "Enemy on the left",
		"accessibility.blind.enemy_right": "Enemy on the right",
		"accessibility.blind.enemy_behind": "Enemy behind",
		"accessibility.blind.objective_ahead": "Objective ahead",
		"accessibility.blind.damage_received": "Damage received",
	}
	
	# Espagnol (partiel)
	_translations["es"] = {
		"menu.play": "JUGAR",
		"menu.options": "OPCIONES",
		"menu.quit": "SALIR",
		"gameplay.health": "Salud",
		"gameplay.credits": "Créditos",
	}
	
	# Portugais (partiel)
	_translations["pt"] = {
		"menu.play": "JOGAR",
		"menu.options": "OPÇÕES",
		"menu.quit": "SAIR",
		"gameplay.health": "Saúde",
		"gameplay.credits": "Créditos",
	}
	
	# Allemand (partiel)
	_translations["de"] = {
		"menu.play": "SPIELEN",
		"menu.options": "OPTIONEN",
		"menu.quit": "BEENDEN",
		"gameplay.health": "Gesundheit",
		"gameplay.credits": "Kredite",
	}


func _load_saved_locale() -> void:
	"""Charge la langue sauvegardée."""
	var am = get_node_or_null("/root/AccessibilityManager")
	if am and am.get("settings"):
		var saved_locale: String = am.settings.get(SETTINGS_KEY, "")
		if saved_locale in SUPPORTED_LOCALES:
			set_locale(saved_locale, false)
			return
	
	# Détecter automatiquement
	var system_locale := OS.get_locale_language()
	if system_locale in SUPPORTED_LOCALES:
		set_locale(system_locale, false)
	else:
		set_locale(DEFAULT_LOCALE, false)


# ==============================================================================
# CHANGEMENT DE LANGUE
# ==============================================================================

func set_locale(locale: String, save: bool = true) -> void:
	"""Change la langue."""
	if locale not in SUPPORTED_LOCALES:
		push_warning("LocalizationManager: Langue non supportée: " + locale)
		return
	
	current_locale = locale
	TranslationServer.set_locale(locale)
	
	language_changed.emit(locale)
	
	if save:
		_save_locale()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak(get_language_name(locale))


func _save_locale() -> void:
	"""Sauvegarde la préférence de langue."""
	var am = get_node_or_null("/root/AccessibilityManager")
	if am and am.has_method("save_settings"):
		if not am.get("settings"):
			am.settings = {}
		am.settings[SETTINGS_KEY] = current_locale
		am.save_settings()


# ==============================================================================
# TRADUCTION
# ==============================================================================

func tr_key(key: String) -> String:
	"""
	Traduit une clé.
	@param key: Clé de traduction (ex: "menu.play")
	@return: Texte traduit
	"""
	# D'abord essayer la langue actuelle
	if _translations.has(current_locale):
		if _translations[current_locale].has(key):
			return _translations[current_locale][key]
	
	# Fallback vers le français
	if _fallback_translations.has(key):
		return _fallback_translations[key]
	
	# Dernier recours : retourner la clé
	return key


func tr_format(key: String, args: Array) -> String:
	"""
	Traduit avec formatage.
	@param key: Clé de traduction
	@param args: Arguments pour String.format()
	@return: Texte traduit et formaté
	"""
	var text := tr_key(key)
	return text % args


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_current_locale() -> String:
	"""Retourne la langue actuelle."""
	return current_locale


func get_supported_locales() -> Array:
	"""Retourne les langues supportées."""
	return SUPPORTED_LOCALES


func get_language_name(locale: String) -> String:
	"""Retourne le nom d'une langue."""
	match locale:
		"fr": return "Français"
		"en": return "English"
		"es": return "Español"
		"pt": return "Português"
		"de": return "Deutsch"
	return locale


func get_all_language_names() -> Dictionary:
	"""Retourne tous les noms de langues."""
	var result := {}
	for locale in SUPPORTED_LOCALES:
		result[locale] = get_language_name(locale)
	return result


func is_rtl() -> bool:
	"""Retourne true si la langue est RTL (droite à gauche)."""
	# Pour le futur support de l'arabe, hébreu, etc.
	return current_locale in ["ar", "he"]
