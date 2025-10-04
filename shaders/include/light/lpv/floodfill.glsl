#if !defined INCLUDE_LIGHT_LPV_FLOODFILL
#define INCLUDE_LIGHT_LPV_FLOODFILL

#include "voxelization.glsl"

vec3 CobblestoneColors[3] = vec3[](
    vec3(0.85, 0.50, 0.20),
    vec3(0.65, 0.30, 0.70),
    vec3(0.15, 0.60, 0.65)
);

/**************************************
*
* 判断函数
*
**************************************/


bool is_emitter(uint block_id) {
    return (32u <= block_id && block_id < 64u) && block_id != 47u && block_id != 54u;
}

bool is_red_components(uint block_id) {
	return block_id == 47u;
}

bool is_enchanting_table(uint block_id) {
	return block_id == 54u;
}

bool is_translucent(uint block_id) {
	return 64u <= block_id && block_id < 80u;
}

/**************************************
*
* 辅助函数
*
**************************************/

vec3 lab_to_lms(vec3 lab) {
    float L = lab.x;
    float a = lab.y;
    float b = lab.z;
    
    float l_ = L + 0.3963377774 * a + 0.2158037573 * b;
    float m_ = L - 0.1055613458 * a - 0.0638541728 * b;
    float s_ = L - 0.0894841775 * a - 1.2914855480 * b;
    
    return vec3(l_, m_, s_);
}

vec3 lms_to_linear_srgb(vec3 lms) {
    float l = lms.x;
    float m = lms.y;
    float s = lms.z;
    
    float r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    float g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    float b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
    
    return vec3(r, g, b);
}

vec3 OKLabToRGB(vec3 lab) {
    vec3 lms = lab_to_lms(lab);
    lms = lms * lms * lms; // cubic root approximation
    vec3 linear_srgb = lms_to_linear_srgb(lms);
    return clamp(linear_srgb, 0.0, 1.0);
}

vec3 colorGradient(vec3 colors[3], int colorCount, float sunAngle) {
    float t = fract(sunAngle);
    
    float segment = t * float(colorCount);
    int index = int(floor(segment));
    float blend = fract(segment);
    
    vec3 c1 = colors[index % colorCount];
    vec3 c2 = colors[(index + 1) % colorCount];
    
    return mix(c1, c2, blend);
}

/**************************************
*
* 效果函数
*
**************************************/

vec3 gradientEffect(vec3 pos, float aa, float bb, float cc) {
    float redPhase = 600.0 * sunAngle + 0.1 * (aa * pos.x + bb * pos.y + cc * pos.z);
    float red = clamp(2.0 * sin(redPhase) + 0.2, 0.0, 1.0);
    
    float greenPhase = 600.0 * sunAngle - 79.9999999 + 0.1 * (aa * pos.x + bb * pos.y + cc * pos.z);
    float green = clamp(2.0 * sin(greenPhase) + 0.2, 0.0, 1.0);
    
    float bluePhase = 600.0 * sunAngle - 39.9999999 + 0.1 * (aa * pos.x + bb * pos.y + cc * pos.z);
    float blue = clamp(2.0 * sin(bluePhase) + 0.2, 0.0, 1.0);
    
    return vec3(red, green, blue);
}

vec3 rainbowDiskEffect(vec3 pos) {
    float angle = atan(pos.z, pos.x);
    float normalizedAngle = (angle + 3.141592653589793) / 6.283185307179586;
    
    float yPhase = pos.y * -0.003;
    float cycles = 2.0;
    float rotationSpeed = -150.0;
    
    float hue = mod(normalizedAngle * cycles + yPhase + sunAngle * rotationSpeed + 1.0, 1.0);

    float lightness = 0.9;
    float chroma = 0.4;
    
    vec3 lab = vec3(
        lightness,
        chroma * cos(hue * 6.283185307179586),
        chroma * sin(hue * 6.283185307179586)
    );
    
    return clamp(OKLabToRGB(lab), 0.0, 1.0);
}

