// ==============================================================================
// cyberpunk_hologram.gdshader - Shader Hologramme Cyberpunk
// ==============================================================================
// Effet holographique avec scanlines, glitch, et transparence.
// Usage: Panneaux d'affichage, PNJ hologrammes, UI monde.
// ==============================================================================

shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

// == UNIFORMS ==
uniform vec4 hologram_color : source_color = vec4(0.2, 0.8, 1.0, 0.7);
uniform float intensity : hint_range(0.5, 3.0) = 1.5;
uniform float scanline_density : hint_range(10.0, 200.0) = 80.0;
uniform float scanline_speed : hint_range(0.0, 5.0) = 1.0;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float glitch_speed : hint_range(0.1, 5.0) = 2.0;
uniform float edge_fade : hint_range(0.0, 1.0) = 0.5;
uniform float flicker_speed : hint_range(1.0, 20.0) = 10.0;
uniform float flicker_amount : hint_range(0.0, 0.5) = 0.1;
uniform sampler2D noise_texture : hint_default_white;

// == RANDOM ==
float random(float x) {
    return fract(sin(x * 12.9898) * 43758.5453);
}

float random2d(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// == VERTEX ==
void vertex() {
    // Glitch vertex displacement
    float time = TIME * glitch_speed;
    float glitch = step(0.95, random(floor(time * 10.0)));
    
    if (glitch > 0.5) {
        float offset = random(floor(time * 20.0)) * glitch_intensity * 0.1;
        VERTEX.x += offset * sign(random(VERTEX.y) - 0.5);
    }
}

// == FRAGMENT ==
void fragment() {
    // Base fresnel pour effet de bord
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 2.0);
    fresnel = mix(edge_fade, 1.0, fresnel);
    
    // Scanlines
    float scanline = sin((SCREEN_UV.y + TIME * scanline_speed * 0.1) * scanline_density);
    scanline = (scanline * 0.5 + 0.5) * 0.3 + 0.7;
    
    // Glitch horizontal
    float time = TIME * glitch_speed;
    float glitch_line = step(0.98, random(floor(UV.y * 20.0 + time)));
    float glitch_offset = (random(floor(time * 30.0)) - 0.5) * glitch_intensity * glitch_line;
    
    // Appliquer le glitch à l'UV
    vec2 glitched_uv = UV;
    glitched_uv.x += glitch_offset;
    
    // Flicker
    float flicker = 1.0 - flicker_amount + flicker_amount * sin(TIME * flicker_speed);
    
    // Couleur finale
    vec3 color = hologram_color.rgb * intensity;
    
    // Appliquer les effets
    color *= scanline;
    color *= fresnel;
    color *= flicker;
    
    // RGB split sur glitch
    if (abs(glitch_offset) > 0.01) {
        float split = 0.01;
        color.r = hologram_color.r * intensity * 1.2;
        color.g = hologram_color.g * intensity * 0.8;
    }
    
    ALBEDO = color;
    ALPHA = hologram_color.a * fresnel * scanline;
    
    // Emission pour le glow
    EMISSION = color * 0.5;
}
