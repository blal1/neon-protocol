# ==============================================================================
# QuietRoom.gd - Cafés QuietRoom™ (Zones Sûres EMF)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Espaces blindés EMF où aucune surveillance ne passe.
# Gameplay: zone safe, dialogues critiques, quêtes exclusives, twist hack.
# ==============================================================================

extends Node3D
class_name QuietRoom

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal room_entered(player: Node3D)
signal room_exited(player: Node3D)
signal quest_available(quest_data: Dictionary)
signal dialogue_started(npc: Node3D, dialogue_id: String)
signal room_hacked(hack_data: Dictionary)
signal hallucination_triggered()

# ==============================================================================
# ENUMS
# ==============================================================================

enum RoomStatus {
	SECURE,      ## Zone 100% sûre
	COMPROMISED, ## Zone piratée - hallucinations possibles
	LOCKED       ## Zone verrouillée (quête requise)
}

enum RoomType {
	CAFE,        ## Café classique
	LOUNGE,      ## Lounge VIP
	UNDERGROUND, ## Planque secrète
	CORPORATE    ## QuietRoom corporatif
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Identité")
@export var room_name: String = "QuietRoom™ Alpha"
@export var room_type: RoomType = RoomType.CAFE
@export var room_status: RoomStatus = RoomStatus.SECURE

@export_group("Sécurité")
@export var emf_shield_strength: float = 100.0  ## Force du blindage
@export var is_truly_secure: bool = true  ## False = peut être piraté
@export var hack_probability: float = 0.0  ## Chance d'hallucination

@export_group("Quêtes Exclusives")
@export var exclusive_quests: Array[String] = []  ## IDs des quêtes disponibles ici uniquement
@export var required_reputation: int = 0
@export var required_story_progress: int = 0

@export_group("NPCs")
@export var npc_scenes: Array[PackedScene] = []
@export var dialogue_ids: Array[String] = []
@export var romance_npc_id: String = ""

@export_group("Ambiance")
@export var ambient_music: AudioStream
@export var background_chatter: AudioStream

# ==============================================================================
# VARIABLES
# ==============================================================================

var _player_inside: bool = false
var _current_player: Node3D = null
var _npcs: Array[Node3D] = []
var _active_dialogues: Dictionary = {}
var _hallucination_active: bool = false
var _combat_disabled: bool = true

# Audio players
var _music_player: AudioStreamPlayer
var _chatter_player: AudioStreamPlayer

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_setup_safe_zone()
	_setup_audio()
	_spawn_npcs()
	_check_hack_status()


func _setup_safe_zone() -> void:
	"""Configure la zone sûre (pas de combat)."""
	# Créer une Area3D pour la zone
	var area := Area3D.new()
	area.name = "SafeZoneArea"
	area.collision_layer = 0
	area.collision_mask = 2  # Player layer
	
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 6, 20)
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _setup_audio() -> void:
	"""Configure l'audio ambiant."""
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = ambient_music
	_music_player.volume_db = -15.0
	_music_player.autoplay = false
	add_child(_music_player)
	
	_chatter_player = AudioStreamPlayer.new()
	_chatter_player.stream = background_chatter
	_chatter_player.volume_db = -20.0
	_chatter_player.autoplay = false
	add_child(_chatter_player)


func _spawn_npcs() -> void:
	"""Génère les PNJs du QuietRoom."""
	var spawn_offset := 0.0
	for npc_scene in npc_scenes:
		if npc_scene:
			var npc := npc_scene.instantiate() as Node3D
			npc.position = Vector3(spawn_offset, 0, 0)
			spawn_offset += 3.0
			add_child(npc)
			_npcs.append(npc)
			
			# Connecter les dialogues
			if npc.has_signal("dialogue_requested"):
				npc.dialogue_requested.connect(_on_npc_dialogue_requested)


func _check_hack_status() -> void:
	"""Vérifie si le QuietRoom a été piraté."""
	if not is_truly_secure and randf() < hack_probability:
		room_status = RoomStatus.COMPROMISED


# ==============================================================================
# GAMEPLAY - ZONE SÛRE
# ==============================================================================

