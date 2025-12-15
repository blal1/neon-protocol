# ==============================================================================
# DistrictEcosystem.gd - Quartiers comme Écosystèmes Vivants
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Chaque zone a: économie, idéologie, style de violence.
# Les districts sont des micro-mondes interconnectés.
# ==============================================================================

extends Node
class_name DistrictEcosystem

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal district_entered(district_id: String)
signal district_exited(district_id: String)
signal district_economy_changed(district_id: String, economy: Dictionary)
signal district_tension_changed(district_id: String, tension: float)
signal district_event_triggered(district_id: String, event: Dictionary)
signal faction_control_changed(district_id: String, new_controller: String)

# ==============================================================================
# ENUMS
# ==============================================================================

enum DistrictType {
	CORPORATE,    ## Quartier corpo - propre, surveillé
	RESIDENTIAL,  ## Zone résidentielle - classe moyenne
	INDUSTRIAL,   ## Zone industrielle - usines, pollution
	SLUMS,        ## Bidonville - pauvre, dangereux
	NOMAD,        ## Zone nomade/wasteland - liberté fragile
	UNDERGROUND,  ## Sous-ville - chop shops, hackers
	ENTERTAINMENT ## Zone de divertissement - clubs, casinos
}

enum ViolenceStyle {
	CLINICAL,      ## Violence propre, précise (corpo)
	BRUTAL,        ## Violence brute, directe (gangs)
	GUERRILLA,     ## Embuscades, pièges (nomades)
	RITUALISTIC,   ## Violences rituelles (cultes)
	ECONOMIC       ## Violence économique (extorsion)
}

enum EconomyType {
	CORPORATE,     ## Économie légale corpo
	BLACK_MARKET,  ## Marché noir
	BARTER,        ## Troc
	MIXED,         ## Économie mixte
	SUBSISTENCE    ## Survie pure
}

# ==============================================================================
# BASE DE DONNÉES DES DISTRICTS
# ==============================================================================

