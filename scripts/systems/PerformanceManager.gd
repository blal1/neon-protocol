# ==============================================================================
# PerformanceManager.gd - Optimisation Automatique par Device
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Détecte le type de device et applique les paramètres de qualité appropriés.
# Référence: docs/ANDROID_OPTIMIZATION.md
# ==============================================================================

extends Node
class_name PerformanceManager

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal quality_changed(level: QualityLevel)
signal performance_warning(fps: float, recommendation: String)

# ==============================================================================
# ENUMS
# ==============================================================================

enum QualityLevel {
	VERY_LOW,    ## Mobile bas de gamme
	LOW,         ## Mobile milieu de gamme
	MEDIUM,      ## Mobile haut de gamme / PC faible
	HIGH,        ## PC standard
	ULTRA        ## PC haut de gamme
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Auto Detection")
@export var auto_detect_on_ready: bool = true
@export var monitor_fps: bool = true
@export var fps_sample_interval: float = 5.0

@export_group("Thresholds")
@export var low_fps_threshold: float = 25.0
@export var critical_fps_threshold: float = 15.0

@export_group("Current Settings")
@export var current_quality: QualityLevel = QualityLevel.MEDIUM

# ==============================================================================
# VARIABLES
# ==============================================================================

var _gpu_name: String = ""
var _is_mobile: bool = false
var _fps_samples: Array[float] = []
var _sample_timer: float = 0.0

# LOW-END GPUs patterns
const LOW_END_GPUS := [
	"mali-400", "mali-450", "mali-t",
	"adreno 3", "adreno 4", "adreno 5",
	"powervr", "sgx",
	"vivante", "gc7000",
	"intel hd 4", "intel hd 5",
	"geforce 6", "geforce 7", "geforce 8",
	"radeon hd 4", "radeon hd 5"
]

const MID_RANGE_GPUS := [
	"mali-g5", "mali-g7",
	"adreno 6", "adreno 7",
	"apple a", "apple m",
	"intel iris",
	"geforce gtx 9", "geforce gtx 10",
	"radeon rx 4", "radeon rx 5"
]

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_gpu_name = RenderingServer.get_video_adapter_name().to_lower()
	_is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	if auto_detect_on_ready:
		detect_and_apply_quality()
	
	print("[PerformanceManager] GPU: %s | Mobile: %s | Quality: %s" % [
		RenderingServer.get_video_adapter_name(),
		_is_mobile,
		QualityLevel.keys()[current_quality]
	])


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	if not monitor_fps:
		return
	
	_sample_timer += delta
	if _sample_timer >= fps_sample_interval:
		_sample_timer = 0.0
		_check_performance()


func _check_performance() -> void:
	"""Vérifie les performances et ajuste si nécessaire."""
	var current_fps := Engine.get_frames_per_second()
	_fps_samples.append(current_fps)
	
	if _fps_samples.size() > 5:
		_fps_samples.remove_at(0)
	
	var avg_fps := 0.0
	for fps in _fps_samples:
		avg_fps += fps
	avg_fps /= _fps_samples.size()
	
	if avg_fps < critical_fps_threshold:
		_handle_critical_fps(avg_fps)
	elif avg_fps < low_fps_threshold:
		_handle_low_fps(avg_fps)


func _handle_critical_fps(fps: float) -> void:
	"""Gère les FPS critiques."""
	if current_quality > QualityLevel.VERY_LOW:
		var new_level := current_quality - 1 as QualityLevel
		apply_quality_level(new_level)
		performance_warning.emit(fps, "FPS critiques - Qualité réduite à " + QualityLevel.keys()[new_level])


func _handle_low_fps(fps: float) -> void:
	"""Gère les FPS faibles."""
	performance_warning.emit(fps, "FPS faibles détectés: %.1f" % fps)


# ==============================================================================
# DÉTECTION QUALITÉ
# ==============================================================================

func detect_and_apply_quality() -> void:
	"""Détecte automatiquement et applique le niveau de qualité."""
	var detected := _detect_quality_level()
	apply_quality_level(detected)


func _detect_quality_level() -> QualityLevel:
	"""Détecte le niveau de qualité approprié."""
	# Mobile bas de gamme
	if _is_mobile and _is_low_end_gpu():
		return QualityLevel.VERY_LOW
	
	# Mobile milieu de gamme
	if _is_mobile and _is_mid_range_gpu():
		return QualityLevel.LOW
	
	# Mobile haut de gamme
	if _is_mobile:
		return QualityLevel.MEDIUM
	
	# PC avec GPU très faible
	if _is_low_end_gpu():
		return QualityLevel.LOW
	
