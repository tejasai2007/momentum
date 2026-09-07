/// Fill these in from your Supabase project settings
/// (Project Settings -> API). Never commit real production keys to a public
/// repo — for a real app, load these from --dart-define or a .env file
/// instead of hardcoding them.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR-PROJECT-REF.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR-SUPABASE-ANON-KEY',
  );
}

class AppConstants {
  static const String journalBucket = 'journal-media';
  static const String widgetAppGroup = 'tickoff_widget'; // used by home_widget
}