const DISTRICTS: Dictionary = {
	"corpo_heights": {
		"name": "Corpo Heights",
		"type": DistrictType.CORPORATE,
		"description": "Tours de verre et néon. Propreté artificielle. Bonheur surveillé.",
		"economy": EconomyType.CORPORATE,
		"ideology": "Productivité = Valeur. Consommez. Obéissez.",
		"violence_style": ViolenceStyle.CLINICAL,
		"controlling_faction": "novatech",
		"base_prices": 1.5,  # 50% plus cher
		"security_level": 0.9,
		"surveillance_level": 1.0,
		"atmosphere": {
			"cleanliness": 1.0,
			"drone_density": 0.8,
			"ad_density": 1.0,
			"citizen_mood": "artificially_happy"
		},
		"available_services": ["corpo_clinic", "premium_shops", "banks", "security_checkpoint"],
		"restricted_items": ["weapons_visible", "unregistered_implants", "banned_media"]
	},
	
	"the_sprawl": {
		"name": "The Sprawl",
		"type": DistrictType.RESIDENTIAL,
		"description": "Classe moyenne en déclin. Entre les tours et les ruines.",
		"economy": EconomyType.MIXED,
		"ideology": "Survivre. Travailler. Espérer.",
		"violence_style": ViolenceStyle.BRUTAL,
		"controlling_faction": "police",
		"base_prices": 1.0,
		"security_level": 0.5,
		"surveillance_level": 0.6,
		"atmosphere": {
			"cleanliness": 0.5,
			"drone_density": 0.3,
			"ad_density": 0.7,
			"citizen_mood": "resigned"
		},
		"available_services": ["basic_clinic", "shops", "food_stalls", "metro"],
		"restricted_items": []
	},
	
	"rust_belt": {
		"name": "Rust Belt",
		"type": DistrictType.INDUSTRIAL,
		"description": "Usines automatisées. Pollution permanente. Travailleurs remplacés.",
		"economy": EconomyType.MIXED,
		"ideology": "La machine ne dort jamais. Toi non plus.",
		"violence_style": ViolenceStyle.ECONOMIC,
		"controlling_faction": "novatech",
		"base_prices": 0.9,
		"security_level": 0.4,
		"surveillance_level": 0.7,
		"atmosphere": {
			"cleanliness": 0.2,
			"drone_density": 0.5,
			"ad_density": 0.3,
			"citizen_mood": "exhausted"
		},
		"available_services": ["industrial_clinic", "junk_shops", "vertical_farms"],
		"restricted_items": ["union_materials"]
	},
	
	"dead_end": {
		"name": "Dead End",
		"type": DistrictType.SLUMS,
		"description": "Oubliés du système. Violence quotidienne. Solidarité fragile.",
		"economy": EconomyType.BLACK_MARKET,
		"ideology": "Chacun pour soi. Ou crever ensemble.",
		"violence_style": ViolenceStyle.BRUTAL,
		"controlling_faction": "anarkingdom",
		"base_prices": 0.7,
		"security_level": 0.1,
		"surveillance_level": 0.1,
		"atmosphere": {
			"cleanliness": 0.1,
			"drone_density": 0.05,
			"ad_density": 0.2,
			"citizen_mood": "desperate"
		},
		"available_services": ["chop_shop", "black_market", "food_stalls", "fixer"],
		"restricted_items": []  # Tout est permis
	},
	
	"the_wastes": {
		"name": "The Wastes",
		"type": DistrictType.NOMAD,
		"description": "Au-delà des murs. Junk rides. Liberté fragile.",
		"economy": EconomyType.BARTER,
		"ideology": "La route est tout. Les murs sont la mort.",
		"violence_style": ViolenceStyle.GUERRILLA,
		"controlling_faction": "nomads",
		"base_prices": 0.8,
		"security_level": 0.2,
		"surveillance_level": 0.0,
		"atmosphere": {
			"cleanliness": 0.3,
			"drone_density": 0.0,
			"ad_density": 0.0,
			"citizen_mood": "wary_but_free"
		},
		"available_services": ["scrap_market", "nomad_clinic", "vehicle_repair", "trade_post"],
		"restricted_items": ["corpo_ids"]
	},
	
	"the_depths": {
		"name": "The Depths",
		"type": DistrictType.UNDERGROUND,
		"description": "Sous la ville. Chop shops. Hackers. Cultes techno. IA oubliées.",
		"economy": EconomyType.BLACK_MARKET,
		"ideology": "La surface a oublié. Nous nous souvenons.",
		"violence_style": ViolenceStyle.RITUALISTIC,
		"controlling_faction": "ban_captchas",
		"base_prices": 0.6,
		"security_level": 0.05,
		"surveillance_level": 0.0,
		"atmosphere": {
			"cleanliness": 0.0,
			"drone_density": 0.0,
			"ad_density": 0.0,
			"citizen_mood": "hidden"
		},
		"available_services": ["organ_market", "hacker_den", "ai_shrine", "secret_clinic"],
		"restricted_items": []
	},
	
	"neon_mile": {
		"name": "Neon Mile",
		"type": DistrictType.ENTERTAINMENT,
		"description": "Plaisirs sans fin. Tout s'achète. Même l'oubli.",
		"economy": EconomyType.MIXED,
		"ideology": "Travaille dur. Dépense tout. Recommence.",
		"violence_style": ViolenceStyle.CLINICAL,
		"controlling_faction": "entertainment_corps",
		"base_prices": 1.3,
		"security_level": 0.7,
		"surveillance_level": 0.8,
		"atmosphere": {
			"cleanliness": 0.7,
			"drone_density": 0.4,
			"ad_density": 1.0,
			"citizen_mood": "intoxicated"
		},
		"available_services": ["clubs", "casinos", "braindance_parlors", "quiet_rooms", "premium_food"],
		"restricted_items": ["recording_devices"]
	}
}

# ==============================================================================
# VARIABLES
# ==============================================================================

var current_district: String = ""
var _district_states: Dictionary = {}  # district_id -> dynamic state
var _player: Node3D = null

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_initialize_district_states()


func _initialize_district_states() -> void:
	"""Initialise les états dynamiques des districts."""
	for district_id in DISTRICTS.keys():
		var base_data: Dictionary = DISTRICTS[district_id]
		_district_states[district_id] = {
			"tension": 0.3,  # 0-1, niveau de tension
			"economy_health": 0.7,  # 0-1, santé économique
			"population_mood": base_data.atmosphere.citizen_mood,
			"controlling_faction": base_data.controlling_faction,
			"recent_events": [],
			"player_reputation_local": 0  # Réputation locale
		}


# ==============================================================================
# GESTION DES ENTRÉES/SORTIES
# ==============================================================================

