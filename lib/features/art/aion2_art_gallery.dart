// Aion-2 Art Gallery & Asset Showcase
// Interactive Flutter UI gallery displaying all 14 asset categories:
// Boss portraits, deities, skill icons, weapon & armor icons, living backgrounds,
// animated flipbooks, and ornate UI frames.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'aion2_art_assets.dart';

/// Entrypoint Widget for the Aion-2 Art Gallery
class Aion2ArtGallery extends StatefulWidget {
  const Aion2ArtGallery({super.key});

  @override
  State<Aion2ArtGallery> createState() => _Aion2ArtGalleryState();
}

class _Aion2ArtGalleryState extends State<Aion2ArtGallery> {
  Aion2AssetCategory? _selectedCategory;
  String _searchQuery = '';
  String _selectedRarity = 'All';

  final TextEditingController _searchController = TextEditingController();

  final List<String> _rarities = const [
    'All',
    'Mythic',
    'Divine',
    'Eternal',
    'Heroic',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Aion2AssetItem> get _filteredAssets {
    return Aion2ArtAssets.allAssets.where((asset) {
      if (_selectedCategory != null && asset.category != _selectedCategory) {
        return false;
      }
      if (_selectedRarity != 'All' && asset.rarity != _selectedRarity) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = asset.title.toLowerCase().contains(query);
        final matchSubtitle = asset.subtitle.toLowerCase().contains(query);
        final matchLore = asset.lore.toLowerCase().contains(query);
        if (!matchTitle && !matchSubtitle && !matchLore) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAssets;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090A0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF13151F),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F111A),
          elevation: 4,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                  gradient: const RadialGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFF13151F)],
                  ),
                ),
                child: const Icon(Icons.shield_moon_rounded, color: Color(0xFFD4AF37), size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AION-2 ART GALLERY',
                    style: TextStyle(
                      fontFamily: 'Trajan Pro',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Color(0xFFE2C158),
                    ),
                  ),
                  Text(
                    'High Fantasy Assets & Production VFX Manifest',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2235),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 6),
                    Text(
                      '${Aion2ArtAssets.allAssets.length} Assets',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search & Filter Header
            _buildSearchAndFilters(),

            // Category Chips Bar
            _buildCategorySelector(),

            // Asset Grid
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _AssetCard(
                          asset: filtered[index],
                          onTap: () => _openAssetDetail(filtered[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: const Color(0xFF0F111A),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Search input
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF181B28),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2C324B)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by title, class, boss, rune...',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFFD4AF37)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Rarity Selector
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF181B28),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2C324B)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRarity,
                dropdownColor: const Color(0xFF181B28),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFD4AF37)),
                style: const TextStyle(fontSize: 12, color: Colors.white),
                items: _rarities.map((r) {
                  return DropdownMenuItem<String>(
                    value: r,
                    child: Text(
                      r,
                      style: TextStyle(
                        color: _getRarityColor(r),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRarity = val;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 48,
      color: const Color(0xFF0F111A),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All Categories'),
              selected: _selectedCategory == null,
              selectedColor: const Color(0xFFD4AF37),
              backgroundColor: const Color(0xFF181B28),
              labelStyle: TextStyle(
                fontSize: 11,
                color: _selectedCategory == null ? Colors.black : Colors.white70,
                fontWeight: _selectedCategory == null ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedCategory = null;
                });
              },
            ),
          ),

          // Individual categories
          ...Aion2AssetCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat;
            final count = Aion2ArtAssets.byCategory(cat).length;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(cat.icon, size: 14, color: isSelected ? Colors.black : const Color(0xFFD4AF37)),
                label: Text('${cat.displayName} ($count)'),
                selected: isSelected,
                selectedColor: const Color(0xFFD4AF37),
                backgroundColor: const Color(0xFF181B28),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedCategory = isSelected ? null : cat;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No Assets Match Query',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your category, rarity, or search term.',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFD4AF37)),
            ),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _selectedCategory = null;
                _selectedRarity = 'All';
              });
            },
            child: const Text('Reset All Filters', style: TextStyle(color: Color(0xFFD4AF37))),
          ),
        ],
      ),
    );
  }

  void _openAssetDetail(Aion2AssetItem asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AssetDetailModal(asset: asset),
    );
  }

  static Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'Mythic':
        return const Color(0xFFFF5252);
      case 'Divine':
        return const Color(0xFFFFD700);
      case 'Eternal':
        return const Color(0xFFFF9100);
      case 'Heroic':
        return const Color(0xFF00E5FF);
      default:
        return Colors.white70;
    }
  }
}

