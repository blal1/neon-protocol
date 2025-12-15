// ==============================================================================
// triplanar_procedural.gdshader - Triplanar Mapping Procédural
// ==============================================================================
// Évite les textures étirées sur géométrie procédurale.
// Essentiel pour la génération de monde.
// ==============================================================================

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// == TEXTURES ==
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_enable;

// == PROPERTIES ==
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;

// == TRIPLANAR ==
uniform float texture_scale : hint_range(0.1, 10.0) = 1.0;
uniform float blend_sharpness : hint_range(1.0, 10.0) = 3.0;

// Variation par position (anti-répétition)
uniform float variation_scale : hint_range(0.01, 1.0) = 0.1;
uniform float variation_amount : hint_range(0.0, 0.5) = 0.1;

// Wetness (pluie cyberpunk)
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform vec4 wet_color : source_color = vec4(0.1, 0.1, 0.15, 1.0);

// == FUNCTIONS ==
vec3 triplanar_blend(vec3 normal) {
    vec3 blend = abs(normal);
    blend = pow(blend, vec3(blend_sharpness));
    blend /= (blend.x + blend.y + blend.z);
    return blend;
}

vec4 triplanar_sample(sampler2D tex, vec3 pos, vec3 blend) {
    vec4 x = texture(tex, pos.zy * texture_scale);
    vec4 y = texture(tex, pos.xz * texture_scale);
    vec4 z = texture(tex, pos.xy * texture_scale);
    return x * blend.x + y * blend.y + z * blend.z;
}

vec3 triplanar_normal(sampler2D tex, vec3 pos, vec3 blend, vec3 world_normal) {
    vec3 tnormalX = texture(tex, pos.zy * texture_scale).rgb * 2.0 - 1.0;
    vec3 tnormalY = texture(tex, pos.xz * texture_scale).rgb * 2.0 - 1.0;
    vec3 tnormalZ = texture(tex, pos.xy * texture_scale).rgb * 2.0 - 1.0;
    
    // Reorient pour chaque axe
    tnormalX = vec3(tnormalX.xy + world_normal.zy, abs(tnormalX.z) * world_normal.x);
    tnormalY = vec3(tnormalY.xy + world_normal.xz, abs(tnormalY.z) * world_normal.y);
    tnormalZ = vec3(tnormalZ.xy + world_normal.xy, abs(tnormalZ.z) * world_normal.z);
    
    return normalize(tnormalX.zyx * blend.x + tnormalY.xzy * blend.y + tnormalZ.xyz * blend.z);
}

// == VARYING ==
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    // Triplanar blend weights
    vec3 blend = triplanar_blend(world_normal);
    
    // Position avec variation
    vec3 sample_pos = world_position;
    float variation = sin(world_position.x * variation_scale) * 
                      cos(world_position.z * variation_scale) * 
                      variation_amount;
    sample_pos += vec3(variation);
    
    // Sample textures
    vec4 albedo_sample = triplanar_sample(albedo_texture, sample_pos, blend);
    vec3 normal_sample = triplanar_normal(normal_texture, sample_pos, blend, world_normal);
    float roughness_sample = triplanar_sample(roughness_texture, sample_pos, blend).r;
    float ao_sample = triplanar_sample(ao_texture, sample_pos, blend).r;
    
    // Albedo avec couleur
    vec3 final_albedo = albedo_sample.rgb * albedo_color.rgb;
    
    // Wetness (pour la pluie)
    if (wetness > 0.0) {
        // Surface mouillée = plus sombre et réfléchissante
        final_albedo = mix(final_albedo, final_albedo * wet_color.rgb, wetness);
        roughness_sample = mix(roughness_sample, roughness_sample * 0.3, wetness);
    }
    
    // Output
    ALBEDO = final_albedo;
    ROUGHNESS = roughness_sample * roughness;
    METALLIC = metallic;
    NORMAL_MAP = normal_sample * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = normal_strength;
    AO = mix(1.0, ao_sample, ao_strength);
}
