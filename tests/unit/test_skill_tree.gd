# ==============================================================================
# test_skill_tree.gd - Tests unitaires pour l'arbre de talents
# ==============================================================================

extends RefCounted

var runner: Node = null

func set_runner(r: Node) -> void:
	runner = r

# ==============================================================================
# TESTS
# ==============================================================================

func test_skill_tree_manager_exists() -> Dictionary:
	"""Vérifie que SkillTreeManager est un autoload."""
	var skill_tree = Engine.get_main_loop().root.get_node_or_null("/root/SkillTreeManager")
	return runner.assert_not_null(skill_tree, "SkillTreeManager autoload non trouvé")


func test_skill_tree_script_exists() -> Dictionary:
	"""Vérifie que le script SkillTreeManager existe."""
	var exists := ResourceLoader.exists("res://scripts/systems/SkillTreeManager.gd")
	return runner.assert_true(exists, "SkillTreeManager.gd n'existe pas")


func test_skill_tree_has_skills() -> Dictionary:
	"""Vérifie que SkillTreeManager a des compétences."""
	var skill_tree = Engine.get_main_loop().root.get_node_or_null("/root/SkillTreeManager")
	if not skill_tree:
		return {"passed": false, "message": "SkillTreeManager non trouvé"}
	
	if not "skills" in skill_tree:
		return {"passed": false, "message": "Propriété 'skills' manquante"}
	
	var has_skills := skill_tree.skills.size() > 0
	return runner.assert_true(has_skills, "Aucune compétence dans l'arbre")


func test_skill_tree_branches() -> Dictionary:
	"""Vérifie que les 4 branches existent."""
	var skill_tree = Engine.get_main_loop().root.get_node_or_null("/root/SkillTreeManager")
	if not skill_tree:
		return {"passed": false, "message": "SkillTreeManager non trouvé"}
	
	if not skill_tree.has_method("get_skills_by_branch"):
		return {"passed": false, "message": "Méthode get_skills_by_branch manquante"}
	
	var branches := ["combat", "hacking", "stealth", "survival"]
	for branch in branches:
		var skills = skill_tree.get_skills_by_branch(branch)
		if skills.size() == 0:
			return {"passed": false, "message": "Branche vide: " + branch}
	
	return {"passed": true}


func test_skill_tree_add_points() -> Dictionary:
	"""Vérifie la méthode add_skill_points."""
	var skill_tree = Engine.get_main_loop().root.get_node_or_null("/root/SkillTreeManager")
	if not skill_tree:
		return {"passed": false, "message": "SkillTreeManager non trouvé"}
	
	return runner.assert_has_method(skill_tree, "add_skill_points")


func test_skill_tree_can_unlock() -> Dictionary:
	"""Vérifie la méthode can_unlock_skill."""
	var skill_tree = Engine.get_main_loop().root.get_node_or_null("/root/SkillTreeManager")
	if not skill_tree:
		return {"passed": false, "message": "SkillTreeManager non trouvé"}
	
	return runner.assert_has_method(skill_tree, "can_unlock_skill")


func test_skill_tree_unlock_skill() -> Dictionary:
	"""Vérifie la méthode unlock_skill."""
	var skill_tree = Engine.get_main_loop().root.get_node_or_null("/root/SkillTreeManager")
	if not skill_tree:
		return {"passed": false, "message": "SkillTreeManager non trouvé"}
	
	return runner.assert_has_method(skill_tree, "unlock_skill")


func test_skill_tree_get_effect_total() -> Dictionary:
	"""Vérifie la méthode get_effect_total."""
	var skill_tree = Engine.get_main_loop().root.get_node_or_null("/root/SkillTreeManager")
	if not skill_tree:
		return {"passed": false, "message": "SkillTreeManager non trouvé"}
	
	return runner.assert_has_method(skill_tree, "get_effect_total")
