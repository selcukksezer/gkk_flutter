import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import 'auth_design.dart';

/// 2027 Aion 2 Mobile Cinematic Tab Switcher: [ GİRİŞ YAP ] | [ YENİ KAYIT ]
class AionPortalTabs extends StatelessWidget {
  const AionPortalTabs({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
    this.loginLabel = 'GİRİŞ YAP',
    this.registerLabel = 'KAYIT OL',
    this.accentColor = const Color(0xFFFFD700),
  });

  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final String loginLabel;
  final String registerLabel;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xCC060A14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _TabButton(
              label: loginLabel,
              icon: Icons.shield_outlined,
              isSelected: selectedIndex == 0,
              accentColor: accentColor,
              onTap: () {
                HapticFeedback.selectionClick();
                onTabChanged(0);
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              label: registerLabel,
              icon: Icons.auto_awesome_outlined,
              isSelected: selectedIndex == 1,
              accentColor: AppColors.cyberFuchsia,
              onTap: () {
                HapticFeedback.selectionClick();
                onTabChanged(1);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AuthPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    accentColor.withValues(alpha: 0.32),
                    accentColor.withValues(alpha: 0.12),
                  ],
                )
              : null,
          border: isSelected
              ? Border.all(color: accentColor.withValues(alpha: 0.65), width: 1.2)
              : Border.all(color: Colors.transparent),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: isSelected ? accentColor : AuthDesign.textLow,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.urbanist(
                color: isSelected ? Colors.white : AuthDesign.textLow,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
