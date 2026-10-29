# Vision Prompt Director — Wave 1 Continuity Findings

1. **Cold-Boot `SplashScreen` Bypass (`lib/routing/app_router.dart` L216-270, `lib/main.dart`)**:
   - `'/'` (`AppRoutes.splash`) in `isAuthEntryRoute` redirects immediately to `/home` when persisted Supabase session exists, skipping `DeviceSessionService.verifyCurrentDevice()`, `AuthNotifier.loadSession()`, and `GraphicsSettingsService.instance.load()`.
2. **Colliding Guild-War Route Constants (`lib/routing/app_router.dart` L113-119, L622)**:
   - `AppRoutes.guildWarTerritory` and `AppRoutes.guildWarAttack` both equal `'/guild-war/territory'` vs parameterized `GoRoute` paths; unused global `appRouter` duplicates `_GkkMobileAppState._router`.
3. **Logout Leak in `DungeonBattleScreen` (`lib/screens/dungeon/dungeon_battle_screen.dart` L607-610)**:
   - Inline logout instead of centralized `performLogout(ref)`.
4. **Market UUID Namespace Split (`public.users.id` vs `auth.uid()`), Self-Buy Bug, Double-Submit & Slider Freeze**:
   - `lib/providers/market_provider.dart` L94-103 & L222-334
   - `lib/screens/market/widgets/market_browse_tab.dart` L112, L505, L513-545
   - `lib/repositories/market_repository.dart` L123
   - `lib/screens/market/widgets/market_quantity_sheet.dart` L80-206 (`divisions: _effectiveMax - 1` up to `999,998`).
5. **`PlayerProfile` `copyWith(healthLastUpdated)` Reset, `toJson` Missing Nightlife Fields & `fromJson` Cast Fragility**:
   - `lib/models/player_model.dart` L138-408
   - `lib/repositories/player_repository.dart` L26-47
6. **`DungeonBattleScreen` Direct RPC Bypass (`attack_dungeon`)**:
   - `lib/screens/dungeon/dungeon_battle_screen.dart` L436-439
7. **Impeller Shaders Under `assets:` Instead of `shaders:` (`pubspec.yaml` L171-201)**:
   - `shaders/crowd/vat_crowd.frag`, `shaders/lighting/clustered_crowd_lighting.frag`, plus any missing `.frag` files out of 18.
8. **`AdaptiveQualityScaler` Unwired, Eco 30 FPS vs 60 FPS Dynamic Scale, Duplicate `update()` & `existsSync()`**:
   - `lib/screens/home/home_screen.dart` L61, L248-258
   - `lib/screens/home/widgets/hub_crowd_layer.dart` L75
   - `lib/screens/dungeon/widgets/dungeon_monster_glb_viewport.dart` L343-395
   - `lib/screens/settings/graphics_settings_service.dart` L38-44 (UTF-8 mojibake!), L108-165
   - `lib/core/engine/adaptive_quality_scaler.dart` L15-16
9. **Forbidden `*_beauty.png` References & `<48dp` Hitboxes**:
   - `lib/screens/dungeon/widgets/dungeon_monster_glb_viewport.dart` L61-77, L572-582
   - `lib/screens/dungeon/dungeon_battle_screen.dart` L1218
