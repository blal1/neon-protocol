# ==============================================================================
# CharacterStateMachine.gd - Machine à États Finis pour Animation
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gestion des transitions d'animation (Idle -> Attack -> HitStun -> Roll).
# Intégration avec AnimationTree.
# ==============================================================================

extends Node
class_name CharacterStateMachine

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal state_changed(old_state: StringName, new_state: StringName)
signal state_entered(state: StringName)
signal state_exited(state: StringName)
signal transition_blocked(from: StringName, to: StringName, reason: String)

# ==============================================================================
# ÉTATS DISPONIBLES
# ==============================================================================

enum State {
	IDLE,
	WALK,
	RUN,
	JUMP,
	FALL,
	LAND,
	ATTACK_1,
	ATTACK_2,
	ATTACK_3,
	ATTACK_HEAVY,
	DODGE,
	ROLL,
	BLOCK,
	PARRY,
	HIT_STUN,
	KNOCKDOWN,
	GET_UP,
	DEAD,
	INTERACT,
	HACK,
	COVER,
	AIM,
	SHOOT,
	RELOAD,
	TACTICAL_MODE
}

# ==============================================================================
# CONFIGURATION DES TRANSITIONS
# ==============================================================================

## Transitions autorisées: from_state -> [allowed_to_states]
const TRANSITIONS: Dictionary = {
	State.IDLE: [State.WALK, State.RUN, State.JUMP, State.ATTACK_1, State.DODGE, 
				 State.BLOCK, State.INTERACT, State.HACK, State.AIM, State.TACTICAL_MODE,
				 State.HIT_STUN, State.KNOCKDOWN],
	
	State.WALK: [State.IDLE, State.RUN, State.JUMP, State.ATTACK_1, State.DODGE,
				 State.BLOCK, State.INTERACT, State.AIM, State.HIT_STUN],
	
	State.RUN: [State.IDLE, State.WALK, State.JUMP, State.DODGE, State.ROLL,
				State.HIT_STUN, State.ATTACK_1],
	
	State.JUMP: [State.FALL, State.ATTACK_1, State.HIT_STUN],
	
	State.FALL: [State.LAND, State.HIT_STUN, State.ATTACK_1],
	
	State.LAND: [State.IDLE, State.WALK, State.RUN, State.ROLL, State.HIT_STUN],
	
	State.ATTACK_1: [State.ATTACK_2, State.IDLE, State.DODGE, State.HIT_STUN, State.BLOCK],
	State.ATTACK_2: [State.ATTACK_3, State.IDLE, State.DODGE, State.HIT_STUN],
	State.ATTACK_3: [State.IDLE, State.DODGE, State.HIT_STUN],
	State.ATTACK_HEAVY: [State.IDLE, State.HIT_STUN],
	
	State.DODGE: [State.IDLE, State.WALK, State.RUN, State.ATTACK_1],
	State.ROLL: [State.IDLE, State.WALK, State.RUN, State.ATTACK_1],
	
	State.BLOCK: [State.IDLE, State.PARRY, State.HIT_STUN, State.ATTACK_1],
	State.PARRY: [State.IDLE, State.ATTACK_1, State.HIT_STUN],
	
	State.HIT_STUN: [State.IDLE, State.KNOCKDOWN, State.DEAD],
	State.KNOCKDOWN: [State.GET_UP, State.DEAD],
	State.GET_UP: [State.IDLE],
	
	State.DEAD: [],  # Pas de sortie
	
	State.INTERACT: [State.IDLE, State.HIT_STUN],
	State.HACK: [State.IDLE, State.HIT_STUN],
	
	State.COVER: [State.IDLE, State.AIM, State.SHOOT, State.HIT_STUN],
	State.AIM: [State.IDLE, State.SHOOT, State.COVER, State.HIT_STUN],
	State.SHOOT: [State.AIM, State.IDLE, State.RELOAD, State.HIT_STUN],
	State.RELOAD: [State.IDLE, State.AIM, State.HIT_STUN],
	
	State.TACTICAL_MODE: [State.IDLE, State.AIM, State.ATTACK_1]
}