	# PC avec GPU milieu de gamme
	if _is_mid_range_gpu():
		return QualityLevel.MEDIUM
	
	# PC standard
	return QualityLevel.HIGH


func _is_low_end_gpu() -> bool:
	"""Vérifie si le GPU est bas de gamme."""
	for pattern in LOW_END_GPUS:
		if pattern in _gpu_name:
			return true
	return false


func _is_mid_range_gpu() -> bool:
	"""Vérifie si le GPU est milieu de gamme."""
	for pattern in MID_RANGE_GPUS:
		if pattern in _gpu_name:
			return true
	return false


# ==============================================================================
# APPLICATION QUALITÉ
# ==============================================================================

func apply_quality_level(level: QualityLevel) -> void:
	"""Applique un niveau de qualité."""
	current_quality = level
	
	match level:
		QualityLevel.VERY_LOW:
			_apply_very_low_settings()
		QualityLevel.LOW:
			_apply_low_settings()
		QualityLevel.MEDIUM:
			_apply_medium_settings()
		QualityLevel.HIGH:
			_apply_high_settings()
		QualityLevel.ULTRA:
			_apply_ultra_settings()
	
	quality_changed.emit(level)


func _apply_very_low_settings() -> void:
	"""Paramètres très bas (mobile bas de gamme)."""
	# Résolution
	get_viewport().scaling_3d_scale = 0.5
	
	# Ombres
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_HARD
	)
	
	# Désactiver les effets
	_set_environment_effects(false, false, false, false)
	
	# Physics
	Engine.physics_ticks_per_second = 20


func _apply_low_settings() -> void:
	"""Paramètres bas (mobile milieu de gamme)."""
	get_viewport().scaling_3d_scale = 0.65
	
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW
	)
	
	_set_environment_effects(false, false, false, false)
	
	Engine.physics_ticks_per_second = 30


func _apply_medium_settings() -> void:
	"""Paramètres moyens (mobile haut de gamme / PC faible)."""
	get_viewport().scaling_3d_scale = 0.85
	
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW
	)
	
	_set_environment_effects(true, false, false, false)
	
	Engine.physics_ticks_per_second = 30


func _apply_high_settings() -> void:
	"""Paramètres hauts (PC standard)."""
	get_viewport().scaling_3d_scale = 1.0
	
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
	)
	
	_set_environment_effects(true, true, false, false)
	
	Engine.physics_ticks_per_second = 60


func _apply_ultra_settings() -> void:
	"""Paramètres ultra (PC haut de gamme)."""
	get_viewport().scaling_3d_scale = 1.0
	
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH
	)
	
	_set_environment_effects(true, true, true, true)
	
	Engine.physics_ticks_per_second = 60


func _set_environment_effects(glow: bool, ssao: bool, ssr: bool, sdfgi: bool) -> void:
	"""Configure les effets d'environnement."""
	# Chercher le WorldEnvironment
	var world_env := get_tree().get_first_node_in_group("world_environment")
	if not world_env or not world_env is WorldEnvironment:
		return
	
	var env: Environment = world_env.environment
	if not env:
		return
	
	env.glow_enabled = glow
	env.ssao_enabled = ssao
	env.ssr_enabled = ssr
	env.sdfgi_enabled = sdfgi


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_quality_level() -> QualityLevel:
	"""Retourne le niveau de qualité actuel."""
	return current_quality


func set_quality_level(level: QualityLevel) -> void:
	"""Définit manuellement le niveau de qualité."""
	apply_quality_level(level)


func get_gpu_name() -> String:
	"""Retourne le nom du GPU."""
	return RenderingServer.get_video_adapter_name()


func is_mobile() -> bool:
	"""Vérifie si on est sur mobile."""
	return _is_mobile


func get_current_fps() -> float:
	"""Retourne les FPS actuels."""
	return Engine.get_frames_per_second()


func get_average_fps() -> float:
	"""Retourne la moyenne des FPS récents."""
	if _fps_samples.is_empty():
		return Engine.get_frames_per_second()
	
	var total := 0.0
	for fps in _fps_samples:
		total += fps
	return total / _fps_samples.size()


func get_system_info() -> Dictionary:
	"""Retourne les informations système."""
	return {
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"is_mobile": _is_mobile,
		"quality_level": QualityLevel.keys()[current_quality],
		"current_fps": Engine.get_frames_per_second(),
		"average_fps": get_average_fps(),
		"scaling_3d": get_viewport().scaling_3d_scale,
		"physics_fps": Engine.physics_ticks_per_second
	}