func enter_district(district_id: String, player: Node3D) -> Dictionary:
	"""Le joueur entre dans un district."""
	if not DISTRICTS.has(district_id):
		return {"error": "District inconnu"}
	
	var old_district := current_district
	current_district = district_id
	_player = player
	
	if old_district != "":
		district_exited.emit(old_district)
	
	district_entered.emit(district_id)
	
	var district := DISTRICTS[district_id]
	var state: Dictionary = _district_states[district_id]
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Entrée dans %s. %s" % [district.name, _get_atmosphere_description(district_id)])
	
	# Vérifier les items restreints
	var violations := _check_restricted_items(player, district)
	
	return {
		"district": district.name,
		"type": DistrictType.keys()[district.type],
		"atmosphere": district.atmosphere,
		"services": district.available_services,
		"tension": state.tension,
		"violations": violations
	}


func exit_district() -> void:
	"""Le joueur quitte le district actuel."""
	if current_district != "":
		district_exited.emit(current_district)
		current_district = ""
		_player = null


func _get_atmosphere_description(district_id: String) -> String:
	"""Génère une description de l'atmosphère."""
	var district: Dictionary = DISTRICTS[district_id]
	var desc := []
	
	var atmo: Dictionary = district.atmosphere
	if atmo.cleanliness > 0.8:
		desc.append("Propreté artificielle")
	elif atmo.cleanliness < 0.3:
		desc.append("Saleté omniprésente")
	
	if atmo.drone_density > 0.5:
		desc.append("Drones omniprésents")
	
	if atmo.surveillance_level > 0.7:
		desc.append("Surveillance maximale")
	
	return ". ".join(desc) if desc.size() > 0 else "Zone neutre"


# ==============================================================================
# ITEMS RESTREINTS
# ==============================================================================

func _check_restricted_items(player: Node3D, district: Dictionary) -> Array[String]:
	"""Vérifie si le joueur a des items restreints."""
	var violations: Array[String] = []
	var restricted: Array = district.get("restricted_items", [])
	
	for item in restricted:
		if _player_has_item(player, item):
			violations.append(item)
	
	if violations.size() > 0 and district.get("security_level", 0) > 0.5:
		_trigger_security_alert(current_district, violations)
	
	return violations


func _player_has_item(player: Node3D, item_type: String) -> bool:
	"""Vérifie si le joueur a un type d'item."""
	# Logique simplifiée - à connecter avec l'inventaire réel
	if player.has_method("has_item_type"):
		return player.has_item_type(item_type)
	return false


func _trigger_security_alert(district_id: String, violations: Array[String]) -> void:
	"""Déclenche une alerte sécurité."""
	var state: Dictionary = _district_states[district_id]
	state.tension += 0.1
	
	district_event_triggered.emit(district_id, {
		"type": "security_alert",
		"violations": violations,
		"consequence": "surveillance_increased"
	})


# ==============================================================================
# ÉCONOMIE DU DISTRICT
# ==============================================================================

func get_price_modifier(district_id: String = "") -> float:
	"""Retourne le modificateur de prix du district."""
	var d_id := district_id if district_id != "" else current_district
	if not DISTRICTS.has(d_id):
		return 1.0
	
	var base_price: float = DISTRICTS[d_id].base_prices
	var state: Dictionary = _district_states[d_id]
	
	# Ajuster selon l'économie
	var economy_modifier := 1.0 + (0.7 - state.economy_health) * 0.3
	
	# Ajuster selon la réputation locale
	var rep_modifier := 1.0 - (state.player_reputation_local / 100.0 * 0.2)
	
	return base_price * economy_modifier * rep_modifier


func get_available_services(district_id: String = "") -> Array:
	"""Retourne les services disponibles."""
	var d_id := district_id if district_id != "" else current_district
	if not DISTRICTS.has(d_id):
		return []
	return DISTRICTS[d_id].get("available_services", [])


func modify_district_economy(district_id: String, delta: float) -> void:
	"""Modifie la santé économique d'un district."""
	if not _district_states.has(district_id):
		return
	
	var state: Dictionary = _district_states[district_id]
	var old_health: float = state.economy_health
	state.economy_health = clampf(old_health + delta, 0.0, 1.0)
	
	district_economy_changed.emit(district_id, {
		"old": old_health,
		"new": state.economy_health
	})


# ==============================================================================
# TENSION & VIOLENCE
# ==============================================================================

