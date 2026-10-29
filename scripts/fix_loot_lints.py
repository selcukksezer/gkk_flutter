import sys
content = open('lib/screens/loot/loot_chest_widgets.dart', encoding='utf-8').read()

replacements = [
    ("'x' + widget.quantity.toString()", "'x${widget.quantity}'"),
    ("'[GKK] 10x ' + widget.boxName + ' açılışı tamamlandı! En iyi drop: ' + best + '!'", "'[GKK]} 10x ${widget.boxName} açılışı tamamlandı! En iyi drop: $best!'"),
    ("'Paylaşıldı: ' + shareText", "'Paylaşıldı: $shareText'"),
    ("'10x ' + widget.boxName.toUpperCase()", "'10x ${widget.boxName.toUpperCase()}'"),
    ("errorBuilder: (_, __, ___)", "errorBuilder: (_, _, _)"),
    ("theme.tier.tierBadge + ' · ' + theme.tier.runicGlyphs.first", "'${theme.tier.tierBadge} · ${theme.tier.runicGlyphs.first}'"),
    ("'%' + drop.dropRate.toStringAsFixed(2)", "'%${drop.dropRate.toStringAsFixed(2)}'"),
    ("'x' + drop.minQuantity.toString() + '-' + drop.maxQuantity.toString()", "'x${drop.minQuantity}-${drop.maxQuantity}'"),
    ("drop.rarity.toUpperCase() + ' · ' + lootDropCategoryLabel(drop.itemId)", "'${drop.rarity.toUpperCase()} · ${lootDropCategoryLabel(drop.itemId)}'"),
    ("stat.$1 + ': ' + stat.$2", "'d{stat.$1}: ${stat.$2}'"),
]

for old, new in replacements:
    content = content.replace(old, new)

open('lib/screens/loot/loot_chest_widgets.dart', 'w', encoding='utf-8').write(content)
print('Successfully fixed loot_chest_widgets.dart')
