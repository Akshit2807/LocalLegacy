import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Replace these with your actual Supabase project credentials
  static const String supabaseUrl = 'https://gnjcdxbhodvjtohlmaoo.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImduamNkeGJob2R2anRvaGxtYW9vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg2MTY3NjcsImV4cCI6MjA2NDE5Mjc2N30.JVyWNh4kyhH9VxrQLmS8VYbpkAnEjIe_9Poh4uUaUps';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
}

// Helper to get Supabase client
SupabaseClient get supabase => Supabase.instance.client;