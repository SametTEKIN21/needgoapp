import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import 'tema.dart';
import 'kota.dart';

class ProfilAlan {
  final String anahtar;
  final String etiket;
  final bool cokSatir;
  final TextInputType klavye;
  const ProfilAlan(this.anahtar, this.etiket,
      {this.cokSatir = false, this.klavye = TextInputType.text});
}

const _alanlar = [
  ProfilAlan('ad', 'Ad'),
  ProfilAlan('soyad', 'Soyad'),
  ProfilAlan('telefon', 'Telefon', klavye: TextInputType.phone),
  ProfilAlan('iletisim_eposta', 'E-posta', klavye: TextInputType.emailAddress),
  ProfilAlan('adres', 'Adres', cokSatir: true),
];

class ProfilSayfasi extends StatefulWidget {
  const ProfilSayfasi({super.key});

  @override
  State<ProfilSayfasi> createState() => _ProfilSayfasiState();
}

class _ProfilSayfasiState extends State<ProfilSayfasi> {
  final Map<String, TextEditingController> _kontrolorler = {
    for (final a in _alanlar) a.anahtar: TextEditingController(),
  };

  User? _kullanici;
  bool _kontrolBitti = false;
  bool _duzenleme = true;
  Map<String, String>? _kayitli;
  bool _kaydediliyor = false;
  String _hata = '';
  KotaDurumu? _kota;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final user = supabase.auth.currentUser;
    _kullanici = user;
    final m = user?.userMetadata ?? const {};

    for (final a in _alanlar) {
      var deger = (m[a.anahtar] as String?) ?? '';
      if (a.anahtar == 'iletisim_eposta' && deger.isEmpty) {
        deger = user?.email ?? '';
      }
      _kontrolorler[a.anahtar]!.text = deger;
    }

    final tam = _formTamMi();
    _duzenleme = !tam;
    if (tam) _kayitli = _formDegerleri();

    setState(() => _kontrolBitti = true);

