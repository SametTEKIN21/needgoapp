import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_client.dart';

/// Web'deki `needgo-mesaj-son-goruldu` localStorage anahtarının mobil karşılığı.
const _sonGorulduAnahtar = 'needgo-mesaj-son-goruldu';

/// Mesajlar ekranına girildiğinde "şu ana kadar görüldü" damgası basılır.
Future<void> mesajlariGorulduIsaretle() async {
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_sonGorulduAnahtar, DateTime.now().toUtc().toIso8601String());
  } catch (_) {}
}

/// Kullanıcının okunmamış (kendi göndermediği, son görülmeden sonra gelen) mesaj sayısı.
Future<int> okunmamisMesajSayisi(String? uid) async {
  if (uid == null) return 0;

  try {
    final konusmalar = await supabase
        .from('konusmalar')
        .select('id')
        .or('gonderen_id.eq.$uid,alici_id.eq.$uid');

    final ids = (konusmalar as List)
        .map((k) => (k as Map)['id'] as String)
        .toList();
    if (ids.isEmpty) return 0;

    var sonGoruldu = '1970-01-01T00:00:00Z';
    try {
      final sp = await SharedPreferences.getInstance();
      sonGoruldu = sp.getString(_sonGorulduAnahtar) ?? sonGoruldu;
    } catch (_) {}

    final yeniMesajlar = await supabase
        .from('mesajlar')
        .select('id')
        .inFilter('konusma_id', ids)
        .neq('gonderen_id', uid)
        .gt('olusturulma_tarihi', sonGoruldu);

    return (yeniMesajlar as List).length;
  } catch (_) {
    return 0;
  }
}