func get_violence_style(district_id: String = "") -> ViolenceStyle:
	"""Retourne le style de violence du district."""
	var d_id := district_id if district_id != "" else current_district
	if not DISTRICTS.has(d_id):
		return ViolenceStyle.BRUTAL
	return DISTRICTS[d_id].violence_style


func modify_tension(district_id: String, delta: float) -> void:
	"""Modifie la tension d'un district."""
	if not _district_states.has(district_id):
		return
	
	var state: Dictionary = _district_states[district_id]
	var old_tension: float = state.tension
	state.tension = clampf(old_tension + delta, 0.0, 1.0)
	
	district_tension_changed.emit(district_id, state.tension)
	
	# Événements de tension
	if state.tension >= 0.8 and old_tension < 0.8:
		_trigger_high_tension_event(district_id)


func _trigger_high_tension_event(district_id: String) -> void:
	"""Déclenche un événement de haute tension."""
	var events := [
		{"type": "riot", "description": "Émeute dans les rues"},
		{"type": "gang_war", "description": "Guerre de gangs"},
		{"type": "lockdown", "description": "Confinement de sécurité"},
		{"type": "blackout", "description": "Coupure de courant"}
	]
	
	var event := events[randi() % events.size()]
	event["district"] = district_id
	
	_district_states[district_id].recent_events.append(event)
	district_event_triggered.emit(district_id, event)


func get_tension(district_id: String = "") -> float:
	"""Retourne la tension d'un district."""
	var d_id := district_id if district_id != "" else current_district
	if not _district_states.has(d_id):
		return 0.5
	return _district_states[d_id].tension


# ==============================================================================
# CONTRÔLE DE FACTION
# ==============================================================================

func get_controlling_faction(district_id: String = "") -> String:
	"""Retourne la faction contrôlant le district."""
	var d_id := district_id if district_id != "" else current_district
	if not _district_states.has(d_id):
		return ""
	return _district_states[d_id].controlling_faction


func change_faction_control(district_id: String, new_faction: String) -> void:
	"""Change le contrôle d'un district."""
	if not _district_states.has(district_id):
		return
	
	var old_faction: String = _district_states[district_id].controlling_faction
	_district_states[district_id].controlling_faction = new_faction
	
	# Augmenter la tension
	_district_states[district_id].tension = minf(1.0, _district_states[district_id].tension + 0.3)
	
	faction_control_changed.emit(district_id, new_faction)
	
	# Impact réputation
	if FactionManager:
		FactionManager.add_reputation(old_faction, -20)
		FactionManager.add_reputation(new_faction, 10)


# ==============================================================================
# RÉPUTATION LOCALE
# ==============================================================================

func modify_local_reputation(district_id: String, delta: int) -> void:
	"""Modifie la réputation locale du joueur."""
	if not _district_states.has(district_id):
		return
	
	var state: Dictionary = _district_states[district_id]
	state.player_reputation_local = clampi(state.player_reputation_local + delta, -100, 100)


func get_local_reputation(district_id: String = "") -> int:
	"""Retourne la réputation locale."""
	var d_id := district_id if district_id != "" else current_district
	if not _district_states.has(d_id):
		return 0
	return _district_states[d_id].player_reputation_local


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_district_data(district_id: String) -> Dictionary:
	"""Retourne toutes les données d'un district."""
	if not DISTRICTS.has(district_id):
		return {}
	
	var base: Dictionary = DISTRICTS[district_id].duplicate(true)
	var state: Dictionary = _district_states.get(district_id, {})
	
	base["dynamic_state"] = state
	return base


func get_all_districts() -> Array[String]:
	"""Retourne la liste des districts."""
	var districts: Array[String] = []
	for key in DISTRICTS.keys():
		districts.append(key)
	return districts


func get_current_district() -> String:
	"""Retourne le district actuel."""
	return current_district


func get_current_district_data() -> Dictionary:
	"""Retourne les données du district actuel."""
	return get_district_data(current_district)


func get_system_summary() -> Dictionary:
	"""Retourne un résumé du système."""
	return {
		"current_district": current_district,
		"current_district_name": DISTRICTS.get(current_district, {}).get("name", ""),
		"total_districts": DISTRICTS.size(),
		"high_tension_districts": _count_high_tension_districts()
	}


func _count_high_tension_districts() -> int:
	"""Compte les districts à haute tension."""
	var count := 0
	for state in _district_states.values():
		if state.tension >= 0.7:
			count += 1
	return count
