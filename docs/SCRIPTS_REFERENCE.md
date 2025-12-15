# 📜 Documentation des Scripts - Neon Protocol

## Vue d'Ensemble

Ce document décrit tous les scripts du projet, leur rôle, et comment les configurer.

---

## 🎮 Scripts Joueur (`scripts/player/`)

### Player.gd
**Type**: CharacterBody3D  
**Rôle**: Contrôleur principal du joueur

**Variables clés**:
```gdscript
@export var move_speed: float = 5.0
@export var rotation_speed: float = 10.0
```

**Signaux**:
- `player_moved(position: Vector3)`
- `player_died`
- `player_respawned`

---

### CombatManager.gd
**Type**: Node (enfant de Player)  
**Rôle**: Gestion du combat et des combos

**Configuration**:
```gdscript
@export var auto_target_range: float = 5.0  # Rayon auto-ciblage
@export var attack_damage: float = 25.0
@export var max_combo: int = 3
@export var combo_window: float = 0.8       # Temps pour enchaîner
```

**Utilisation**:
```gdscript
CombatManager.request_attack()  # Appelé par le bouton attaque
```

---

### DashAbility.gd
**Type**: Node (enfant de Player)  
**Rôle**: Capacité de dash avec invincibilité

**Configuration**:
```gdscript
@export var dash_speed: float = 20.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0
@export var invincibility_enabled: bool = true
```

---

### PlayerAnimationController.gd
**Type**: Node  
**Rôle**: Animations procédurales (sans AnimationPlayer)

**Animations disponibles**:
- `play_idle()` - Respiration idle
- `play_walk()` - Marche avec bobbing
- `play_attack(combo_level)` - Swing d'attaque
- `play_dash(direction)` - Squash/stretch
- `play_hit()` - Flash rouge + recul
- `play_death()` / `play_respawn()`

---

### WeaponVisuals.gd
**Type**: Node3D  
**Rôle**: Gestion des armes visuelles

**Armes disponibles**:
| ID | Type | Description |
|----|------|-------------|
| `katana` | Melee | Cyber katana lumineux |
| `stun_baton` | Melee | Matraque électrique |
| `pistol` | Ranged | Pistolet cyber |
| `plasma_rifle` | Ranged | Fusil plasma |
| `cyber_fists` | Cyber | Poings augmentés |

**Utilisation**:
```gdscript
WeaponVisuals.equip_weapon("katana")
WeaponVisuals.play_attack_animation(combo_level)
```

---

## 👾 Scripts Ennemis (`scripts/enemies/`)

### SecurityRobot.gd
**Type**: CharacterBody3D  
**Rôle**: Ennemi de base avec IA de patrouille/combat

**États**:
- `PATROL` - Patrouille entre waypoints
- `CHASE` - Poursuite du joueur
- `ATTACK` - Attaque au corps-à-corps
- `RETURN` - Retour à la patrouille
- `SEARCH` - Recherche après perte de vue

**Configuration**:
```gdscript
@export var detection_range: float = 10.0
@export var attack_range: float = 2.0
@export var patrol_speed: float = 3.0
@export var chase_speed: float = 5.0
@export var waypoints: Array[Node3D] = []  # Points de patrouille
```

---

### EnemyDrone.gd
**Type**: CharacterBody3D  
**Rôle**: Drone volant avec projectiles

**Spécificités**:
- Vol avec bobbing
- Maintien de distance
- Tir à distance
- Vulnérable aux EMP

---

### EnemyTurret.gd
**Type**: StaticBody3D  
**Rôle**: Tourelle fixe hackable

**Configuration**:
```gdscript
@export var detection_range: float = 18.0
@export var fire_rate: float = 0.5
@export var burst_count: int = 3
@export var can_be_hacked: bool = true
```

**Éléments spéciaux**:
- Mode scan (balayage)
- Mode hacké (attaque les ennemis)

---

### BossEnemy.gd
**Type**: CharacterBody3D  
**Rôle**: Boss avec phases multiples

