import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// Web `app/lib/kota.ts` ile aynı: bir hesap son 30 günde en fazla 3 eşya alabilir.
const aylikAlmaHakki = 3;

class KotaDurumu {
  final int alinan;
  final int kalan;
  final DateTime? yenilenmeTarihi;

  const KotaDurumu({
    required this.alinan,
    required this.kalan,
    this.yenilenmeTarihi,
  });
}

/// Bir hesabın son 30 gündeki eşya alma kotası durumu.
Future<KotaDurumu> kotaDurumu(String uid) async {
  int alinan = 0;
  try {
    final sayi = await supabase.rpc('alinan_esya_sayisi', params: {'kisi': uid});
    if (sayi is int) alinan = sayi;
  } on PostgrestException {
    // kota-limiti.sql henüz çalıştırılmadıysa RPC yok — kotayı boş say
  }

  final kalan = (aylikAlmaHakki - alinan) < 0 ? 0 : aylikAlmaHakki - alinan;

  DateTime? yenilenmeTarihi;
  if (kalan == 0) {
    try {
      final tarih =
          await supabase.rpc('kota_yenilenme_tarihi', params: {'kisi': uid});
      if (tarih is String) yenilenmeTarihi = DateTime.tryParse(tarih);
    } on PostgrestException {
      // yoksa geç
    }
  }

  return KotaDurumu(alinan: alinan, kalan: kalan, yenilenmeTarihi: yenilenmeTarihi);
}

/// Belirli bir kişinin son 30 günde aldığı eşya sayısı (bağış alıcı listesi için).
Future<int> alinanEsyaSayisi(String uid) async {
  try {
    final data = await supabase.rpc('alinan_esya_sayisi', params: {'kisi': uid});
    if (data is int) return data;
  } on PostgrestException {
    // yoksa 0
  }
  return 0;
}

const _aylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

String tarihMetni(DateTime? tarih) {
  if (tarih == null) return '';
  final t = tarih.toLocal();
  return '${t.day} ${_aylar[t.month - 1]} ${t.year}';
}
