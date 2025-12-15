// ==============================================================================
// wet_surface.gdshader - Surfaces Mouillées (Pluie Cyberpunk)
// ==============================================================================
// Béton/métal mouillé avec réflexions, puddlés, et variation.
// ==============================================================================

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// == TEXTURES ==
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D puddle_mask : hint_default_black, filter_linear_mipmap, repeat_enable;

// == BASE PROPERTIES ==
uniform vec4 albedo_color : source_color = vec4(0.3, 0.3, 0.35, 1.0);
uniform float base_roughness : hint_range(0.0, 1.0) = 0.8;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.0;

// == WETNESS ==
uniform float wetness : hint_range(0.0, 1.0) = 0.5;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.3;
uniform float puddle_roughness : hint_range(0.0, 0.3) = 0.05;
uniform vec4 water_tint : source_color = vec4(0.02, 0.02, 0.05, 1.0);

// == RIPPLES ==
uniform bool ripples_enabled = true;
uniform float ripple_density : hint_range(1.0, 20.0) = 8.0;
uniform float ripple_speed : hint_range(0.1, 3.0) = 1.0;
uniform float ripple_intensity : hint_range(0.0, 0.5) = 0.15;

// == REFLECTIONS ==
uniform samplerCube environment_map : hint_default_black;
uniform float reflection_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float reflection_blur : hint_range(0.0, 1.0) = 0.3;

// == NEON REFLECTIONS ==
uniform bool neon_reflections = true;
uniform vec4 neon_color_1 : source_color = vec4(1.0, 0.2, 0.6, 1.0);
uniform vec4 neon_color_2 : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float neon_reflection_intensity : hint_range(0.0, 1.0) = 0.3;

// == FUNCTIONS ==
float random2d(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 ripple(vec2 uv, float time) {
    vec2 center = vec2(0.5);
    float dist = length(uv - center);
    float ripple = sin(dist * ripple_density * 3.14159 * 2.0 - time * ripple_speed * 3.0);
    ripple *= exp(-dist * 5.0);
    return vec2(ripple) * ripple_intensity;
}

// == VARYING ==
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 view_direction;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    view_direction = normalize(CAMERA_POSITION_WORLD - world_position);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME;
    
    // Sample base textures
    vec4 albedo_sample = texture(albedo_texture, uv);
    vec3 normal_sample = texture(normal_texture, uv).rgb * 2.0 - 1.0;
    float roughness_sample = texture(roughness_texture, uv).r;
    float puddle_mask_sample = texture(puddle_mask, uv).r;
    
    // Calculate puddle areas (low areas accumulate water)
    float in_puddle = smoothstep(0.5 - puddle_amount * 0.5, 0.5 + puddle_amount * 0.5, puddle_mask_sample);
    in_puddle *= wetness;
    
    // Wetness effect on regular surface
    float surface_wetness = wetness * (1.0 - in_puddle * 0.5);
    
    // == ALBEDO ==
    vec3 base_color = albedo_sample.rgb * albedo_color.rgb;
    
    // Wet surfaces are darker
    base_color *= (1.0 - surface_wetness * 0.3);
    
    // Puddles are very dark (showing reflections instead)
    base_color = mix(base_color, water_tint.rgb, in_puddle * 0.8);
    
    // == ROUGHNESS ==
    float final_roughness = roughness_sample * base_roughness;
    
    // Wet surfaces are smoother
    final_roughness *= (1.0 - surface_wetness * 0.5);
    
    // Puddles are very smooth
    final_roughness = mix(final_roughness, puddle_roughness, in_puddle);
    
    // == NORMALS ==
    vec3 final_normal = normal_sample;
    
    // Flatten normals in puddles (water is flat)
    final_normal = mix(final_normal, vec3(0.0, 0.0, 1.0), in_puddle * 0.8);
    
    // Add ripples in puddles
    if (ripples_enabled && in_puddle > 0.1) {
        // Multiple ripple sources
        vec2 ripple1 = ripple(uv + vec2(0.0, time * 0.02), time);
        vec2 ripple2 = ripple(uv * 1.3 + vec2(0.5, 0.3), time * 1.2);
        vec2 ripple3 = ripple(uv * 0.7 + vec2(0.2, 0.8), time * 0.8);
        
        vec2 total_ripple = (ripple1 + ripple2 + ripple3) / 3.0;
        total_ripple *= in_puddle;
        
        final_normal.xy += total_ripple;
        final_normal = normalize(final_normal);
    }
    
    // == REFLECTIONS ==
    vec3 reflection_color = vec3(0.0);
    
    if (wetness > 0.0) {
        // Fresnel pour les réflexions
        float fresnel = pow(1.0 - max(0.0, dot(world_normal, view_direction)), 3.0);
        fresnel = mix(0.04, 1.0, fresnel);
        
        // Environment reflection
        vec3 reflect_dir = reflect(-view_direction, world_normal);
        vec3 env_reflection = textureLod(environment_map, reflect_dir, reflection_blur * 5.0).rgb;
        
        // Neon reflections (fake, but effective)
        if (neon_reflections) {
            float neon_pattern = sin(world_position.x * 0.5) * cos(world_position.z * 0.3);
            neon_pattern = (neon_pattern * 0.5 + 0.5);
            
            vec3 neon = mix(neon_color_1.rgb, neon_color_2.rgb, neon_pattern);
            neon *= sin(world_position.x * 2.0 + time) * 0.5 + 0.5;
            
            env_reflection += neon * neon_reflection_intensity;
        }
        
        reflection_color = env_reflection * fresnel * reflection_intensity * wetness;
        
        // Stronger reflections in puddles
        reflection_color *= (1.0 + in_puddle * 1.5);
    }
    
    // == OUTPUT ==
    ALBEDO = base_color + reflection_color;
    ROUGHNESS = final_roughness;
    METALLIC = mix(base_metallic, 0.0, in_puddle);
    NORMAL_MAP = final_normal * 0.5 + 0.5;
    
    // Slight emission from neon reflections
    EMISSION = reflection_color * 0.3;
}
