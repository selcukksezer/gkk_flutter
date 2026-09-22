class AppConstants {
  const AppConstants._();

  static const String appName = 'GKK';
  static const String defaultLocale = 'tr_TR';

  /// Custom scheme for auth email / OAuth callbacks (password reset, confirm).
  /// Must also be allow-listed in Supabase Dashboard → Auth → URL Configuration.
  static const String authRedirectUrl = 'gkk://auth-callback';

  /// Override via `--dart-define=SUPABASE_URL=...` / `SUPABASE_ANON_KEY=...`.
  /// Defaults keep local `flutter run` working without extra flags.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://znvsyzstmxhqvdkkmgdt.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudnN5enN0bXhocXZka2ttZ2R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0MzIyODUsImV4cCI6MjA4MzAwODI4NX0.uXjfsk_VnhQ8Ri9Fwg_tY_pUf1xuF5G-dgRSRRAJV5I',
  );
}