vec3 ribbonEffect(vec3 pos) {
    float baseHue = sunAngle;

    float layerRotation = pos.y * 0.05;

    float angle = atan(pos.z, pos.x);
    float rotatedAngle = angle + layerRotation;
    float normalizedAngle = (rotatedAngle + 3.141592653589793) / 6.283185307179586;

    int sector = int(floor(normalizedAngle * 2.0)) % 2;

    float color1Hue = baseHue;
    float color2Hue = mod(baseHue + 0.5, 1.0); // Complementary color

    float wave = round(sin(pos.y * 0.008 + sunAngle * -1000.0));
    float brightness = wave > 0.5 ? 1.0 : 0.0;

    // Assign color and brightness based on sector
    float hue, lightness;
    if (sector == 0) {
        // Fixed brightness area
        hue = color1Hue;
        lightness = 0.8;
    } else {
        // Dynamic brightness area
        hue = color2Hue;
        lightness = brightness;
    }

    // Generate color using OKLab color space
    float chroma = 0.4;
    vec3 lab = vec3(
        lightness,
        chroma * cos(hue * 6.283185307179586),
        chroma * sin(hue * 6.283185307179586)
    );

    // Convert to RGB
    vec3 rgb = OKLabToRGB(lab);
    return clamp(rgb, 0.0, 1.0);
}

vec3 rainbowCylinder(vec3 pos) {
    // 计算点在x-z平面上的角度（0到2π）
    float PI = 3.141592653589793;
    float baseAngle = atan(pos.z, pos.x);

    // 添加y坐标的扭转效果 - 每单位y值扭转的角度
    float twistFactor = -0.005; // 可以调整这个值来控制螺旋的紧密程度
    float rotationSpeed = -150.0;
    float twistedAngle = baseAngle + pos.y * twistFactor + sunAngle;

    float normalizedAngle = (twistedAngle + PI) / (2.0 * PI); // 归一化到[0,1]
    
    // 彩虹色谱：红->橙->黄->绿->青->蓝->紫->红
    // 使用6段线性插值来模拟彩虹
    vec3 red = vec3(1.0, 0.0, 0.0);
    vec3 orange = vec3(1.0, 0.5, 0.0);
    vec3 yellow = vec3(1.0, 1.0, 0.0);
    vec3 green = vec3(0.0, 1.0, 0.0);
    vec3 cyan = vec3(0.0, 1.0, 1.0);
    vec3 blue = vec3(0.0, 0.0, 1.0);
    vec3 purple = vec3(0.5, 0.0, 1.0);

    // 将归一化角度映射到离散色块
    float segment = normalizedAngle * 7.0; // 7种颜色
    int segmentIndex = int(floor(segment));
    
    // 直接返回对应的颜色，没有混合
    if (segmentIndex == 0) {
        return red;
    } else if (segmentIndex == 1) {
        return orange;
    } else if (segmentIndex == 2) {
        return yellow;
    } else if (segmentIndex == 3) {
        return green;
    } else if (segmentIndex == 4) {
        return cyan;
    } else if (segmentIndex == 5) {
        return blue;
    } else {
        return purple;
    }
    
    // 混色示例代码，在本函数中不使用，仅供参考
    // 将归一化角度映射到彩虹色谱
    // float segment = normalizedAngle * 6.0;
    // int segmentIndex = int(floor(segment));
    // float t = fract(segment);
    // vec3 color;
    // if (segmentIndex == 0) {
    //     color = mix(red, orange, t);
    // }
    // return color;
}

vec3 twistedConeEffect(vec3 pos) {
    // Normalize position to similar scale as original shader
    vec2 uv = pos.xz * 0.01;
    float t = sunAngle * 120.0; // Map sunAngle to animation time
    
    vec4 color = vec4(0.0);
    
    // Raymarch parameters
    const int iterations = 50;
    float z = 0.0;
    
    for(int i = 0; i < iterations; i++) {
        // Raymarch sample position (adjusted for our coordinate system)
        vec3 p = z * normalize(vec3(uv, 0.0));
        
        // Shift back and animate (adjusted for our scale)
        p.z += 0.5 + cos(t);
        
        // Twist and rotate (using pos.y instead of original p.y)
        p.xz *= mat2(cos(pos.y * 0.02 + vec4(0, 33, 11, 0)));
        
        // Expand upward (modified for our coordinate system)
        p.xz /= max(pos.y * 0.01 + 1.0, 0.1);
        
        // Turbulence loop (increase frequency)
        float d;
        for(d = 2.0; d < 15.0; d /= 0.6) {
            // Add turbulence wave (using sunAngle for animation)
            p += cos((p.yzx - vec3(t/0.1, t, d)) * d) / d;
        }
        
        // Sample approximate distance to hollow cone
        float stepSize = 0.01 + abs(length(p.xz) + pos.y * 0.003 - 0.8) / 4.0;
        z += stepSize;
        
        // Add color and glow attenuation
        color += (sin(z / 15.0 + vec4(600.0 * sunAngle, 600.0 * sunAngle - 79.9999999, 600.0 * sunAngle - 39.9999999, 0)) + 1.0) / stepSize;
    }
    
    // Tanh tonemapping
    color = tanh(color / 1000.0);
    
    return color.rgb;
}