    if (user != null) {
      try {
        final k = await kotaDurumu(user.id);
        if (mounted) setState(() => _kota = k);
      } catch (_) {}
    }
  }

  Map<String, String> _formDegerleri() =>
      {for (final a in _alanlar) a.anahtar: _kontrolorler[a.anahtar]!.text.trim()};

  bool _formTamMi() =>
      _alanlar.every((a) => _kontrolorler[a.anahtar]!.text.trim().isNotEmpty);

  Future<void> _kaydet() async {
    setState(() => _hata = '');
    final temiz = _formDegerleri();

    if (!_formTamMi()) {
      setState(() => _hata = 'Tüm alanları doldurman gerekiyor.');
      return;
    }

    setState(() => _kaydediliyor = true);
    try {
      await supabase.auth.updateUser(UserAttributes(data: temiz));
      if (!mounted) return;
      Navigator.of(context).pop(true); // ana sayfaya dön
    } catch (e) {
      setState(() {
        _kaydediliyor = false;
        _hata = 'Kaydedilemedi: $e';
      });
    }
  }

  @override
  void dispose() {
    for (final c in _kontrolorler.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: renkZemin,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: renkKart,
        foregroundColor: renkInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shape: const Border(bottom: BorderSide(color: renkCizgi)),
      ),
      body: !_kontrolBitti
          ? const Center(child: CircularProgressIndicator(color: renkOrman))
          : _kullanici == null
              ? const Center(
                  child: Text('Bu sayfayı görmek için giriş yapmalısın.'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Bu bilgiler seninle iletişim kurmak isteyenler için kullanılır ve zorunludur.',
                      style: TextStyle(
                          fontSize: 13, color: renkInk.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 20),
                    if (_kota != null) _kotaKarti(_kota!),
                    if (_kota != null) const SizedBox(height: 20),
                    if (!_duzenleme && _kayitli != null)
                      _ozet(_kayitli!)
                    else
                      _form(),
                  ],
                ),
    );
  }

  Widget _kotaKarti(KotaDurumu kota) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkKart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renkCizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Eşya alma hakkın',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: renkInk)),
          const SizedBox(height: 4),
          Text(
            'Son 30 günde ${kota.alinan} eşya aldın · kalan hakkın ${kota.kalan}/$aylikAlmaHakki',
            style: TextStyle(fontSize: 13, color: renkInk.withOpacity(0.7)),
          ),
          if (kota.kalan == 0 && kota.yenilenmeTarihi != null) ...[
            const SizedBox(height: 4),
            Text(
              'Hakların ${tarihMetni(kota.yenilenmeTarihi)} tarihinden itibaren yenilenmeye başlar.',
              style: TextStyle(fontSize: 11, color: renkInk.withOpacity(0.5)),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Fırsatçılığı önlemek için her hesap 30 günde en fazla $aylikAlmaHakki eşya alabilir.',
            style: TextStyle(fontSize: 11, color: renkInk.withOpacity(0.45)),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkKart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renkCizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in _alanlar) ...[
            Text('${a.etiket} *',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: renkInk)),
            const SizedBox(height: 6),
            TextField(
              controller: _kontrolorler[a.anahtar],
              keyboardType: a.klavye,
              maxLines: a.cokSatir ? 3 : 1,
              style: const TextStyle(color: Color(0xFF111111)),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: renkCizgi),
                ),
              ),
            ),
            if (a.anahtar == 'iletisim_eposta')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Giriş e-postan: ${_kullanici?.email ?? '-'}',
                    style: TextStyle(
                        fontSize: 11, color: renkInk.withOpacity(0.45))),
              ),
            const SizedBox(height: 14),
          ],
          if (_hata.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_hata,
                  style: const TextStyle(fontSize: 12, color: renkHata)),
            ),
          Row(
            children: [
              ElevatedButton(
                onPressed: _kaydediliyor ? null : _kaydet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: renkOrman,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(_kaydediliyor ? 'Kaydediliyor…' : 'Kaydet',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (_kayitli != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    for (final a in _alanlar) {
                      _kontrolorler[a.anahtar]!.text = _kayitli![a.anahtar] ?? '';
                    }
                    setState(() {
                      _hata = '';
                      _duzenleme = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: renkInk,
                    side: BorderSide(color: renkInk.withOpacity(0.2)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('Vazgeç'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _ilkHarf(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? '' : t.characters.first;
  }

  Widget _ozet(Map<String, String> k) {
    final bas = _ilkHarf(k['ad']) + _ilkHarf(k['soyad']);
    Widget satir(IconData ikon, String etiket, String deger) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ikon, size: 18, color: renkOrman),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etiket,
                        style: TextStyle(
                            fontSize: 11, color: renkInk.withOpacity(0.45))),
                    const SizedBox(height: 2),
                    Text(deger,
                        style: const TextStyle(fontSize: 14, color: renkInk)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: renkKart,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renkCizgi),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: renkOrman.withOpacity(0.06),
              border: const Border(bottom: BorderSide(color: renkCizgi)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration:
                      const BoxDecoration(color: renkOrman, shape: BoxShape.circle),
                  child: Text(bas.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${k['ad']} ${k['soyad']}',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: renkInk)),
                      Text('NeedGO üyesi',
                          style: TextStyle(
                              fontSize: 11, color: renkInk.withOpacity(0.5))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
            child: Column(
              children: [
                satir(Icons.phone_outlined, 'Telefon', k['telefon'] ?? ''),
                satir(Icons.mail_outline, 'E-posta', k['iletisim_eposta'] ?? ''),
                satir(Icons.location_on_outlined, 'Adres', k['adres'] ?? ''),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () {
                  for (final a in _alanlar) {
                    _kontrolorler[a.anahtar]!.text = k[a.anahtar] ?? '';
                  }
                  setState(() {
                    _hata = '';
                    _duzenleme = true;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: renkOrman,
                  side: const BorderSide(color: renkOrman),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Düzenle',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
