shader_type canvas_item;

// Procedural eye used by the compact pupil panel.

uniform bool beam_only = false;
uniform vec4 beam_color : source_color = vec4(1.0, 0.98, 0.90, 1.0);
uniform float radius_normalized : hint_range(0.05, 0.5) = 0.42;
uniform float core_brightness : hint_range(0.0, 2.0) = 1.0;
uniform float pupil_scale : hint_range(0.15, 0.85) = 0.45;
uniform float sclera_redness : hint_range(0.0, 1.0) = 0.0;
uniform float eye_aspect = 1.45;
uniform vec2 light_pos = vec2(0.5, 0.5);
uniform float light_intensity = 1.0;
uniform float light_beam_radius = 0.35;
uniform bool light_on = true;
uniform float ambient_light : hint_range(0.0, 1.0) = 0.425;
uniform float squint : hint_range(0.0, 1.0) = 0.0;
uniform float blink : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	if (beam_only) {
		vec2 beam_position = UV - vec2(0.5);
		float beam_distance = length(beam_position);
		float falloff = pow(smoothstep(radius_normalized, 0.0, beam_distance), 1.8);
		float hotspot = smoothstep(radius_normalized * 0.25, 0.0, beam_distance) * 0.6;
		float alpha = (falloff * core_brightness + hotspot) * 0.55;
		COLOR = vec4(beam_color.rgb, clamp(alpha, 0.0, 0.7));
	} else {
		vec2 p = UV - vec2(0.5);
		float eye_distance = length(p * vec2(1.0, 1.25));
		float pupil_distance = length((UV - vec2(0.5)) * vec2(eye_aspect, 1.0));
		float pupil_radius = 0.40 * clamp(pupil_scale, 0.12, 0.88);

		float redness = pow(clamp(sclera_redness, 0.0, 1.0), 0.65);
		vec3 sclera = mix(vec3(0.96, 0.95, 0.91), vec3(0.78, 0.025, 0.02), redness);
		float eyeball_shading = 1.0 - smoothstep(0.0, 0.52, eye_distance);
		sclera *= 0.84 + 0.16 * eyeball_shading;

		float iris_radius = pupil_radius + 0.045;
		float iris_mask = 1.0 - smoothstep(iris_radius - 0.008, iris_radius + 0.008, pupil_distance);
		float pupil_mask = 1.0 - smoothstep(pupil_radius - 0.005, pupil_radius + 0.005, pupil_distance);
		vec3 iris = mix(vec3(0.27, 0.16, 0.09), vec3(0.47, 0.30, 0.16), clamp(pupil_distance / max(iris_radius, 0.001), 0.0, 1.0));
		vec3 eye_color = mix(sclera, iris, iris_mask);
		eye_color = mix(eye_color, vec3(0.008, 0.009, 0.012), pupil_mask);

		float ambient = clamp(ambient_light, 0.08, 1.0);
		vec3 lit_color = eye_color * ambient;
		if (light_on) {
			vec2 light_delta = (UV - light_pos) * vec2(eye_aspect, 1.0);
			float falloff = pow(smoothstep(light_beam_radius, 0.0, length(light_delta)), 1.4);
			lit_color += eye_color * falloff * light_intensity * 0.85;
		}
		float redness_contrast = redness * 0.45;
		lit_color *= mix(vec3(1.0), vec3(1.0, 0.42, 0.38), redness_contrast);

		float upper_lid_y = 0.38 - (squint * 0.16) - (blink * 0.42) - (p.x * p.x) * 0.9;
		float lower_lid_y = -0.38 + (squint * 0.14) + (blink * 0.42) + (p.x * p.x) * 0.8;
		float upper_edge = smoothstep(upper_lid_y - 0.015, upper_lid_y, p.y);
		float lower_edge = smoothstep(lower_lid_y + 0.015, lower_lid_y, p.y);
		float lid_cut = max(upper_edge, lower_edge);
		float outer_mask = smoothstep(0.50, 0.48, eye_distance);
		float visible_mask = (1.0 - lid_cut) * outer_mask;
		vec3 skin = vec3(0.20, 0.14, 0.12) * ambient;
		float lash_shadow = smoothstep(upper_lid_y, upper_lid_y - 0.08, p.y);
		lit_color *= 1.0 - lash_shadow * 0.35;

		COLOR = vec4(mix(skin, lit_color, visible_mask), 1.0);
	}
}
