# 🏗️ Guide des Scènes - Neon Protocol

## Vue d'Ensemble

Ce guide explique comment configurer et utiliser les différentes scènes du projet.

---

## 📂 Structure des Scènes

```
scenes/
├── main/
│   └── Main.tscn           # Point d'entrée, menu principal
├── player/
│   └── Player.tscn         # Scène du joueur
├── enemies/
│   ├── SecurityRobot.tscn  # Robot de sécurité
│   └── [autres ennemis]
├── ui/
│   ├── HUD.tscn            # Interface en jeu
│   ├── PauseMenu.tscn      # Menu pause
│   └── VirtualJoystick.tscn # Joystick mobile
└── world/
    ├── CityBlock.tscn      # Niveau principal
    └── TutorialLevel.tscn  # Niveau tutoriel
```

---

## 🎭 Scène Player.tscn

### Hiérarchie

```
Player (CharacterBody3D)
├── CollisionShape3D
├── MeshPivot (Node3D)
│   └── MeshInstance3D      # Modèle joueur
├── Camera3D                # Caméra 3ème personne
├── HealthComponent
├── CombatManager
├── DashAbility
├── WeaponVisuals
└── PlayerAnimationController
```

### Configuration

1. **Ouvrir** `scenes/player/Player.tscn`
2. **Sélectionner** le nœud root `Player`
3. **Attacher le script** `scripts/player/Player.gd`

### Composants Requis

| Nœud | Script | Obligatoire |
|------|--------|-------------|
| Player | Player.gd | ✅ |
| HealthComponent | HealthComponent.gd | ✅ |
| CombatManager | CombatManager.gd | ✅ |
| DashAbility | DashAbility.gd | ✅ |

### Groupes

Le Player doit être dans le groupe `player`:
```
Player → Nœud → Groupes → Ajouter: "player"
```

### Collision Layers

```
Layer: 2 (Player)
Mask: 1, 3, 4 (World, Enemy, Interactable)
```

---

## 👾 Scène SecurityRobot.tscn

### Hiérarchie

```
SecurityRobot (CharacterBody3D)
├── CollisionShape3D
├── MeshPivot (Node3D)
│   └── MeshInstance3D
├── NavigationAgent3D
├── DetectionArea (Area3D)
├── HealthComponent
└── AudioStreamPlayer3D
```

### Configuration Waypoints

1. Créer des Node3D dans le niveau
2. Les ajouter au tableau `waypoints` dans l'inspecteur
3. L'ennemi patrouillera entre eux

### Variables Importantes

| Variable | Description | Défaut |
|----------|-------------|--------|
| detection_range | Portée de détection | 10.0 |
| attack_range | Portée d'attaque | 2.0 |
| patrol_speed | Vitesse patrouille | 3.0 |
| chase_speed | Vitesse poursuite | 5.0 |

### Groupes Requis

- `enemy` (obligatoire)
- `robot` (pour sons spécifiques)

---

## 🌆 Scène CityBlock.tscn

### Hiérarchie Recommandée

```
CityBlock (Node3D)
├── WorldEnvironment
├── DirectionalLight3D
├── NavigationRegion3D
│   └── [Géométrie du niveau]
├── Ground (StaticBody3D)
├── Buildings (Node3D)
│   └── [StaticBody3D pour chaque bâtiment]
├── SpawnPoints (Node3D)
│   ├── PlayerSpawn (Marker3D)
│   └── EnemySpawns (Node3D)
├── Interactables (Node3D)
│   └── [Portes, Terminaux...]
└── Lighting (Node3D)
    └── [OmniLight3D, SpotLight3D...]
```

### Configuration Navigation

1. **Sélectionner** `NavigationRegion3D`
2. **Créer** un `NavigationMesh` dans l'inspecteur
3. **Configurer**:
   - Agent Radius: 0.5
   - Agent Height: 2.0
   - Cell Size: 0.25
4. **Bake**: Clic droit → Rebake Navigation Mesh

### Spawn du Joueur

1. Créer un `Marker3D` nommé `PlayerSpawn`
2. Le positionner à l'entrée du niveau
3. Dans le script du niveau:
```gdscript
func _ready():
    var player_scene = preload("res://scenes/player/Player.tscn")
    var player = player_scene.instantiate()
    player.global_position = $SpawnPoints/PlayerSpawn.global_position
    add_child(player)
```

---

## 📱 Scène VirtualJoystick.tscn

### Configuration

```
VirtualJoystick (Control)
├── Background (TextureRect)
└── Knob (TextureRect)
```

### Script

