// =============================================================================
// neon_glow.gdshader - Shader Néon Cyberpunk (Optimisé Mobile)
// Action-RPG Cyberpunk Low-Poly - Godot 4
// =============================================================================
// Unlit = Pas de calcul de lumière = RAPIDE
// Simule le bloom sans post-processing coûteux
// =============================================================================

shader_type spatial;

// Pas de lighting = performances maximales
render_mode unshaded, cull_disabled;

// =============================================================================
// PARAMÈTRES UNIFORMES (modifiables depuis GDScript)
// =============================================================================

group_uniforms NeonColor;
uniform vec3 neon_color : source_color = vec3(0.0, 1.0, 1.0);  // Cyan par défaut
uniform float emission_strength : hint_range(1.0, 10.0) = 3.0;  // Intensité émissive

group_uniforms GlowEffect;
uniform float glow_size : hint_range(0.0, 0.5) = 0.1;  // Taille du halo
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.5;  // Intensité du halo

group_uniforms Flicker;
uniform bool flicker_enabled = true;  // Activer le scintillement
uniform float flicker_speed : hint_range(0.1, 20.0) = 8.0;  // Vitesse de pulsation
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.3;  // Amplitude du flicker
uniform float flicker_randomness : hint_range(0.0, 1.0) = 0.5;  // Irrégularité

// Temps passé par le shader (uniform automatique Godot)
uniform float time_offset = 0.0;  // Décalage pour désynchroniser plusieurs néons

// =============================================================================
// FONCTIONS UTILITAIRES
// =============================================================================

// Pseudo-random basé sur les coordonnées (pas de texture = léger)
float random(float seed) {
	return fract(sin(seed * 12.9898) * 43758.5453);
}

// Calcul du flicker irrégulier
float calculate_flicker(float time) {
	if (!flicker_enabled) {
		return 1.0;
	}
	
	float t = time * flicker_speed + time_offset;
	
	// Onde de base (sinus)
	float base_wave = sin(t) * 0.5 + 0.5;
	
	// Ajout d'irrégularité avec des fréquences multiples
	float irregular = sin(t * 2.3) * 0.3 + sin(t * 5.7) * 0.2;
	irregular *= flicker_randomness;
	
	// Combiner et normaliser
	float flicker = base_wave + irregular;
	flicker = clamp(flicker, 0.0, 1.0);
	
	// Appliquer l'intensité (1.0 = pas de changement quand flicker_intensity = 0)
	return mix(1.0, flicker, flicker_intensity);
}

// =============================================================================
// VERTEX SHADER (optionnel : légère pulsation de taille)
// =============================================================================

void vertex() {
	// Optionnel : faire "respirer" le mesh avec le flicker
	// Décommenter si désiré (coût minimal)
	// float pulse = calculate_flicker(TIME) * 0.05;
	// VERTEX += NORMAL * pulse;
}

// =============================================================================
// FRAGMENT SHADER
// =============================================================================

void fragment() {
	// Calculer le facteur de flicker
	float flicker = calculate_flicker(TIME);
	
	// Couleur de base avec émission
	vec3 final_color = neon_color * emission_strength * flicker;
	
	// === FAKE GLOW (Simule le bloom sans post-process) ===
	// Utilise la distance au bord du fragment pour créer un halo
	// Plus le fragment est proche du bord UV, plus il est lumineux
	
	// Distance au centre des UVs (0.5, 0.5)
	vec2 center_uv = UV - vec2(0.5);
	float dist_from_center = length(center_uv) * 2.0;  // Normalisé 0-1
	
	// Créer un effet de glow sur les bords
	float edge_glow = smoothstep(1.0 - glow_size, 1.0, dist_from_center);
	final_color += neon_color * edge_glow * glow_intensity * flicker;
	
	// === OUTPUT ===
	ALBEDO = final_color;
	
	// Pas d'alpha pour la performance, mais peut être activé si nécessaire
	// ALPHA = 1.0;
}
