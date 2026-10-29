import glob

for p in sorted(glob.glob('reports/audit/*.md')):
    with open(p, 'r', encoding='utf-8') as f:
        print('=== ' + p + ' ===')
        lines = f.readlines()
        for line in lines[:30]:
            safe_line = line.strip().encode('ascii', 'replace').decode('ascii')
            print(safe_line)
        print()
