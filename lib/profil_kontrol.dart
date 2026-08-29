import 'package:supabase_flutter/supabase_flutter.dart';

/// Web `app/lib/profil.ts` ile aynı zorunlu profil alanları.
const profilAlanlari = ['ad', 'soyad', 'telefon', 'adres', 'iletisim_eposta'];

/// Kullanıcının zorunlu profil alanları (ad, soyad, telefon, adres, e-posta) dolu mu?
bool profilTamMi(User? user) {
  if (user == null) return false;
  final m = user.userMetadata ?? const {};
  return profilAlanlari.every((alan) {
    final v = m[alan];
    return v is String && v.trim().isNotEmpty;
  });
}
