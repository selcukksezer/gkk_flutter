import json

with open('reports/vision/live_telemetry_snapshot.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

print('=== 3D ASSETS ===')
print('Categories:', json.dumps(data['3d_assets']['categories'], indent=2))
print('LOD distribution:', data['3d_assets']['lod_distribution'])
print('Polygon range:', data['3d_assets']['polygon_range'])
print('Total size MB:', data['3d_assets']['total_size_mb'])

print('\n=== PBR TEXTURES ===')
print('PBR Channel breakdown:', json.dumps(data['pbr_textures']['pbr_channel_distribution'], indent=2))
print('Total texture size MB:', data['pbr_textures']['total_size_mb'])

print('\n=== SHADER PIPELINE ===')
print('Total shaders:', data['shader_pipeline']['total_shader_files'])
print('Registered in pubspec:', data['shader_pipeline']['registered_in_pubspec'])
print('Shader feature breakdown:', json.dumps(data['shader_pipeline']['shader_feature_breakdown'], indent=2))
print('Shader list:')
for s in data['shader_pipeline']['shaders']:
    print('  -', s['name'], f"({s['size_bytes']} bytes)")

print('\n=== GOLDEN SCREENSHOTS ===')
print('Total screenshot images:', data['golden_screenshots']['total_golden_screenshot_images'])
print('Screen definitions in lib/screens:', data['golden_screenshots']['total_screen_definitions'])
print('Golden test suites count:', data['golden_screenshots']['golden_test_suites_count'])
print('Golden test suites:')
for t in data['golden_screenshots']['golden_test_suites']:
    print('  -', t)

print('\n=== BENCHMARKS & THERMAL ===')
print('Bench files found:', len(data['performance_and_benchmark']['bench_files_found']))
for b in data['performance_and_benchmark']['bench_files_found']:
    print('  -', b)
print('Extracted benchmark data:', json.dumps(data['performance_and_benchmark']['extracted_data'], indent=2))

print('\n=== TEAM CONCURRENCY ===')
print(json.dumps(data['teamwork_concurrency'], indent=2))
