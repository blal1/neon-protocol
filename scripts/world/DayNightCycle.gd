# ==============================================================================
# DayNightCycle.gd - Cycle jour/nuit
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère le cycle jour/nuit avec effets visuels et gameplay
# ==============================================================================

extends Node
class_name DayNightCycle

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal time_changed(hour: int, minute: int)
signal period_changed(period: TimePeriod)
signal dawn_started
signal day_started
signal dusk_started
signal night_started

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum TimePeriod {
	DAWN,    # 5h - 7h
	DAY,     # 7h - 18h
	DUSK,    # 18h - 20h
	NIGHT    # 20h - 5h
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Temps")
@export var game_minutes_per_real_second: float = 2.0  ## Vitesse du temps
@export var starting_hour: int = 8  ## Heure de départ (0-23)
@export var starting_minute: int = 0

@export_group("Lumière")
@export var sun_light: DirectionalLight3D
@export var environment: WorldEnvironment

@export_group("Couleurs")
@export var dawn_color: Color = Color(1.0, 0.6, 0.4, 1.0)
@export var day_color: Color = Color(1.0, 0.95, 0.9, 1.0)
@export var dusk_color: Color = Color(1.0, 0.4, 0.3, 1.0)
@export var night_color: Color = Color(0.3, 0.35, 0.5, 1.0)

@export_group("Intensité")
@export var dawn_intensity: float = 0.5
@export var day_intensity: float = 1.0
@export var dusk_intensity: float = 0.4
@export var night_intensity: float = 0.1

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_hour: int = 8
var current_minute: int = 0
var current_period: TimePeriod = TimePeriod.DAY
var is_paused: bool = false

var _time_accumulator: float = 0.0
var _last_period: TimePeriod = TimePeriod.DAY

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	current_hour = starting_hour
	current_minute = starting_minute
	_update_period()
	_apply_lighting()


func _process(delta: float) -> void:
	"""Mise à jour du temps."""
	if is_paused:
		return
	
	_time_accumulator += delta * game_minutes_per_real_second
	
	while _time_accumulator >= 1.0:
		_time_accumulator -= 1.0
		_advance_minute()


# ==============================================================================
# GESTION DU TEMPS
# ==============================================================================

func _advance_minute() -> void:
	"""Avance d'une minute."""
	current_minute += 1
	
	if current_minute >= 60:
		current_minute = 0
		current_hour += 1
		
		if current_hour >= 24:
			current_hour = 0
	
	time_changed.emit(current_hour, current_minute)
	_update_period()
	_apply_lighting()


func _update_period() -> void:
	"""Met à jour la période de la journée."""
	_last_period = current_period
	
	if current_hour >= 5 and current_hour < 7:
		current_period = TimePeriod.DAWN
	elif current_hour >= 7 and current_hour < 18:
		current_period = TimePeriod.DAY
	elif current_hour >= 18 and current_hour < 20:
		current_period = TimePeriod.DUSK
	else:
		current_period = TimePeriod.NIGHT
	
	if current_period != _last_period:
		_on_period_changed()


func _on_period_changed() -> void:
	"""Appelé quand la période change."""
	period_changed.emit(current_period)
	
	match current_period:
		TimePeriod.DAWN:
			dawn_started.emit()
		TimePeriod.DAY:
			day_started.emit()
		TimePeriod.DUSK:
			dusk_started.emit()
		TimePeriod.NIGHT:
			night_started.emit()
	
	# TTS pour accessibilité
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		var period_names := ["Aube", "Jour", "Crépuscule", "Nuit"]
		tts.speak(period_names[current_period] + ", " + str(current_hour) + " heures")


# ==============================================================================
# ÉCLAIRAGE
# ==============================================================================

func _apply_lighting() -> void:
	"""Applique l'éclairage selon le temps."""
	var target_color: Color
	var target_intensity: float
	var sun_rotation: float
	
	# Calculer le pourcentage dans la période
	var progress := _get_period_progress()
	
	match current_period:
		TimePeriod.DAWN:
			target_color = dawn_color.lerp(day_color, progress)
			target_intensity = lerp(dawn_intensity, day_intensity, progress)
			sun_rotation = lerp(-15.0, 30.0, progress)
		TimePeriod.DAY:
			target_color = day_color
			target_intensity = day_intensity
			sun_rotation = lerp(30.0, 150.0, progress)
		TimePeriod.DUSK:
			target_color = day_color.lerp(dusk_color, progress)
			target_intensity = lerp(day_intensity, dusk_intensity, progress)
			sun_rotation = lerp(150.0, 195.0, progress)
		TimePeriod.NIGHT:
			target_color = night_color
			target_intensity = night_intensity
			sun_rotation = lerp(195.0, 345.0, progress)
	
	# Appliquer au soleil
	if sun_light:
		sun_light.light_color = target_color
		sun_light.light_energy = target_intensity
		sun_light.rotation_degrees.x = -sun_rotation
	
	# Appliquer à l'environnement
	if environment and environment.environment:
		environment.environment.ambient_light_color = target_color
		environment.environment.ambient_light_energy = target_intensity * 0.3


func _get_period_progress() -> float:
	"""Retourne la progression dans la période actuelle (0-1)."""
	match current_period:
		TimePeriod.DAWN:  # 5h - 7h (2h)
			return float((current_hour - 5) * 60 + current_minute) / 120.0
		TimePeriod.DAY:  # 7h - 18h (11h)
			return float((current_hour - 7) * 60 + current_minute) / 660.0
		TimePeriod.DUSK:  # 18h - 20h (2h)
			return float((current_hour - 18) * 60 + current_minute) / 120.0
		TimePeriod.NIGHT:  # 20h - 5h (9h)
			if current_hour >= 20:
				return float((current_hour - 20) * 60 + current_minute) / 540.0
			else:
				return float((current_hour + 4) * 60 + current_minute) / 540.0
	return 0.0


# ==============================================================================
# CONTRÔLE
# ==============================================================================

func set_time(hour: int, minute: int = 0) -> void:
	"""Définit l'heure."""
	current_hour = clamp(hour, 0, 23)
	current_minute = clamp(minute, 0, 59)
	_update_period()
	_apply_lighting()
	time_changed.emit(current_hour, current_minute)


func skip_to_period(period: TimePeriod) -> void:
	"""Avance jusqu'à une période spécifique."""
	match period:
		TimePeriod.DAWN:
			set_time(5, 0)
		TimePeriod.DAY:
			set_time(8, 0)
		TimePeriod.DUSK:
			set_time(18, 0)
		TimePeriod.NIGHT:
			set_time(22, 0)


func pause_time() -> void:
	"""Met le temps en pause."""
	is_paused = true


func resume_time() -> void:
	"""Reprend le temps."""
	is_paused = false


func set_time_speed(speed: float) -> void:
	"""Définit la vitesse du temps."""
	game_minutes_per_real_second = clamp(speed, 0.1, 60.0)


# ==============================================================================
# GAMEPLAY
# ==============================================================================

func is_night() -> bool:
	"""Retourne true si c'est la nuit."""
	return current_period == TimePeriod.NIGHT


func is_day() -> bool:
	"""Retourne true si c'est le jour."""
	return current_period == TimePeriod.DAY


func get_visibility_multiplier() -> float:
	"""Retourne un multiplicateur de visibilité pour l'IA."""
	match current_period:
		TimePeriod.DAWN:
			return 0.7
		TimePeriod.DAY:
			return 1.0
		TimePeriod.DUSK:
			return 0.6
		TimePeriod.NIGHT:
			return 0.4
	return 1.0


func get_enemy_spawn_multiplier() -> float:
	"""Retourne un multiplicateur pour les spawns d'ennemis."""
	match current_period:
		TimePeriod.NIGHT:
			return 1.5  # Plus d'ennemis la nuit
		TimePeriod.DAY:
			return 0.8  # Moins le jour
	return 1.0


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_time_string() -> String:
	"""Retourne l'heure formatée."""
	return "%02d:%02d" % [current_hour, current_minute]


func get_period_name() -> String:
	"""Retourne le nom de la période."""
	match current_period:
		TimePeriod.DAWN:
			return "Aube"
		TimePeriod.DAY:
			return "Jour"
		TimePeriod.DUSK:
			return "Crépuscule"
		TimePeriod.NIGHT:
			return "Nuit"
	return "Inconnu"


func get_current_period() -> TimePeriod:
	"""Retourne la période actuelle."""
	return current_period