**Phases**:
| Phase | Seuil HP | Attaques |
|-------|----------|----------|
| 1 | 100-60% | Melee, Ranged |
| 2 | 60-30% | + Charge |
| 3 | 30-0% | + AOE |

---

## 🔊 Scripts Audio (`scripts/audio/`)

### MusicManager.gd (Autoload)
**Rôle**: Gestion des musiques contextuelles

**Contextes**:
```gdscript
enum MusicContext {
    MENU, EXPLORATION, COMBAT, STEALTH, 
    BOSS, CUTSCENE, VICTORY, GAMEOVER
}
```

**Utilisation**:
```gdscript
MusicManager.set_context(MusicManager.MusicContext.COMBAT)
MusicManager.enter_boss()
MusicManager.play_victory()
```

---

### TTSManager.gd (Autoload)
**Rôle**: Text-to-Speech pour accessibilité

**Priorités**:
| Niveau | Usage |
|--------|-------|
| LOW | Hints optionnels |
| NORMAL | Messages standards |
| HIGH | Alertes (interrompt) |
| CRITICAL | Priorité absolue |

**Utilisation**:
```gdscript
TTSManager.speak("Ennemi détecté", TTSManager.Priority.HIGH)
TTSManager.announce_health(current, max)
TTSManager.announce_enemy_count(3)
```

---

### SonarNavigation.gd
**Rôle**: Navigation audio pour joueurs aveugles

**Fonctionnalités**:
- Ping objectif (pitch = distance)
- Détection ennemis spatial
- Détection obstacles (raycasts)
- Annonces TTS directionnelles

**Utilisation**:
```gdscript
SonarNavigation.set_target(Vector3(10, 0, 5))
SonarNavigation.set_pulse_interval(1.0)  # Fréquence
```

---

## 🎯 Scripts Gameplay (`scripts/gameplay/`)

### Pickup.gd
**Rôle**: Items ramassables

**Types**:
| Type | Effet |
|------|-------|
| CREDITS | + Crédits |
| HEALTH | + HP |
| AMMO | + Munitions |
| ENERGY | + Énergie |
| EXPERIENCE | + XP |
| KEY | Déverrouille portes |
| DATA_CHIP | Collectible |

**Factory**:
```gdscript
var pickup = Pickup.create_health(position, 50.0)
get_tree().current_scene.add_child(pickup)
```

---

### SpawnManager.gd
**Rôle**: Gestion des vagues d'ennemis

**Vagues prédéfinies**:
| Vague | Ennemis | Bonus |
|-------|---------|-------|
| 1 | 3 Robots | 50¥ |
| 2 | 3 Robots + 2 Drones | 100¥ |
| 3 | 4 Robots + 3 Drones + 1 Turret | 150¥ |
| 4 | Intensif | 200¥ |
| 5 | 2 Robots + BOSS | 500¥ |

**Utilisation**:
```gdscript
SpawnManager.start_waves()
SpawnManager.stop_spawning()
SpawnManager.spawn_at_point("SpawnPoint1", "drone")
```

---

### CraftingSystem.gd
**Rôle**: Système de fabrication

**Catégories de recettes**:
- Consumables (Health Kit, Stim Pack...)
- Ammo (Balles, Plasma, EMP)
- Upgrades (Puces dégâts/défense/vitesse)
- Hacking (Clés de hack)

**Utilisation**:
```gdscript
CraftingSystem.learn_recipe("emp_grenade")
if CraftingSystem.can_craft("health_kit"):
    CraftingSystem.craft("health_kit")
```

---

### RandomEventManager.gd
**Rôle**: Événements aléatoires en exploration

**Types d'événements**:
- AMBUSH - Embuscade
- MERCHANT - Vendeur ambulant
- LOOT_CACHE - Cache secrète
- DISTRESS_SIGNAL - Signal détresse
- GANG_WAR - Guerre gangs
- HACKER_OFFER - Job hacking
- DRONE_DROP - Crash drone
- STREET_FIGHT - Combat rue
- DATA_LEAK - Fuite données
- CORPO_PATROL - Patrouille corpo