vec3 firewallEffect(vec3 pos) {
    // Normalize position and setup time
    vec2 uv = pos.xz * 0.01;
    float t = sunAngle * 150.0; // Map sunAngle to animation time
    
    vec4 color = vec4(0.0);
    float z = 0.0;
    const float iterations = 20.0; // Reduced from original 100 for performance
    
    for(float i = 0.0; i < iterations; i += 1.0) {
        // Sample point (adjusted for our coordinate system)
        vec3 p = z * normalize(vec3(uv, 0.0)) + 0.1;
        
        // Polar coordinates and transformations (modified for our scale)
        p = vec3(
            atan(p.z + 0.9, p.x + 0.1) * 2.0,  // Angular component
            0.6 * p.y + t * 2.0,               // Vertical component with animation
            length(p.xz) - 0.3                 // Radial component
        );
        
        // Apply turbulence and refraction effect
        float d;
        for(d = 0.0; d++ < 7.0;) {
            p += sin(p.yzx * d + t + 0.5 * float(i)) / d;
        }
        
        // Distance estimation with refraction waves
        float stepSize = 0.05 * length(vec4(4.5 * cos(p) - 1.0, p.z));
        z += stepSize;
        
        // Coloring with bright flame-like colors
        color += (0.8 + cos(p.y + i * 0.4 + vec4(3, 0, -3, 0))) / stepSize;
    }
    
    // Enhanced tanh tonemapping (squared for more contrast)
    color = tanh(color * color / 6000.0);
    
    return color.rgb;
}

vec3 sineWaveEffect(vec3 pos) {
    // Normalize position to similar scale as original shader
    vec2 uv = pos.xy * 0.008 + 0.5;
    float t = sunAngle * 150.0; // Map sunAngle to animation time
    
    vec4 color = vec4(0.0);
    
    // Raymarch parameters
    const int iterations = 30;
    float z = 0.0;
    
    for(int i = 0; i < iterations; i++) {
        // Raymarch sample position (adjusted for our coordinate system)
        vec3 p = z * normalize(vec3(uv, 0.0));
        
        // Scroll forward with animation
        p.z -= t;
        
        // Temporary vector for sine waves
        vec3 v;
        
        // Compute distance for sine pattern (and step forward)
        float d = 1e-4 + 0.5 * length(max(v = cos(p) - sin(p).yzx, v.yzx * 1.5));
        z += d;
        
        // Use position for coloring
        color.rgb += (cos(p) * 0.8 + 0.5) / d;
    }
    
    // Tonemapping
    color.rgb /= color.rgb + 1000.0;
    
    return color.rgb;
}

vec3 spectralWaveEffect(vec3 pos) {
    // 将3D位置转换为2D UV坐标，在x-y平面上应用效果
    vec2 uv = pos.xy * 0.008 - 0.95; // 调整缩放因子以适应场景
    
    // 使用sunAngle作为动画时间
    float t = sunAngle * 500.0;
    
    // 定义颜色方案
    vec3 color1 = vec3(254.0/255.0, 63.0/255.0, 53.0/255.0); // 红色
    vec3 color2 = vec3(254.0/255.0, 91.0/255.0, 200.0/255.0); // 粉色
    vec3 color3 = vec3(1.0, 1.0, 1.0); // 白色
    vec3 color4 = vec3(21.0/255.0, 202.0/255.0, 130.0/255.0); // 绿色
    
    // 初始化颜色
    vec3 col = color1;
    vec3 currentCol;
    
    // 控制波浪层数量的参数
    float s = 0.08;
    float factorSheets = 1.0; // 控制显示的层数
    
    // 添加一些随时间变化的动态效果
    factorSheets *= (sin(t * 0.4) + 1.0) * 0.5 + 0.5; // 可选：使层数波动
    
    for(float f = -1.0; f < factorSheets; f += s) {
        uv.x += s;
        
        // 波浪参数
        float freq = 5.0 * exp(-5.0 * (f * f));
        float amp = 0.15 * exp(-5.0 * (f * f));
        
        // 波浪距离场
        float dist = amp * pow(sin(freq * uv.y - 2.0 * t + 100.0 * sin(122434.0 * f)), 2.0) * 
                    exp(-5.0 * uv.y * uv.y) - uv.x;
        
        // 创建遮罩
        float mask = 1.0 - smoothstep(0.0, 0.005, dist);
        
        // 绘制每层线条
        float dist1 = abs(dist);
        dist1 = smoothstep(0.0, 0.01, dist1);
        
        // 阴影效果
        float dist2 = smoothstep(0.0, 0.04, dist);
        dist2 = mix(1.0, 1.0, dist2);
        dist2 *= mask;
        
        // 组合效果
        float l = mix(dist1, dist2, mask);
        
        // 随机选择颜色
        float rand = fract(sin(dot(vec2(f, f), vec2(12.9898, 78.233))) * 43758.5453);
        if(rand < 0.5) currentCol = color1;
        else if(rand < 0.65) currentCol = color3;
        else if(rand < 0.75) currentCol = color2;
        else currentCol = color4;
        
        // 混合颜色
        col = mix(currentCol, col, mask);
    }
    
    // 最终颜色调整
    vec3 curvecolor = vec3(0.0);
    vec3 finalColor = mix(curvecolor, col, 1.0);
    
    return finalColor;
}

