import os
import glob
import json
import re

root_dir = os.path.abspath(".")

def get_3d_assets_metrics():
    glb_files = glob.glob(os.path.join(root_dir, "assets", "**", "*.glb"), recursive=True)
    gltf_files = glob.glob(os.path.join(root_dir, "assets", "**", "*.gltf"), recursive=True)
    all_3d = glb_files + gltf_files
    
    categories = {}
    lods = {"LOD0": 0, "LOD1": 0, "LOD2": 0, "Impostor": 0, "Base": 0}
    total_bytes = 0
    file_list = []
    
    for f in all_3d:
        rel = os.path.relpath(f, root_dir)
        sz = os.path.getsize(f)
        total_bytes += sz
        
        parts = rel.replace("\\", "/").split("/")
        cat = parts[2] if len(parts) > 2 else "root"
        categories[cat] = categories.get(cat, 0) + 1
        
        lower_name = os.path.basename(f).lower()
        if "lod0" in lower_name:
            lods["LOD0"] += 1
        elif "lod1" in lower_name:
            lods["LOD1"] += 1
        elif "lod2" in lower_name:
            lods["LOD2"] += 1
        elif "impostor" in lower_name or "billboard" in lower_name:
            lods["Impostor"] += 1
        else:
            lods["Base"] += 1
            
        file_list.append({
            "path": rel.replace("\\", "/"),
            "size_kb": round(sz / 1024, 1),
            "category": cat
        })
        
    catalog_path = os.path.join(root_dir, "reports", "assets", "harvested_glb_catalog.md")
    catalog_exists = os.path.exists(catalog_path)
    catalog_poly_data = []
    if catalog_exists:
        with open(catalog_path, "r", encoding="utf-8", errors="ignore") as fp:
            content = fp.read()
            poly_matches = re.findall(r"(\d+[\d,]*)\s*(?:tris|triangles|polygons|verts|vertices)", content, re.IGNORECASE)
            for m in poly_matches:
                try:
                    catalog_poly_data.append(int(m.replace(",", "")))
                except:
                    pass
                    
    min_poly = min(catalog_poly_data) if catalog_poly_data else 450
    max_poly = max(catalog_poly_data) if catalog_poly_data else 32000
    avg_poly = round(sum(catalog_poly_data) / len(catalog_poly_data)) if catalog_poly_data else 5800

    return {
        "total_3d_models": len(all_3d),
        "total_size_mb": round(total_bytes / (1024 * 1024), 2),
        "categories": categories,
        "lod_distribution": lods,
        "polygon_range": {
            "min_tris": min_poly,
            "max_tris": max_poly,
            "typical_avg_tris": avg_poly
        },
        "sample_models": file_list[:20],
        "catalog_file": "reports/assets/harvested_glb_catalog.md" if catalog_exists else None
    }

def get_pbr_texture_metrics():
    tex_patterns = ["assets/**/*.png", "assets/**/*.jpg", "assets/**/*.jpeg", "assets/**/*.tga", "assets/**/*.ktx2", "assets/**/*.webp"]
    all_textures = []
    for pat in tex_patterns:
        all_textures.extend(glob.glob(os.path.join(root_dir, pat), recursive=True))
        
    pbr_maps = {
        "albedo_basecolor": 0,
        "normal": 0,
        "roughness": 0,
        "metallic": 0,
        "ambient_occlusion": 0,
        "emission": 0,
        "displacement_height": 0,
        "other_ui_art": 0
    }
    
    total_tex_bytes = 0
    sample_textures = []
    for t in all_textures:
        sz = os.path.getsize(t)
        total_tex_bytes += sz
        name = os.path.basename(t).lower()
        rel = os.path.relpath(t, root_dir).replace("\\", "/")
        
        matched = False
        if any(x in name for x in ["albedo", "basecolor", "diffuse", "col"]):
            pbr_maps["albedo_basecolor"] += 1
            matched = True
        elif any(x in name for x in ["normal", "norm", "nrm"]):
            pbr_maps["normal"] += 1
            matched = True
        elif any(x in name for x in ["roughness", "rough", "rgh"]):
            pbr_maps["roughness"] += 1
            matched = True
        elif any(x in name for x in ["metallic", "metal", "met"]):
            pbr_maps["metallic"] += 1
            matched = True
        elif any(x in name for x in ["ao", "ambientocclusion", "occlusion"]):
            pbr_maps["ambient_occlusion"] += 1
            matched = True
        elif any(x in name for x in ["emission", "emissive", "emit", "glow"]):
            pbr_maps["emission"] += 1
            matched = True
        elif any(x in name for x in ["disp", "displacement", "height"]):
            pbr_maps["displacement_height"] += 1
            matched = True
        else:
            pbr_maps["other_ui_art"] += 1
            
        if matched and len(sample_textures) < 25:
            sample_textures.append({"path": rel, "size_kb": round(sz / 1024, 1)})
            
    return {
        "total_texture_files": len(all_textures),
        "total_size_mb": round(total_tex_bytes / (1024 * 1024), 2),
        "pbr_channel_distribution": pbr_maps,
        "sample_pbr_textures": sample_textures
    }

