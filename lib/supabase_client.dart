import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://wyuhcrpcuvetffylpzcl.supabase.co';
const supabaseAnonKey = 'sb_publishable_SpkqvSSy2_i0mGSG6mpnAQ__1NNTA0f';

final supabase = Supabase.instance.client;

Future<void> supabaseBaslat() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}