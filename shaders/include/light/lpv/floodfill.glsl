#if !defined INCLUDE_LIGHT_LPV_FLOODFILL
#define INCLUDE_LIGHT_LPV_FLOODFILL

#include "voxelization.glsl"

bool is_emitter(uint block_id) {
	return (32u <= block_id && block_id < 47u) || (47u < block_id && block_id < 64u);
}

bool is_red_components(uint block_id) {
	return block_id == 47u;
}

bool is_translucent(uint block_id) {
	return 64u <= block_id && block_id < 80u;
}

float redColor(ivec3 pos, float aa, float bb, float cc) {
    float phase = 600.0 * sunAngle + 0.1 * float(aa * pos.x + bb * pos.y + cc * pos.z);
    return clamp(2.0 * sin(phase) + 0.5, 0.0, 1.0);
}

float greenColor(ivec3 pos, float aa, float bb, float cc) {
    float phase = 600.0 * sunAngle - 79.9999999 + 0.1 * float(aa * pos.x + bb * pos.y + cc * pos.z);
    return clamp(2.0 * sin(phase) + 0.5, 0.0, 1.0);
}

float blueColor(ivec3 pos, float aa, float bb, float cc) {
    float phase = 600.0 * sunAngle - 39.9999999 + 0.1 * float(aa * pos.x + bb * pos.y + cc * pos.z);
    return clamp(2.0 * sin(phase) + 0.5, 0.0, 1.0);
}

vec3 get_emitted_light(uint block_id, ivec3 pos) {
	if (is_red_components(block_id)) {
		int MODE_COUNT = 5;
        int SHOW_TIMES = 40;
        float cyclePosition = sunAngle * float(SHOW_TIMES);
        int currentMode = int(floor(cyclePosition)) % MODE_COUNT;
        
        float aa, bb, cc;
        if (currentMode == 0) {
            aa = 0.0;
            bb = 0.0;
            cc = 0.0;
        } else if (currentMode == 1) {
            aa = 1.0;
            bb = -0.5;
            cc = 0.0;
        } else if (currentMode == 2) {
            aa = 1.0;
            bb = -0.1;
            cc = 0.0;
        } else if (currentMode == 3) {
            aa = 0.0;
            bb = 0.0;
            cc = 1.0;
        } else {
			aa = 0.0;
            bb = 1.0;
            cc = 1.0;
		}
    	float r = redColor(pos, aa, bb, cc);
    	float g = greenColor(pos, aa, bb, cc);
    	float b = blueColor(pos, aa, bb, cc);
		vec3 RC;
		if (Scene_pos.z < 100.0) {
			RC = vec3(g, r, b);
		} else {
			RC = vec3(r, g, b);
		}
		RC *= 0.8;
		return RC * (sunAngle > 0.478 && sunAngle < 1.0 ? 8.0 : 0.0);
	} 
        else if (is_emitter(block_id)) {
		return vec3(0.0);//texelFetch(light_data_sampler, ivec2(int(block_id) - 32, 0), 0).rgb;
	} else {
		return vec3(0.0);
	}
}

vec3 get_tint(uint block_id, bool is_transparent) {
	if (is_translucent(block_id)) {
		return texelFetch(light_data_sampler, ivec2(int(block_id) - 64, 1), 0).rgb;
	} else {
		return vec3(is_transparent);
	}
}

ivec3 clamp_to_voxel_volume(ivec3 pos) {
	return pos;//clamp(pos, ivec3(0), voxel_volume_size - 1);
}

vec3 gather_light(sampler3D light_sampler, ivec3 pos) {
	const ivec3[6] face_offsets = ivec3[6](
		ivec3( 1,  0,  0),
		ivec3( 0,  1,  0),
		ivec3( 0,  0,  1),
		ivec3(-1,  0,  0),
		ivec3( 0, -1,  0),
		ivec3( 0,  0, -1)
	);

	return texelFetch(light_sampler, pos, 0).rgb +
	       texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[0]), 0).xyz +
	       texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[1]), 0).xyz +
	       texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[2]), 0).xyz +
	       texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[3]), 0).xyz +
	       texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[4]), 0).xyz +
	       texelFetch(light_sampler, clamp_to_voxel_volume(pos + face_offsets[5]), 0).xyz;
}


void update_lpv(writeonly image3D light_img, sampler3D light_sampler) {
	ivec3 pos = ivec3(gl_GlobalInvocationID);
	
	ivec3 previous_pos = ivec3(vec3(pos) - floor(previousCameraPosition) + floor(cameraPosition));

	uint block_id       = texelFetch(voxel_sampler, pos, 0).x;
	bool transparent    = block_id == 0u || block_id >= 128u;
	block_id            = block_id & 127;
	vec3 light_avg      = gather_light(light_sampler, previous_pos) * rcp(7.0);
	vec3 emitted_light  = sqr(get_emitted_light(block_id, pos));
	vec3 tint           = sqr(get_tint(block_id, transparent));

	vec3 light = emitted_light + light_avg * tint;

	imageStore(light_img, pos, vec4(light, 0.0));
}

#endif // INCLUDE_LIGHT_LPV_FLOODFILL