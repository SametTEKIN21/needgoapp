import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { AppState, Platform } from 'react-native';
import { createClient } from '@supabase/supabase-js';

export const supabaseUrl = 'https://wyuhcrpcuvetffylpzcl.supabase.co';
export const supabaseAnonKey = 'sb_publishable_SpkqvSSy2_i0mGSG6mpnAQ__1NNTA0f';

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});

// Supabase önerisi: uygulama ön plandayken token'ı otomatik yenile, arka planda durdur.
if (Platform.OS !== 'web') {
  AppState.addEventListener('change', (state) => {
    if (state === 'active') {
      supabase.auth.startAutoRefresh();
    } else {
      supabase.auth.stopAutoRefresh();
    }
  });
}