/// Asset Card Displayed in the Gallery Grid
class _AssetCard extends StatelessWidget {
  final Aion2AssetItem asset;
  final VoidCallback onTap;

  const _AssetCard({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rarityColor = _Aion2ArtGalleryState._getRarityColor(asset.rarity);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF13151F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: rarityColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Preview Area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                    child: Container(
                      color: const Color(0xFF0A0C12),
                      child: Aion2ArtAssets.image(
                        asset.path,
                        fit: asset.isBackground ? BoxFit.cover : BoxFit.contain,
                      ),
                    ),
                  ),

                  // Rarity Badge
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: rarityColor, width: 0.8),
                      ),
                      child: Text(
                        asset.rarity.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: rarityColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Flipbook / VFX Indicator Badge
                  if (asset.isFlipbook)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E57C2).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_filled, size: 10, color: Colors.white),
                            SizedBox(width: 3),
                            Text('4x4 ANIM', style: TextStyle(fontSize: 8, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Card Caption
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF13151F),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    asset.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF0E6D2),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    asset.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed Modal Dialog / Sheet for Asset Inspection & Animation Playback
class _AssetDetailModal extends StatelessWidget {
  final Aion2AssetItem asset;

  const _AssetDetailModal({required this.asset});

  @override
  Widget build(BuildContext context) {
    final rarityColor = _Aion2ArtGalleryState._getRarityColor(asset.rarity);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF10131E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.9),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Rarity Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.title,
                          style: const TextStyle(
                            fontFamily: 'Trajan Pro',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE2C158),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          asset.subtitle,
                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: rarityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: rarityColor),
                    ),
                    child: Text(
                      asset.rarity.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: rarityColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Interactive Media Preview Box
              Container(
                height: 320,
                decoration: BoxDecoration(
                  color: const Color(0xFF08090E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF23283B)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildMediaView(),
                ),
              ),
              const SizedBox(height: 16),

              // Category and Path Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A28),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF23283B)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Category', asset.category.displayName),
                    const Divider(color: Colors.white12, height: 16),
                    _buildInfoRow('Internal ID', asset.id),
                    const Divider(color: Colors.white12, height: 16),
                    _buildInfoRow('Manifest Path', asset.path, isSelectable: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Lore & Description Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A28),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_stories_rounded, size: 16, color: Color(0xFFD4AF37)),
                        SizedBox(width: 8),
                        Text(
                          'ATREIAN ARCHIVE LORE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      asset.lore,
                      style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Close Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2235),
                  foregroundColor: const Color(0xFFD4AF37),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFD4AF37)),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaView() {
    if (asset.isFlipbook) {
      return _FlipbookPlayer(asset: asset);
    } else if (asset.isMagicCircle) {
      return _MagicCircleViewer(asset: asset);
    } else {
      return InteractiveViewer(
        maxScale: 4.0,
        child: Center(
          child: Aion2ArtAssets.image(
            asset.path,
            fit: asset.isBackground ? BoxFit.cover : BoxFit.contain,
          ),
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value, {bool isSelectable = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54),
          ),
        ),
        Expanded(
          child: isSelectable
              ? SelectableText(
                  value,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF00E5FF)),
                )
              : Text(
                  value,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
        ),
      ],
    );
  }
}

/// Interactive Animated Flipbook Player
/// Decodes a 4x4 sprite atlas and plays all 16 frames in real-time
class _FlipbookPlayer extends StatefulWidget {
  final Aion2AssetItem asset;

  const _FlipbookPlayer({required this.asset});

