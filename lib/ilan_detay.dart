import 'package:flutter/material.dart';
import 'supabase_client.dart';
import 'tema.dart';
import 'kota.dart';
import 'profil_kontrol.dart';
import 'profil.dart';
import 'mesajlar.dart';

class IlanDetay extends StatefulWidget {
  final String ilanId;

  const IlanDetay({super.key, required this.ilanId});

  @override
  State<IlanDetay> createState() => _IlanDetayState();
}

class _IlanDetayState extends State<IlanDetay> {
  Map<String, dynamic>? _ilan;
  bool _yukleniyor = true;
  bool _begenildi = false;
  int _aktifFoto = 0;
  bool _sayacArtirildi = false;

  KotaDurumu? _kota;
  String? _mevcutKonusmaId;
  bool _mesajIslemde = false;
  String _mesajHata = '';

  @override
  void initState() {
    super.initState();
    _getir();
  }

  Future<void> _getir() async {
    try {
      final veri = await supabase
          .from('ilanlar')
          .select()
          .eq('id', widget.ilanId)
          .single();

      setState(() {
        _ilan = veri;
        _yukleniyor = false;
      });

      final kullanici = supabase.auth.currentUser;
      if (kullanici != null && veri['user_id'] != kullanici.id) {
        kotaDurumu(kullanici.id).then((k) {
          if (mounted) setState(() => _kota = k);
        }).catchError((_) {});
        try {
          final k = await supabase
              .from('konusmalar')
              .select('id')
              .eq('ilan_id', widget.ilanId)
              .eq('gonderen_id', kullanici.id)
              .maybeSingle();
          if (mounted && k != null) {
            setState(() => _mevcutKonusmaId = k['id'] as String);
          }
        } catch (_) {}
      }

      if (!_sayacArtirildi) {
        _sayacArtirildi = true;
        final yeniGoruntulenme = ((veri['goruntulenme_sayisi'] as int?) ?? 0) + 1;
        await supabase
            .from('ilanlar')
            .update({'goruntulenme_sayisi': yeniGoruntulenme})
            .eq('id', widget.ilanId);
      }
    } catch (e) {
      setState(() {
        _yukleniyor = false;
      });
    }
  }

  Future<void> _begen() async {
    if (_ilan == null || _begenildi) return;

    final yeniBegeni = ((_ilan!['begeni_sayisi'] as int?) ?? 0) + 1;
    try {
      await supabase
          .from('ilanlar')
          .update({'begeni_sayisi': yeniBegeni})
          .eq('id', widget.ilanId);

      setState(() {
        _ilan!['begeni_sayisi'] = yeniBegeni;
        _begenildi = true;
      });
    } catch (e) {
      // sessizce yoksay
    }
  }