## Durées minimales des états (en secondes)
const STATE_DURATIONS: Dictionary = {
	State.ATTACK_1: 0.4,
	State.ATTACK_2: 0.4,
	State.ATTACK_3: 0.6,
	State.ATTACK_HEAVY: 1.0,
	State.DODGE: 0.3,
	State.ROLL: 0.5,
	State.PARRY: 0.2,
	State.HIT_STUN: 0.3,
	State.KNOCKDOWN: 1.5,
	State.GET_UP: 0.8,
	State.LAND: 0.15,
	State.INTERACT: 0.5,
	State.RELOAD: 1.5
}

## États interruptibles par dégâts
const DAMAGE_INTERRUPTIBLE: Array[State] = [
	State.IDLE, State.WALK, State.RUN, State.ATTACK_1, State.ATTACK_2,
	State.AIM, State.SHOOT, State.INTERACT, State.HACK, State.RELOAD
]

# ==============================================================================
# VARIABLES
# ==============================================================================

var current_state: State = State.IDLE
var previous_state: State = State.IDLE
var _state_timer: float = 0.0
var _locked_until: float = 0.0
var _animation_tree: AnimationTree = null
var _animation_state_machine: AnimationNodeStateMachinePlayback = null

## Buffer d'input pour les combos
var _input_buffer: Array[State] = []
var _input_buffer_time: float = 0.3
var _input_buffer_timer: float = 0.0

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	pass


func setup(animation_tree: AnimationTree) -> void:
	"""Configure avec un AnimationTree."""
	_animation_tree = animation_tree
	
	if _animation_tree:
		_animation_state_machine = _animation_tree.get("parameters/playback")


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	_state_timer += delta
	
	# Gérer le buffer d'input
	if not _input_buffer.is_empty():
		_input_buffer_timer -= delta
		if _input_buffer_timer <= 0:
			_input_buffer.clear()
	
	# Auto-transition après durée d'état
	_check_auto_transitions()


func _check_auto_transitions() -> void:
	"""Vérifie les transitions automatiques."""
	if not STATE_DURATIONS.has(current_state):
		return
	
	var duration: float = STATE_DURATIONS[current_state]
	if _state_timer >= duration:
		# Buffer check pour combos
		if not _input_buffer.is_empty():
			var buffered := _input_buffer.pop_front()
			if can_transition_to(buffered):
				transition_to(buffered)
				return
		
		# Retour à idle ou état approprié
		match current_state:
			State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
				transition_to(State.IDLE)
			State.DODGE, State.ROLL:
				transition_to(State.IDLE)
			State.LAND:
				transition_to(State.IDLE)
			State.GET_UP:
				transition_to(State.IDLE)
			State.HIT_STUN:
				transition_to(State.IDLE)


# ==============================================================================
# TRANSITIONS
# ==============================================================================

func can_transition_to(new_state: State) -> bool:
	"""Vérifie si une transition est possible."""
	# État mort = pas de sortie
	if current_state == State.DEAD:
		return false
	
	# Vérifier si locked
	if _state_timer < _locked_until:
		return false
	
	# Vérifier les transitions autorisées
	if not TRANSITIONS.has(current_state):
		return false
	
	var allowed: Array = TRANSITIONS[current_state]
	return new_state in allowed


func transition_to(new_state: State, force: bool = false) -> bool:
	"""Effectue une transition d'état."""
	if not force and not can_transition_to(new_state):
		transition_blocked.emit(
			State.keys()[current_state],
			State.keys()[new_state],
			"Transition not allowed"
		)
		return false
	
	var old_state := current_state
	
	# Exécuter la sortie de l'état
	_exit_state(old_state)
	
	# Changer l'état
	previous_state = old_state
	current_state = new_state
	_state_timer = 0.0
	
	# Calculer le lock time
	_locked_until = STATE_DURATIONS.get(new_state, 0.0) * 0.7
	
	# Exécuter l'entrée dans l'état
	_enter_state(new_state)
	
	# Signaux
	state_exited.emit(State.keys()[old_state])
	state_entered.emit(State.keys()[new_state])
	state_changed.emit(State.keys()[old_state], State.keys()[new_state])
	
	# Mettre à jour l'AnimationTree
	_update_animation(new_state)
	
	return true


func force_transition_to(new_state: State) -> void:
	"""Force une transition (ignore les règles)."""
	transition_to(new_state, true)