func is_combat_allowed() -> bool:
	"""Vérifie si le combat est autorisé."""
	return not _combat_disabled or room_status == RoomStatus.COMPROMISED


func disable_player_combat(player: Node3D) -> void:
	"""Désactive le combat pour le joueur."""
	if player.has_method("set_combat_enabled"):
		player.set_combat_enabled(false)
	
	# Désactiver les armes
	if player.has_method("holster_weapon"):
		player.holster_weapon()


func enable_player_combat(player: Node3D) -> void:
	"""Réactive le combat pour le joueur."""
	if player.has_method("set_combat_enabled"):
		player.set_combat_enabled(true)


# ==============================================================================
# GAMEPLAY - QUÊTES EXCLUSIVES
# ==============================================================================

func get_available_quests() -> Array[Dictionary]:
	"""Retourne les quêtes disponibles uniquement dans ce QuietRoom."""
	var quests: Array[Dictionary] = []
	
	for quest_id in exclusive_quests:
		# Vérifier si la quête peut être déclenchée
		if _can_trigger_quest(quest_id):
			var quest_data := {
				"id": quest_id,
				"location": room_name,
				"exclusive": true
			}
			
			# Récupérer les infos de la quête via MissionManager
			if MissionManager and MissionManager.has_method("get_quest_info"):
				var info: Dictionary = MissionManager.get_quest_info(quest_id)
				quest_data.merge(info)
			
			quests.append(quest_data)
	
	return quests


func _can_trigger_quest(quest_id: String) -> bool:
	"""Vérifie si une quête peut être déclenchée."""
	# Vérifier réputation
	if ReputationManager:
		var rep: int = ReputationManager.get_total_reputation()
		if rep < required_reputation:
			return false
	
	# Vérifier progression histoire
	if MissionManager and MissionManager.has_method("get_story_progress"):
		var progress: int = MissionManager.get_story_progress()
		if progress < required_story_progress:
			return false
	
	# Vérifier si déjà complétée
	if MissionManager and MissionManager.has_method("is_quest_completed"):
		if MissionManager.is_quest_completed(quest_id):
			return false
	
	return true


func trigger_quest(quest_id: String) -> void:
	"""Déclenche une quête exclusive."""
	if quest_id in exclusive_quests and _can_trigger_quest(quest_id):
		quest_available.emit({"id": quest_id, "source": room_name})
		
		if MissionManager and MissionManager.has_method("start_quest"):
			MissionManager.start_quest(quest_id)


# ==============================================================================
# GAMEPLAY - DIALOGUES & ROMANCES
# ==============================================================================

func start_dialogue_with(npc: Node3D, dialogue_id: String) -> void:
	"""Démarre un dialogue avec un PNJ."""
	if room_status == RoomStatus.COMPROMISED and randf() < 0.3:
		# Dialogue peut être falsifié
		_trigger_hallucination("false_dialogue", dialogue_id)
		return
	
	_active_dialogues[npc] = dialogue_id
	dialogue_started.emit(npc, dialogue_id)
	
	# Notifier le système de dialogue
	if CutsceneManager and CutsceneManager.has_method("start_dialogue"):
		CutsceneManager.start_dialogue(dialogue_id)


func is_romance_available() -> bool:
	"""Vérifie si une romance est disponible."""
	return romance_npc_id != "" and room_status == RoomStatus.SECURE


func get_romance_npc() -> Node3D:
	"""Retourne le PNJ romance si disponible."""
	for npc in _npcs:
		if npc.has_meta("npc_id") and npc.get_meta("npc_id") == romance_npc_id:
			return npc
	return null


# ==============================================================================
# GAMEPLAY - TWIST: PIRATAGE
# ==============================================================================

func hack_room() -> void:
	"""Pirate le QuietRoom (événement scénaristique)."""
	if is_truly_secure:
		return  # Impossible de pirater
	
	room_status = RoomStatus.COMPROMISED
	_hallucination_active = true
	
	room_hacked.emit({
		"room": room_name,
		"effects": ["hallucinations", "false_npcs", "narrative_lies"]
	})
	
	# Effets visuels de glitch
	_apply_hack_effects()


