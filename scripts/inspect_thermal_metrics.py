import re
import json

with open('test/core/engine/adaptive_quality_scaler_test.dart', 'r', encoding='utf-8') as f:
    text = f.read()

tests = re.findall(r"test\(['\"](.*?)['\"]", text)
print("=== ADAPTIVE QUALITY SCALER TESTS ===")
for t in tests:
    print(" -", t)

with open('lib/core/engine/adaptive_quality_scaler.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Find thermal and 2GB specifics
thermal_snippets = []
for block in code.split("\n\n"):
    if "thermal" in block.lower() or "throttle" in block.lower() or "low" in block.lower():
        if "class" in block or "enum" in block or "factory" in block or "void" in block:
            thermal_snippets.append(block[:300])

print("\n=== THERMAL & LOW-SPEC ARCHITECTURE SNIPPETS ===")
for s in thermal_snippets[:6]:
    print("---")
    print(s)