func buffer_input(state: State) -> void:
	"""Buffer un input pour combo."""
	_input_buffer.append(state)
	_input_buffer_timer = _input_buffer_time


# ==============================================================================
# ENTRÉE/SORTIE D'ÉTATS
# ==============================================================================

func _enter_state(state: State) -> void:
	"""Logique d'entrée dans un état."""
	match state:
		State.TACTICAL_MODE:
			Engine.time_scale = 0.25
		State.DEAD:
			# Désactiver les inputs
			set_process_input(false)


func _exit_state(state: State) -> void:
	"""Logique de sortie d'un état."""
	match state:
		State.TACTICAL_MODE:
			Engine.time_scale = 1.0


# ==============================================================================
# ANIMATION
# ==============================================================================

func _update_animation(state: State) -> void:
	"""Met à jour l'AnimationTree."""
	if not _animation_state_machine:
		return
	
	var anim_name := _state_to_animation(state)
	_animation_state_machine.travel(anim_name)


func _state_to_animation(state: State) -> String:
	"""Convertit un état en nom d'animation."""
	match state:
		State.IDLE: return "idle"
		State.WALK: return "walk"
		State.RUN: return "run"
		State.JUMP: return "jump"
		State.FALL: return "fall"
		State.LAND: return "land"
		State.ATTACK_1: return "attack_1"
		State.ATTACK_2: return "attack_2"
		State.ATTACK_3: return "attack_3"
		State.ATTACK_HEAVY: return "attack_heavy"
		State.DODGE: return "dodge"
		State.ROLL: return "roll"
		State.BLOCK: return "block"
		State.PARRY: return "parry"
		State.HIT_STUN: return "hit_stun"
		State.KNOCKDOWN: return "knockdown"
		State.GET_UP: return "get_up"
		State.DEAD: return "death"
		State.INTERACT: return "interact"
		State.HACK: return "hack"
		State.COVER: return "cover"
		State.AIM: return "aim"
		State.SHOOT: return "shoot"
		State.RELOAD: return "reload"
		State.TACTICAL_MODE: return "tactical_idle"
		_: return "idle"


# ==============================================================================
# HELPERS DE COMBAT
# ==============================================================================

func receive_damage() -> bool:
	"""Gère la réception de dégâts."""
	if current_state in DAMAGE_INTERRUPTIBLE:
		transition_to(State.HIT_STUN)
		return true
	return false


func receive_knockdown() -> bool:
	"""Gère un knockdown."""
	if current_state != State.DEAD:
		force_transition_to(State.KNOCKDOWN)
		return true
	return false


func die() -> void:
	"""Déclenche la mort."""
	force_transition_to(State.DEAD)


func is_attacking() -> bool:
	"""Vérifie si en attaque."""
	return current_state in [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3, 
							  State.ATTACK_HEAVY, State.SHOOT]


func is_vulnerable() -> bool:
	"""Vérifie si vulnérable aux dégâts."""
	return current_state in DAMAGE_INTERRUPTIBLE


func is_invulnerable() -> bool:
	"""Vérifie si invulnérable (i-frames)."""
	return current_state in [State.DODGE, State.ROLL]


func is_blocking() -> bool:
	"""Vérifie si en bloc."""
	return current_state in [State.BLOCK, State.PARRY]


func can_move() -> bool:
	"""Vérifie si peut bouger."""
	return current_state in [State.IDLE, State.WALK, State.RUN, State.AIM]


func can_attack() -> bool:
	"""Vérifie si peut attaquer."""
	return can_transition_to(State.ATTACK_1)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_current_state() -> State:
	"""Retourne l'état actuel."""
	return current_state


func get_current_state_name() -> String:
	"""Retourne le nom de l'état actuel."""
	return State.keys()[current_state]


func get_state_duration() -> float:
	"""Retourne le temps dans l'état actuel."""
	return _state_timer


func get_state_progress() -> float:
	"""Retourne la progression dans l'état (0-1)."""
	var duration: float = STATE_DURATIONS.get(current_state, 1.0)
	return minf(1.0, _state_timer / duration)


func is_state(check_state: State) -> bool:
	"""Vérifie si dans un état spécifique."""
	return current_state == check_state


func reset() -> void:
	"""Reset à l'état initial."""
	force_transition_to(State.IDLE)
	_input_buffer.clear()
