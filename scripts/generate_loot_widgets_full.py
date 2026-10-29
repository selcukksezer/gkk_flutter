# Full generator
import sys

def main():
    with open('lib/screens/loot/loot_chest_widgets.dart', 'w', encoding='utf-8') as f:
        f.write(CODE_1 + CODE_2 + CODE_3 + CODE_4)
    print('Generated full loot_chest_widgets.dart')

if __name__ == '__main__':
    main()