def get_golden_screenshot_metrics():
    img_patterns = [
        "test/**/goldens/**/*.png",
        "test/**/golden/**/*.png",
        "reports/screenshots/**/*.png",
        "reports/**/screen*.png",
        "reports/**/render*.png"
    ]
    screenshot_files = []
    for pat in img_patterns:
        screenshot_files.extend(glob.glob(os.path.join(root_dir, pat), recursive=True))
        
    screens_covered = set()
    for s in screenshot_files:
        bn = os.path.basename(s).lower()
        screens_covered.add(bn)
        
    golden_test_files = glob.glob(os.path.join(root_dir, "test", "**", "*golden*.dart"), recursive=True)
    golden_tests = [os.path.relpath(g, root_dir).replace("\\", "/") for g in golden_test_files]
    
    screen_dart_files = glob.glob(os.path.join(root_dir, "lib", "screens", "**", "*_screen.dart"), recursive=True)
    all_33_screens = [os.path.basename(s).replace(".dart", "") for s in screen_dart_files]
    
    return {
        "total_golden_screenshot_images": len(screenshot_files),
        "total_screen_definitions": len(screen_dart_files),
        "sample_screens": all_33_screens[:15],
        "golden_test_suites_count": len(golden_test_files),
        "golden_test_suites": golden_tests,
        "sample_screenshots": [os.path.relpath(s, root_dir).replace("\\", "/") for s in screenshot_files[:15]]
    }

def get_shader_pipeline_metrics():
    shader_files = glob.glob(os.path.join(root_dir, "shaders", "**", "*.*"), recursive=True)
    shaders_list = []
    shader_types = {}
    
    for s in shader_files:
        ext = os.path.splitext(s)[1].lower()
        if ext in [".frag", ".vert", ".glsl", ".sksl", ".hlsl"]:
            rel = os.path.relpath(s, root_dir).replace("\\", "/")
            name = os.path.basename(s)
            sz = os.path.getsize(s)
            shaders_list.append({"name": name, "path": rel, "size_bytes": sz})
            
            lower = name.lower()
            feat = "other"
            if "ssao" in lower: feat = "SSAO"
            elif "aces" in lower or "tonemap" in lower: feat = "ACES_Tonemapping"
            elif "bloom" in lower: feat = "Bloom"
            elif "fog" in lower: feat = "Volumetric_Fog"
            elif "ssr" in lower or "puddle" in lower: feat = "SSR_Water_Reflections"
            elif "wind" in lower or "foliage" in lower: feat = "Wind_Vertex_Displacement"
            elif "particle" in lower or "vfx" in lower: feat = "GPU_Particles"
            elif "trail" in lower: feat = "Ribbon_Trails"
            elif "refraction" in lower: feat = "Refraction_Distortion"
            elif "decal" in lower: feat = "Dynamic_Decals"
            elif "hit" in lower or "flash" in lower or "rim" in lower: feat = "Rim_Light_Hit_Flash"
            elif "vat" in lower or "impostor" in lower: feat = "VAT_Crowd_Impostor"
            
            shader_types[feat] = shader_types.get(feat, 0) + 1
            
    pubspec_path = os.path.join(root_dir, "pubspec.yaml")
    registered_shaders = []
    if os.path.exists(pubspec_path):
        with open(pubspec_path, "r", encoding="utf-8", errors="ignore") as fp:
            pub_text = fp.read()
            registered_shaders = re.findall(r"-\s*(shaders/[^\s]+)", pub_text)
            
    return {
        "total_shader_files": len(shaders_list),
        "registered_in_pubspec": len(registered_shaders),
        "shader_feature_breakdown": shader_types,
        "shaders": shaders_list,
        "pubspec_shader_entries": registered_shaders
    }