vec3 waterTurbulenceEffect(vec3 pos) {
    // 使用x-z坐标作为水面平面，y坐标作为时间偏移量
    vec2 uv = pos.xy * 0.005; // 调整缩放因子控制波纹密度
    float time = sunAngle * 150.0 + 77.0; // 映射sunAngle到动画时间
    
    const float TAU = 3.333333333333;
    const int MAX_ITER = 5;
    
    // 使用平铺模式（可以注释掉SHOW_TILING相关代码）
    vec2 p = mod(uv * TAU, TAU) - 333.0;
    vec2 i = vec2(p);
    float c = 1.0;
    float inten = 0.005;

    for (int n = 0; n < MAX_ITER; n++) {
        float t = time * (1.0 - (3.5 / float(n + 1)));
        i = p + vec2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
        c += 1.0 / length(vec2(p.x / (sin(i.x + t) / inten), p.y / (cos(i.y + t) / inten)));
    }
    
    c /= float(MAX_ITER);
    c = 1.17 - pow(c, 1.73);
    vec3 colour = vec3(pow(abs(c), 37.0));
    
    colour = clamp(colour + colorGradient(CobblestoneColors, 3, sunAngle * 20.0) * 1.5, 0.0, 1.0);
    
    
    return colour;
}

vec3 bubblePlaneEffect(vec3 pos) {
    vec2 uv = vec2(pos.x * 0.1, pos.y * 0.015) - 1.5;
    
    // 背景色
    vec3 color = vec3(0.95, 0.85, 0.0);
    
    // 气泡参数
    float time = sunAngle * 6000.0; // 将sunAngle转换为动画时间
    
    // 生成气泡
    for(int i = 0; i < 20; i++) { // 减少气泡数量以提高性能
        // 气泡种子
        float pha = sin(float(i) * 546.13 + 1.0) * 0.5 + 0.5;
        float siz = pow(sin(float(i) * 651.74 + 5.0) * 0.5 + 0.5, 4.0);
        float pox = sin(float(i) * 321.55 + 4.1) * 2.0;
        
        // 气泡大小、位置和颜色
        float rad = 0.1 + 0.3 * siz; // 减小最大半径
        vec2 pos2 = vec2(pox, -1.0 - rad + (2.0 + 2.0 * rad) * mod(pha + 0.1 * time * (0.2 + 0.8 * siz), 1.0));
        float dis = length(uv - pos2);
        
        // 气泡颜色 (根据sunAngle变化)
        vec3 col = mix(vec3(0.20, 0.4, 0.0), 
                      vec3(0.1, 0.4, 0.8), 
                      0.5 + 1.5 * sin(float(i) * 1.2 + sunAngle * 5.0));
        
        // 渲染气泡
        float f = length(uv - pos2) / rad;
        f = sqrt(clamp(1.0 - f * f, 0.0, 1.0));
        color -= col.zyx * (1.0 - smoothstep(rad * 0.95, rad, dis)) * f;
    }
    
    return color;
}

/**************************************
*
* 过渡效果函数
*
**************************************/