---

## 🌍 Scripts World (`scripts/world/`)

### Door.gd
**Rôle**: Portes interactives

**Types de verrouillage**:
| Type | Déverrouillage |
|------|----------------|
| NONE | Libre |
| KEY | Clé spécifique |
| HACK | Mini-jeu hacking |
| SWITCH | Interrupteur externe |
| MISSION | Complétion mission |

---

## 💾 Scripts Systèmes (`scripts/systems/`)

### SaveManager.gd (Autoload)
**Rôle**: Sauvegarde/chargement

**Emplacement**: `user://saves/`

**Utilisation**:
```gdscript
SaveManager.save_game(0)  # Slot 0
SaveManager.load_game(0)
var info = SaveManager.get_save_info(0)
```

---

### StatsManager.gd (Autoload)
**Rôle**: Statistiques de jeu

**Stats suivies**:
- Kills, Damage dealt/taken
- Distance, Time played
- Items collected, Secrets found
- Zone stats

---

### InventoryManager.gd (Autoload)
**Rôle**: Gestion de l'inventaire

**Utilisation**:
```gdscript
InventoryManager.add_item("health_kit", 3)
InventoryManager.add_credits(100)
var count = InventoryManager.get_item_count("ammo_pistol")
```

---

## ♿ Scripts Accessibilité (`scripts/accessibility/`)

### AccessibilityManager.gd (Autoload)
**Rôle**: Configuration d'accessibilité

**Options**:
- High contrast mode
- Screen shake intensity
- TTS enabled/speed
- Subtitles
- Colorblind modes

---

### AudioTutorial.gd
**Rôle**: Tutoriel 100% audio

**11 étapes guidées**:
1. Introduction ARIA
2. Navigation audio
3. Mouvement
4. Suivi objectif par son
5. Attaque
6. Combos
7. Dash
8. Détection ennemis
9. Santé basse
10. Navigation menus
11. Conclusion

---

## 🔧 Scripts Composants (`scripts/components/`)

### HealthComponent.gd
**Attaché à**: Player, Ennemis

**Signaux**:
```gdscript
signal health_changed(current, max)
signal damage_taken(amount, source)
signal healed(amount)
signal died
```

**Utilisation**:
```gdscript
@onready var health = $HealthComponent
health.take_damage(25.0, attacker)
health.heal(50.0)
```

---

## 📱 Scripts Input (`scripts/input/`)

### HapticFeedback.gd (Autoload)
**Rôle**: Vibrations sur mobile

**Patterns**:
```gdscript
HapticFeedback.vibrate_light()   # Sélection UI
HapticFeedback.vibrate_medium()  # Hit
HapticFeedback.vibrate_heavy()   # Explosion
HapticFeedback.vibrate_pattern([50, 30, 50])  # Custom
```

---

## 📋 Conventions de Code

### Nommage

| Type | Convention | Exemple |
|------|------------|---------|
| Classes | PascalCase | `CombatManager` |
| Variables | snake_case | `current_health` |
| Constantes | SCREAMING_CASE | `MAX_COMBO` |
| Signaux | snake_case | `health_changed` |
| Privé | _prefix | `_internal_var` |

### Structure des Scripts

```gdscript
# ==============================================================================
# NomDuScript.gd - Description courte
# ==============================================================================

extends BaseClass
class_name NomDuScript

# Signaux
signal some_signal

# Énumérations
enum State { IDLE, ACTIVE }

# Variables exportées
@export var some_var: float = 1.0

# Variables d'état
var current_state: State = State.IDLE

# Références
@onready var some_node: Node = $SomeNode

# Fonctions Godot
func _ready() -> void:
    pass

func _process(delta: float) -> void:
    pass

# Méthodes publiques
func public_method() -> void:
    pass

# Méthodes privées
func _private_method() -> void:
    pass
```

---

*Documentation Scripts - Neon Protocol v0.1.0*