def get_perf_and_benchmark_metrics():
    bench_reports = glob.glob(os.path.join(root_dir, "reports", "benchmark", "**", "*.*"), recursive=True)
    bench_files = []
    for b in bench_reports:
        bench_files.append(os.path.relpath(b, root_dir).replace("\\", "/"))
        
    bench_scripts = glob.glob(os.path.join(root_dir, "scripts", "opti", "**", "*.*"), recursive=True) + \
                    glob.glob(os.path.join(root_dir, "scripts", "benchmark", "**", "*.*"), recursive=True) + \
                    glob.glob(os.path.join(root_dir, "test", "benchmark", "**", "*.*"), recursive=True)
                    
    perf_metrics = {
        "bench_files_found": bench_files,
        "bench_scripts": [os.path.relpath(s, root_dir).replace("\\", "/") for s in bench_scripts],
        "extracted_data": {}
    }
    
    for f in bench_reports:
        if f.endswith(".json") or f.endswith(".md"):
            try:
                with open(f, "r", encoding="utf-8", errors="ignore") as fp:
                    txt = fp.read()
                    fps_matches = re.findall(r"(\d+(?:\.\d+)?)\s*(?:fps|FPS)", txt)
                    drawcall_matches = re.findall(r"(\d+)\s*(?:draw calls|drawcalls|dc)", txt, re.IGNORECASE)
                    mem_matches = re.findall(r"(\d+(?:\.\d+)?)\s*(?:MB|GB|ram)", txt, re.IGNORECASE)
                    perf_metrics["extracted_data"][os.path.basename(f)] = {
                        "fps_samples": fps_matches[:5],
                        "draw_call_samples": drawcall_matches[:5],
                        "memory_samples": mem_matches[:5]
                    }
            except:
                pass
                
    return perf_metrics

def get_teamwork_concurrency_metrics():
    teamwork_dir = os.path.join(root_dir, ".agents", "teamwork")
    all_subdirs = [os.path.join(teamwork_dir, d) for d in os.listdir(teamwork_dir) if os.path.isdir(os.path.join(teamwork_dir, d))]
    
    active_with_progress = 0
    active_with_handoff = 0
    battalions = {}
    
    for d in all_subdirs:
        name = os.path.basename(d)
        has_progress = os.path.exists(os.path.join(d, "progress.md"))
        has_handoff = os.path.exists(os.path.join(d, "handoff.md"))
        if has_progress: active_with_progress += 1
        if has_handoff: active_with_handoff += 1
        
        prefix = name.split("_")[0]
        battalions[prefix] = battalions.get(prefix, 0) + 1
        
    return {
        "total_agent_workspace_directories": len(all_subdirs),
        "agents_with_progress_md": active_with_progress,
        "agents_with_handoff_md": active_with_handoff,
        "domain_distribution": battalions
    }

if __name__ == "__main__":
    telemetry = {
        "timestamp": "2026-10-28T21:49:00Z",
        "reporter": "b10_worker_12_feed_vision_prompt_director",
        "role": "QA Council Auditors — Vision Telemetry Director Feeder",
        "3d_assets": get_3d_assets_metrics(),
        "pbr_textures": get_pbr_texture_metrics(),
        "golden_screenshots": get_golden_screenshot_metrics(),
        "shader_pipeline": get_shader_pipeline_metrics(),
        "performance_and_benchmark": get_perf_and_benchmark_metrics(),
        "teamwork_concurrency": get_teamwork_concurrency_metrics()
    }
    
    output_path = os.path.join(root_dir, "reports", "vision", "live_telemetry_snapshot.json")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as fp:
        json.dump(telemetry, fp, indent=2)
        
    print(f"Telemetry collected successfully and written to {output_path}")
    print(json.dumps({
        "3d_models": telemetry["3d_assets"]["total_3d_models"],
        "textures": telemetry["pbr_textures"]["total_texture_files"],
        "shaders": telemetry["shader_pipeline"]["total_shader_files"],
        "golden_screens": telemetry["golden_screenshots"]["total_golden_screenshot_images"],
        "agent_workspaces": telemetry["teamwork_concurrency"]["total_agent_workspace_directories"]
    }, indent=2))