Attacher `scripts/ui/SimpleJoystick.gd`

### Intégration dans HUD

1. Ouvrir `scenes/ui/HUD.tscn`
2. Ajouter `VirtualJoystick.tscn` en enfant
3. Positionner en bas à gauche

### Récupérer l'Input

```gdscript
var joystick = get_node_or_null("/root/CurrentScene/HUD/VirtualJoystick")
if joystick:
    var input = joystick.get_input()  # Vector2
    velocity.x = input.x * speed
    velocity.z = input.y * speed
```

---

## 🖥️ Scène HUD.tscn

### Hiérarchie Recommandée

```
HUD (CanvasLayer)
├── TopBar (HBoxContainer)
│   ├── HealthBar (ProgressBar)
│   └── CreditsLabel (Label)
├── LeftSide (VBoxContainer)
│   └── VirtualJoystick
├── RightSide (VBoxContainer)
│   ├── AttackButton (TouchScreenButton)
│   └── DashButton (TouchScreenButton)
├── Minimap (Control)
└── ObjectivePanel (PanelContainer)
```

### Connexion au Player

```gdscript
func _ready():
    var player = get_tree().get_first_node_in_group("player")
    if player and player.has_node("HealthComponent"):
        player.get_node("HealthComponent").health_changed.connect(_on_health_changed)

func _on_health_changed(current: float, max: float):
    $TopBar/HealthBar.value = (current / max) * 100
```

---

## 🎓 Scène TutorialLevel.tscn

### Zones de Tutoriel

```
TutorialLevel (Node3D)
├── [Environment...]
├── TutorialZones (Node3D)
│   ├── Zone1_Movement (Area3D)
│   ├── Zone2_Combat (Area3D)
│   ├── Zone3_Dash (Area3D)
│   └── Zone4_Interact (Area3D)
└── [EnemySpawns, Interactables...]
```

### Configuration des Zones

1. Créer une `Area3D` par zone
2. Ajouter un `CollisionShape3D` définissant la zone
3. Connecter le signal `body_entered`

### Script TutorialLevel.gd

Attacher `scripts/world/TutorialLevel.gd` au nœud root.

---

## 🔧 Création d'une Nouvelle Scène

### Niveau de Jeu

1. **Créer** `Scene → New Scene → Node3D`
2. **Renommer** en nom du niveau
3. **Ajouter**:
   - `WorldEnvironment`
   - `DirectionalLight3D`
   - `NavigationRegion3D`
4. **Configurer** l'environnement (ciel, fog, ambient)
5. **Placer** la géométrie dans NavigationRegion3D
6. **Bake** le navigation mesh
7. **Ajouter** spawn points
8. **Sauvegarder** dans `scenes/world/`

### Ennemi

1. **Créer** `Scene → New Scene → CharacterBody3D`
2. **Ajouter** `CollisionShape3D`, `NavigationAgent3D`
3. **Ajouter** `MeshInstance3D` pour le visuel
4. **Ajouter** `HealthComponent` (enfant)
5. **Attacher** le script approprié
6. **Ajouter** aux groupes (`enemy`, type spécifique)
7. **Sauvegarder** dans `scenes/enemies/`

### UI

1. **Créer** `Scene → New Scene → Control` (ou CanvasLayer)
2. **Designer** l'interface
3. **Attacher** le script UI
4. **Sauvegarder** dans `scenes/ui/`

---

## ⚙️ Paramètres d'Environnement

### WorldEnvironment Cyberpunk

```
WorldEnvironment:
  Environment:
    Background:
      Mode: Sky
      Sky:
        Material: ProceduralSkyMaterial
          Sky Top Color: #0a0a15
          Sky Horizon Color: #ff00ff (magenta)
          Ground Bottom Color: #000022
    
    Ambient Light:
      Source: Color
      Color: #1a1a2e
      Energy: 0.3
    
    Fog:
      Enabled: true
      Light Color: #0d0d1a
      Density: 0.01
```

### Éclairage Neon

Pour les lumières neon:
```
OmniLight3D:
  Color: #00ffff (cyan) ou #ff00ff (magenta)
  Energy: 2.0
  Range: 10.0
  Attenuation: 1.5
```

---

## 📝 Checklist Nouvelle Scène

- [ ] Type de nœud root approprié
- [ ] Collision shapes configurés
- [ ] Navigation mesh (si niveau)
- [ ] Scripts attachés
- [ ] Groupes assignés
- [ ] Collision layers/masks configurés
- [ ] Spawn points placés
- [ ] Test en standalone (F6)

---

*Guide des Scènes - Neon Protocol v0.1.0*