  @override
  State<_FlipbookPlayer> createState() => _FlipbookPlayerState();
}

class _FlipbookPlayerState extends State<_FlipbookPlayer> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  ui.Image? _spriteSheet;
  bool _isLoading = true;
  bool _isPlaying = true;
  int _currentFrame = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // 16 frames in 1.0 sec = 16 fps
    )..addListener(() {
        final frame = (_animController.value * 16).floor() % 16;
        if (frame != _currentFrame) {
          setState(() {
            _currentFrame = frame;
          });
        }
      });

    _animController.repeat();
    _loadSpriteSheet();
  }

  void _loadSpriteSheet() {
    final imageProvider = AssetImage(widget.asset.path);
    final stream = imageProvider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
      if (mounted) {
        setState(() {
          _spriteSheet = info.image;
          _isLoading = false;
        });
      }
      stream.removeListener(listener);
    }, onError: (dynamic error, StackTrace? stackTrace) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
    stream.addListener(listener);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_isPlaying) {
        _animController.stop();
        _isPlaying = false;
      } else {
        _animController.repeat();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      );
    }

    if (_spriteSheet == null) {
      return Center(
        child: Aion2ArtAssets.image(widget.asset.path, fit: BoxFit.contain),
      );
    }

    return Stack(
      children: [
        // Real-time sliced frame painter
        Center(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: CustomPaint(
              painter: _SpriteFramePainter(
                image: _spriteSheet!,
                frameIndex: _currentFrame,
                columns: 4,
                rows: 4,
              ),
            ),
          ),
        ),

        // Bottom Controls Overlay
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  color: const Color(0xFF00E5FF),
                  iconSize: 28,
                  onPressed: _togglePlay,
                ),
                const SizedBox(width: 8),
                Text(
                  'Frame ${_currentFrame + 1}/16',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                const Text(
                  'VFX 4x4 ATLAS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD4AF37),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// CustomPainter that slices and renders a single frame from a sprite sheet grid
class _SpriteFramePainter extends CustomPainter {
  final ui.Image image;
  final int frameIndex;
  final int columns;
  final int rows;

  _SpriteFramePainter({
    required this.image,
    required this.frameIndex,
    required this.columns,
    required this.rows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = image.width / columns;
    final frameHeight = image.height / rows;

    final col = frameIndex % columns;
    final row = (frameIndex / columns).floor() % rows;

    final srcRect = Rect.fromLTWH(
      col * frameWidth,
      row * frameHeight,
      frameWidth,
      frameHeight,
    );

    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..filterQuality = FilterQuality.medium;

    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant _SpriteFramePainter oldDelegate) {
    return oldDelegate.frameIndex != frameIndex || oldDelegate.image != image;
  }
}

/// Rotating Magic Circle Viewer with slow continuous rotation and celestial glow
class _MagicCircleViewer extends StatefulWidget {
  final Aion2AssetItem asset;

  const _MagicCircleViewer({required this.asset});

  @override
  State<_MagicCircleViewer> createState() => _MagicCircleViewerState();
}

class _MagicCircleViewerState extends State<_MagicCircleViewer> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _isRotating = true;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Ambient Runic Glow
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.asset.themeColor.withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
        ),

        // Rotating Circle
        Center(
          child: RotationTransition(
            turns: _rotationController,
            child: SizedBox(
              width: 260,
              height: 260,
              child: Aion2ArtAssets.image(widget.asset.path, fit: BoxFit.contain),
            ),
          ),
        ),

        // Control Toggle
        Positioned(
          top: 10,
          right: 10,
          child: IconButton(
            icon: Icon(
              _isRotating ? Icons.rotate_right_rounded : Icons.pause_circle_outline_rounded,
              color: const Color(0xFFD4AF37),
            ),
            tooltip: 'Toggle Rotation',
            onPressed: () {
              setState(() {
                if (_isRotating) {
                  _rotationController.stop();
                  _isRotating = false;
                } else {
                  _rotationController.repeat();
                  _isRotating = true;
                }
              });
            },
          ),
        ),
      ],
    );
  }
}
