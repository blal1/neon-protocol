# Contributing to Neon Protocol

Merci de votre intérêt pour contribuer à **Neon Protocol** ! 🎮

## 📋 Table des Matières

- [Code de Conduite](#code-de-conduite)
- [Comment Contribuer](#comment-contribuer)
- [Style de Code](#style-de-code)
- [Process de Pull Request](#process-de-pull-request)
- [Rapporter des Bugs](#rapporter-des-bugs)
- [Proposer des Features](#proposer-des-features)

---

## 📜 Code de Conduite

Ce projet adhère à un Code de Conduite. En participant, vous vous engagez à maintenir un environnement respectueux et inclusif.

**Règles principales:**
- Soyez respectueux et inclusif
- Pas de harcèlement ni discrimination
- Acceptez les critiques constructives
- Focus sur ce qui est le mieux pour la communauté

---

## 🤝 Comment Contribuer

### 1. Fork & Clone

```bash
# Fork via GitHub, puis:
git clone https://github.com/VOTRE-USERNAME/neon-protocol.git
cd neon-protocol
git remote add upstream https://github.com/ORIGINAL/neon-protocol.git
```

### 2. Créer une Branche

```bash
# Pour une feature
git checkout -b feature/ma-super-feature

# Pour un bugfix
git checkout -b fix/correction-bug

# Pour la documentation
git checkout -b docs/update-readme
```

### 3. Développer

- Faites vos modifications
- Testez localement dans Godot
- Vérifiez qu'il n'y a pas d'erreurs: `godot --headless --import`

### 4. Commit

```bash
git add .
git commit -m "feat: description courte de la feature"
```

**Convention de commits:**
- `feat:` nouvelle fonctionnalité
- `fix:` correction de bug
- `docs:` documentation
- `style:` formatage (pas de changement de code)
- `refactor:` refactoring
- `test:` ajout/modification de tests
- `chore:` maintenance

### 5. Push & PR

```bash
git push origin feature/ma-super-feature
```

Puis créez une Pull Request sur GitHub.

---

## 💻 Style de Code

### GDScript

Suivez le [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) officiel.

```gdscript
# ✅ BON
class_name MyClass
extends Node

signal my_signal(value: int)

@export var my_variable: int = 0

var _private_var: String = ""

func my_function(param: String) -> bool:
    if param.is_empty():
        return false
    return true


# ❌ MAUVAIS
class_name myclass
extends Node

var myVariable = 0

func myFunction(param):
    if param == "":
        return false
    return true
```

### Conventions de Nommage

| Type | Style | Exemple |
|------|-------|---------|
| Classes | PascalCase | `PlayerController` |
| Fonctions | snake_case | `calculate_damage()` |
| Variables | snake_case | `player_health` |
| Constantes | SCREAMING_SNAKE | `MAX_SPEED` |
| Signaux | snake_case | `health_changed` |
| Privés | _prefix | `_internal_state` |

### Documentation

```gdscript
## Description de la classe.
## Peut être sur plusieurs lignes.
class_name DamageCalculator

## Calcule les dégâts finaux.
## @param base_damage: Dégâts de base.
## @param armor: Valeur d'armure de la cible.
## @return: Dégâts finaux après réduction.
func calculate(base_damage: float, armor: float) -> float:
    return base_damage * (100.0 / (100.0 + armor))
```

---

## 🔀 Process de Pull Request

### Checklist avant PR

- [ ] Le code compile sans erreurs
- [ ] Les noms suivent les conventions
- [ ] Les fonctions sont documentées
- [ ] Pas de code commenté inutile
- [ ] Testé dans Godot

### Template de PR

```markdown
## Description
Courte description des changements.

## Type de changement
- [ ] Bug fix
- [ ] Nouvelle feature
- [ ] Breaking change
- [ ] Documentation

## Tests effectués
Décrivez les tests réalisés.

## Screenshots (si UI)
Ajoutez des captures si pertinent.
```

### Review

- Au moins 1 review approuvée requise
- Tous les commentaires doivent être résolus
- CI/CD doit passer (si configuré)

---

## 🐛 Rapporter des Bugs

Utilisez le template d'issue **Bug Report**:

```markdown
**Description**
Description claire du bug.

**Pour Reproduire**
1. Aller à '...'
2. Cliquer sur '...'
3. Le bug apparaît

**Comportement Attendu**
Ce qui devrait se passer.

**Screenshots**
Si applicable.

**Environnement**
- OS: [Windows/Linux/macOS/Android/iOS]
- Godot: [version]
- Neon Protocol: [version]
```

---

## 💡 Proposer des Features

Utilisez le template d'issue **Feature Request**:

```markdown
**Problème à résoudre**
Quel problème cette feature résout-elle?

**Solution proposée**
Description de la solution.

**Alternatives considérées**
Autres approches possibles.

**Contexte additionnel**
Toute autre information.
```

---

## 📁 Structure du Projet

Pour contribuer efficacement, familiarisez-vous avec la structure:

```
scripts/
├── accessibility/   # Systèmes d'accessibilité
├── audio/           # Audio et TTS
├── combat/          # Système de combat
├── gameplay/        # Mécaniques de jeu
├── systems/         # Systèmes core (save, inventory)
├── ui/              # Interface utilisateur
└── world/           # Génération du monde
```

---

## 🎯 Priorités Actuelles

Consultez les [Issues](../../issues) avec les labels:

- `good first issue` — Parfait pour débuter
- `help wanted` — Besoin d'aide
- `priority: high` — Important pour la release

---

## 📧 Contact

- **Issues GitHub** — Pour bugs et features
- **Discussions GitHub** — Pour questions générales

---

Merci de contribuer à **Neon Protocol**! 🌆💜