func _apply_hack_effects() -> void:
	"""Applique les effets visuels du piratage."""
	# Créer des PNJs fantômes/faux
	_spawn_fake_npcs()
	
	# Modifier l'éclairage
	var lights := get_tree().get_nodes_in_group("lights")
	for light in lights:
		if light is Light3D and is_ancestor_of(light):
			var tween := create_tween()
			tween.set_loops()
			tween.tween_property(light, "light_energy", 0.2, 0.5)
			tween.tween_property(light, "light_energy", 1.0, 0.5)


func _spawn_fake_npcs() -> void:
	"""Génère des faux PNJs (hallucinations)."""
	for npc in _npcs:
		var fake := npc.duplicate() as Node3D
		fake.name = "FakeNPC_" + str(randi())
		fake.set_meta("is_hallucination", true)
		fake.modulate = Color(1, 1, 1, 0.7) if fake is CanvasItem else Color.WHITE
		fake.position += Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		add_child(fake)


func _trigger_hallucination(type: String, context: String = "") -> void:
	"""Déclenche une hallucination."""
	hallucination_triggered.emit()
	
	match type:
		"false_dialogue":
			# Le dialogue dit des mensonges
			if TTSManager and TTSManager.has_method("speak"):
				TTSManager.speak("Attention: source de données corrompue détectée")
		"false_npc":
			# Un PNJ disparaît
			if _npcs.size() > 0:
				var random_npc := _npcs[randi() % _npcs.size()]
				var tween := create_tween()
				tween.tween_property(random_npc, "modulate:a", 0.0, 1.0)


func restore_room() -> void:
	"""Restaure le QuietRoom à son état sécurisé."""
	room_status = RoomStatus.SECURE
	_hallucination_active = false
	
	# Supprimer les faux PNJs
	for child in get_children():
		if child.has_meta("is_hallucination"):
			child.queue_free()


# ==============================================================================
# CALLBACKS
# ==============================================================================

func _on_body_entered(body: Node3D) -> void:
	"""Appelé quand le joueur entre."""
	if body.is_in_group("player"):
		_player_inside = true
		_current_player = body
		
		# Désactiver le combat
		disable_player_combat(body)
		
		# Musique ambiante
		if _music_player and ambient_music:
			_music_player.play()
		if _chatter_player and background_chatter:
			_chatter_player.play()
		
		room_entered.emit(body)
		
		# TTS pour accessibilité
		if TTSManager and TTSManager.has_method("speak"):
			var status_text := "Zone sûre" if room_status == RoomStatus.SECURE else "Zone compromise"
			TTSManager.speak("Entrée dans %s. %s." % [room_name, status_text])
		
		# Vérifier les quêtes disponibles
		var quests := get_available_quests()
		for quest in quests:
			quest_available.emit(quest)


func _on_body_exited(body: Node3D) -> void:
	"""Appelé quand le joueur sort."""
	if body.is_in_group("player"):
		_player_inside = false
		_current_player = null
		
		# Réactiver le combat
		enable_player_combat(body)
		
		# Arrêter la musique
		_music_player.stop()
		_chatter_player.stop()
		
		room_exited.emit(body)


func _on_npc_dialogue_requested(npc: Node3D, dialogue_id: String) -> void:
	"""Appelé quand un PNJ demande à démarrer un dialogue."""
	start_dialogue_with(npc, dialogue_id)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_room_info() -> Dictionary:
	"""Retourne les infos du QuietRoom."""
	return {
		"name": room_name,
		"type": RoomType.keys()[room_type],
		"status": RoomStatus.keys()[room_status],
		"secure": room_status == RoomStatus.SECURE,
		"npcs_count": _npcs.size(),
		"quests_available": exclusive_quests.size()
	}


func is_player_inside() -> bool:
	"""Vérifie si le joueur est dans le QuietRoom."""
	return _player_inside


func is_secure() -> bool:
	"""Vérifie si le QuietRoom est sécurisé."""
	return room_status == RoomStatus.SECURE
