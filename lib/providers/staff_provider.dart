import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';
import '../models/staff_model.dart';

class StaffState {
  const StaffState({
    this.isLoading = false,
    this.profile = StaffProfile.none,
    this.dashboard,
    this.error,
  });

  final bool isLoading;
  final StaffProfile profile;
  final StaffDashboard? dashboard;
  final String? error;

  StaffState copyWith({
    bool? isLoading,
    StaffProfile? profile,
    StaffDashboard? dashboard,
    String? error,
    bool clearError = false,
  }) {
    return StaffState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      dashboard: dashboard ?? this.dashboard,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class StaffNotifier extends Notifier<StaffState> {
  Future<void>? _inFlight;

  @override
  StaffState build() {
    Future<void>.microtask(load);
    return const StaffState(isLoading: true);
  }

  Future<void> load({bool silent = false}) async {
    if (_inFlight != null) {
      return _inFlight!;
    }
    _inFlight = _performLoad(silent: silent);
    try {
      await _inFlight;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _performLoad({required bool silent}) async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentSession == null) {
      state = const StaffState(profile: StaffProfile.none);
      return;
    }
    if (!silent || !state.profile.isStaff) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final dynamic raw = await SupabaseService.client.rpc('get_my_staff_profile');
      StaffProfile profile = StaffProfile.none;
      if (raw is Map && raw['is_staff'] == true) {
        profile = StaffProfile.fromJson(Map<String, dynamic>.from(raw));
      }

      StaffDashboard? dashboard;
      if (profile.isStaff && profile.has('staff.view_hub')) {
        final dynamic dashRaw = await SupabaseService.client.rpc('staff_get_dashboard');
        if (dashRaw is Map && dashRaw['success'] == true) {
          dashboard = StaffDashboard.fromJson(Map<String, dynamic>.from(dashRaw));
        }
      }

      state = StaffState(isLoading: false, profile: profile, dashboard: dashboard);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  bool can(String permission) => state.profile.has(permission);
}

final staffProvider = NotifierProvider<StaffNotifier, StaffState>(StaffNotifier.new);