  void _sohbeteGit(String konusmaId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MesajDetaySayfasi(
        konusmaId: konusmaId,
        ilanId: widget.ilanId,
        ilanBasligi: _ilan?['baslik'] as String? ?? 'İlan',
      ),
    ));
  }

  Future<void> _mesajGonder() async {
    final kullanici = supabase.auth.currentUser;
    if (_ilan == null || kullanici == null) return;

    setState(() {
      _mesajHata = '';
      _mesajIslemde = true;
    });

    // Mevcut sohbet varsa oraya dön (kota/profil engeli yok)
    if (_mevcutKonusmaId != null) {
      setState(() => _mesajIslemde = false);
      _sohbeteGit(_mevcutKonusmaId!);
      return;
    }

    // Yeni istek — profil eksikse önce profile yönlendir
    if (!profilTamMi(kullanici)) {
      setState(() => _mesajIslemde = false);
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ProfilSayfasi()));
      return;
    }

    // Yeni istek — kota dolu ise engelle
    if (_kota != null && _kota!.kalan == 0) {
      setState(() {
        _mesajIslemde = false;
        _mesajHata = _kota!.yenilenmeTarihi != null
            ? 'Son 30 günde 3 eşya aldın. Yeni istek gönderebilmen için ${tarihMetni(_kota!.yenilenmeTarihi)} tarihini beklemelisin.'
            : 'Son 30 günde 3 eşya aldın. Yeni istek gönderemezsin.';
      });
      return;
    }

    try {
      final yeni = await supabase
          .from('konusmalar')
          .insert({
            'ilan_id': widget.ilanId,
            'gonderen_id': kullanici.id,
            'alici_id': _ilan!['user_id'],
            'gonderen_email': kullanici.email,
          })
          .select('id')
          .single();

      if (!mounted) return;
      setState(() {
        _mesajIslemde = false;
        _mevcutKonusmaId = yeni['id'] as String;
      });
      _sohbeteGit(yeni['id'] as String);
    } catch (e) {
      setState(() {
        _mesajIslemde = false;
        _mesajHata = 'Bir hata oluştu: $e';
      });
    }
  }

  List<String> get _fotoListesi {
    if (_ilan == null) return [];
    final fotograflar = _ilan!['fotograflar'];
    if (fotograflar is List && fotograflar.isNotEmpty) {
      return fotograflar.map((e) => e.toString()).toList();
    }
    final tekFoto = _ilan!['fotograf_url'] as String?;
    if (tekFoto != null) return [tekFoto];
    return [];
  }

  AppBar _appBar() {
    return AppBar(
      title: const Text('İlan Detayı'),
      backgroundColor: renkKart,
      foregroundColor: renkInk,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shape: const Border(bottom: BorderSide(color: renkCizgi)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: renkOrman)),
      );
    }

    if (_ilan == null) {
      return Scaffold(
        appBar: _appBar(),
        body: const Center(child: Text('İlan bulunamadı.')),
      );
    }

    final fotolar = _fotoListesi;
    final baslik = _ilan!['baslik'] as String? ?? '';
    final aciklama = _ilan!['aciklama'] as String?;
    final kategori = _ilan!['kategori'] as String?;
    final konum = _ilan!['konum'] as String?;
    final goruntulenme = (_ilan!['goruntulenme_sayisi'] as int?) ?? 0;
    final begeni = (_ilan!['begeni_sayisi'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: renkZemin,
      appBar: _appBar(),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                fotolar.isNotEmpty
                    ? Image.network(
                        fotolar[_aktifFoto],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: renkGorselZemin,
                          alignment: Alignment.center,
                          child: const Text('NG', style: TextStyle(fontSize: 40, color: Colors.black26)),
                        ),
                      )
                    : Container(
                        color: renkGorselZemin,
                        alignment: Alignment.center,
                        child: const Text('NG', style: TextStyle(fontSize: 40, color: Colors.black26)),
                      ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Transform.rotate(
                    angle: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Ücretsiz',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: renkInk),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (fotolar.length > 1)
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: fotolar.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final aktif = index == _aktifFoto;
                  return GestureDetector(
                    onTap: () => setState(() => _aktifFoto = index),
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: aktif ? renkOrman : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(fotolar[index], fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        baslik,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: renkInk),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _begenildi ? null : _begen,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _begenildi ? renkOrman : renkInk,
                        side: BorderSide(color: _begenildi ? renkOrman : Colors.black26),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(_begenildi ? '♥ $begeni' : '♡ $begeni'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (kategori != null) Text(kategori, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    if (konum != null) Text('· $konum', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    Text('· $goruntulenme görüntülenme', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
                if (aciklama != null && aciklama.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(aciklama, style: const TextStyle(fontSize: 14, height: 1.5, color: renkInk)),
                ],
                const SizedBox(height: 24),
                const Divider(color: renkCizgi, height: 1),
                const SizedBox(height: 16),
                _mesajBolumu(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mesajBolumu() {
    final kullanici = supabase.auth.currentUser;

    if (kullanici == null) {
      return Text(
        'İlan sahibiyle mesajlaşmak için giriş yapmalısın.',
        style: TextStyle(fontSize: 12, color: renkInk.withOpacity(0.5)),
      );
    }

    if (_ilan!['user_id'] == kullanici.id) {
      return Text(
        'Bu senin kendi ilanın.',
        style: TextStyle(fontSize: 12, color: renkInk.withOpacity(0.5)),
      );
    }

    final mevcutSohbet = _mevcutKonusmaId != null;
    final profilEksik = !profilTamMi(kullanici) && !mevcutSohbet;
    final kotaDolu = !profilEksik &&
        !mevcutSohbet &&
        _kota != null &&
        _kota!.kalan == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: (_mesajIslemde || kotaDolu || profilEksik) ? null : _mesajGonder,
          style: ElevatedButton.styleFrom(
            backgroundColor: renkOrman,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Text(
            _mesajIslemde
                ? 'Açılıyor…'
                : mevcutSohbet
                    ? 'Sohbete Dön'
                    : 'Mesaj Gönder',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (profilEksik) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfilSayfasi())),
            child: const Text(
              'Mesaj göndermeden önce profil bilgilerini tamamlamalısın.',
              style: TextStyle(
                fontSize: 12,
                color: renkHata,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
        if (kotaDolu) ...[
          const SizedBox(height: 8),
          Text(
            _kota!.yenilenmeTarihi != null
                ? 'Son 30 günde 3 eşya aldın. Yeni istek gönderebilmen için ${tarihMetni(_kota!.yenilenmeTarihi)} tarihini beklemelisin.'
                : 'Son 30 günde 3 eşya aldın. Yeni istek gönderemezsin.',
            style: const TextStyle(fontSize: 12, color: renkHata),
          ),
        ],
        if (!kotaDolu && _mesajHata.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_mesajHata, style: const TextStyle(fontSize: 12, color: renkHata)),
        ],
        if (!kotaDolu &&
            !mevcutSohbet &&
            _kota != null &&
            _kota!.kalan > 0 &&
            _kota!.kalan < 3) ...[
          const SizedBox(height: 8),
          Text(
            'Kalan alma hakkın: ${_kota!.kalan}/3 (son 30 gün)',
            style: TextStyle(fontSize: 12, color: renkInk.withOpacity(0.5)),
          ),
        ],
      ],
    );
  }
}