vec3 getEffectByMode(int mode, vec3 pos) {
    if (mode == 0) {
        return twistedConeEffect(pos);
    } else if (mode == 1) {
        return gradientEffect(pos, -1.0, pos.y < 60 || pos.y >= 160 ? 1.0 : -1.0, 0.0);
    } else if (mode == 2) {
        return gradientEffect(pos, 1.0, -0.2, 0.0);
    } else if (mode == 3) {
        return gradientEffect(pos, 0.0, -0.3, -0.2);
    } else if (mode == 4) {
        return rainbowDiskEffect(pos);
    } else if (mode == 5) {
        return gradientEffect(pos, 0.0, 0.0, 1.0);
    } else if (mode == 6) {
        return rainbowCylinder(pos);
    } else {
        return gradientEffect(pos, 0.0, 0.0, 0.0); // Default to mode 0
    }
}

// 从右向左滑动过渡
vec3 transitionSlideLeft(int oldMode, int newMode, vec3 pos, float progress) {
    vec2 uv = pos.xz * 0.01;
    if (uv.x > 1.0 - progress) {
        return getEffectByMode(newMode, pos);
    } else {
        return getEffectByMode(oldMode, pos);
    }
}

// 从中心向外扩散过渡
vec3 transitionRadial(int oldMode, int newMode, vec3 pos, float progress) {
    vec2 uv = pos.xz * 0.01;
    float dist = length(uv - vec2(0.5));
    if (dist < progress * 0.7) {
        return getEffectByMode(newMode, pos);
    } else {
        return getEffectByMode(oldMode, pos);
    }
}

// 波纹过渡
vec3 transitionRipple(int oldMode, int newMode, vec3 pos, float progress) {
    vec2 uv = pos.xz * 0.01;
    float dist = length(uv - vec2(0.5));
    float ripple = sin(dist * 20.0 - progress * 10.0) * 0.5 + 0.5;
    
    if (ripple < progress) {
        return getEffectByMode(newMode, pos);
    } else {
        return getEffectByMode(oldMode, pos);
    }
}

/**************************************
*
* 收集函数
*
**************************************/

vec3 get_emitted_light(uint block_id, ivec3 pos) {
    ivec3 thread_pos = ivec3(gl_GlobalInvocationID);
	if (is_red_components(block_id)) {
		int MODE_COUNT = 7;
        int SHOW_TIMES = 40;
        float TRANSITION_DURATION = 0.2;

        float cyclePosition = sunAngle * float(SHOW_TIMES);
        int currentMode = int(floor(cyclePosition)) % MODE_COUNT;
        int nextMode = (currentMode + 1) % MODE_COUNT;

        float transitionProgress = fract(cyclePosition);
        
        vec3 posOffset = vec3(0, -60, 0);
		vec3 PPos = vec3(thread_pos) - 0.5 * vec3(voxel_volume_size) + vec3(cameraPosition) - posOffset;
		vec3 RC;

        /* if (transitionProgress < TRANSITION_DURATION) {
            // 在过渡期间混合两种效果
            float normalizedProgress = transitionProgress / TRANSITION_DURATION;
            
            // 选择过渡效果 (0-2)
            int transitionType = int(sunAngle * 100.0) % 3;
            
            if (transitionType == 0) {
                RC = transitionSlideLeft(currentMode, nextMode, PPos, normalizedProgress);
            } else if (transitionType == 1) {
                RC = transitionRadial(currentMode, nextMode, PPos, normalizedProgress);
            } else {
                RC = transitionRipple(currentMode, nextMode, PPos, normalizedProgress);
            }
        } else { */
            // 非过渡期间使用当前模式
            RC = getEffectByMode(currentMode, PPos);
        // }

		RC *= 0.8;
		return RC * (sunAngle > 0.478 && sunAngle < 1.0 ? 6.0 : 0.0);
	} else if (is_enchanting_table(block_id)) {
		vec3 RC = gradientEffect(vec3(pos), 0.0, 0.0, 0.0);
		RC *= 0.8;
		return RC * (sunAngle > 0.478 && sunAngle < 1.0 ? 24.0 : 0.0);
	} else if (is_emitter(block_id)) {
		return texelFetch(light_data_sampler, ivec2(int(block_id) - 32, 0), 0).rgb;
	} else {
		return vec3(0.0);
	}
}

vec3 get_tint(uint block_id, bool is_transparent) {
	if (is_translucent(block_id)) {
		if (block_id == 79u) {
			return vec3(0.85);
		}
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