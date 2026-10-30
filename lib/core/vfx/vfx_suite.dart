/// ----------------------------------------------------------------------------
/// Production 2027 AAA Combat VFX Suite (gkk_flutter 9-Module Pipeline)
/// Target: Metal/Impeller (iOS) & Vulkan/Impeller (Android)
/// ----------------------------------------------------------------------------
library;

// Module 1: Multi-Layer GPU Particle System
export 'gpu_particle_system.dart';

// Module 2: Ribbon Trail Renderer & Mesh Generation
export 'ribbon_trail_renderer.dart';

// Module 3: Refraction & Shockwave Distortion
export 'refraction_effect.dart';

// Module 4: Ground Decal Projection System (hide Vector3D to avoid clash with ribbon_trail_renderer.dart)
export 'ground_decal_system.dart' hide Vector3D;

// Module 5: Directional Camera Shake & Recoil
export 'directional_camera_shake.dart';

// Module 6: Hit-Stop & Time Dilation Manager (30-50ms)
export 'hit_stop_manager.dart';

// Module 7: Rim-Light Hit Flash Effect
export 'rim_hit_flash_effect.dart';

// Module 8: Knockback & Ragdoll Blend Controller
export 'knockback_ragdoll_controller.dart';

// Module 9: Dynamic Dungeon & Arena Shadows
export 'dungeon_shadows.dart';
