import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import 'tema.dart';
import 'kota.dart';

class _Aday {
  final String gonderenId;
  final String? gonderenEposta;
  final bool kotaDolu;
  const _Aday(this.gonderenId, this.gonderenEposta, this.kotaDolu);
}

class Ilanlarim extends StatefulWidget {
  const Ilanlarim({super.key});

  @override
  State<Ilanlarim> createState() => _IlanlarimState();
}

class _IlanlarimState extends State<Ilanlarim> {
  List<Map<String, dynamic>> _ilanlar = [];
  bool _yukleniyor = true;
  String? _islemdekiId;

  String? _bagisPaneliId;
  List<_Aday> _adaylar = [];
  String? _seciliAlici;
  bool _panelYukleniyor = false;
  String _bagisHata = '';

  @override
  void initState() {
    super.initState();
    _ilanlariGetir();
  }

  Future<void> _ilanlariGetir() async {
    final kullanici = supabase.auth.currentUser;
    if (kullanici == null) {
      setState(() => _yukleniyor = false);
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      final data = await supabase
          .from('ilanlar')
          .select()
          .eq('user_id', kullanici.id)
          .order('olusturulma_tarihi', ascending: false);

      setState(() {
        _ilanlar = List<Map<String, dynamic>>.from(data as List);
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _durumDegistir(String id, String yeniDurum) async {
    setState(() => _islemdekiId = id);

    try {
      final guncelleme = yeniDurum == 'aktif'
          ? {'durum': 'aktif', 'alici_id': null, 'bagis_tarihi': null}
          : {'durum': yeniDurum};
      await supabase.from('ilanlar').update(guncelleme).eq('id', id);
      setState(() {
        final index = _ilanlar.indexWhere((i) => i['id'] == id);
        if (index != -1) _ilanlar[index]['durum'] = yeniDurum;
      });
    } catch (e) {
      // sessizce yoksay
    } finally {
      setState(() => _islemdekiId = null);
    }
  }

  void _bagisPaneliKapat() {
    setState(() {
      _bagisPaneliId = null;
      _adaylar = [];
      _seciliAlici = null;
      _bagisHata = '';
    });
  }

  Future<void> _bagisPaneliAc(String ilanId) async {
    setState(() {
      _bagisHata = '';
      _seciliAlici = null;
      _bagisPaneliId = ilanId;
      _adaylar = [];
      _panelYukleniyor = true;
    });

    try {
      final data = await supabase
          .from('konusmalar')
          .select('gonderen_id, gonderen_email')
          .eq('ilan_id', ilanId);

      final benzersiz = <String, String?>{};
      for (final k in (data as List)) {
        final m = k as Map;
        final gid = m['gonderen_id'] as String;
        benzersiz.putIfAbsent(gid, () => m['gonderen_email'] as String?);
      }

      final liste = <_Aday>[];
      for (final e in benzersiz.entries) {
        final dolu = (await alinanEsyaSayisi(e.key)) >= aylikAlmaHakki;
        liste.add(_Aday(e.key, e.value, dolu));
      }

      if (mounted) {
        setState(() {
          _adaylar = liste;
          _panelYukleniyor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _panelYukleniyor = false;
          _bagisHata = 'Alıcılar yüklenemedi.';
        });
      }
    }
  }

  Future<void> _bagisOnayla(String ilanId) async {
    if (_seciliAlici == null) return;
    setState(() {
      _bagisHata = '';
      _islemdekiId = ilanId;
    });

    try {
      await supabase.from('ilanlar').update({
        'durum': 'bagislandi',
        'alici_id': _seciliAlici,
        'bagis_tarihi': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', ilanId);

      setState(() {
        final index = _ilanlar.indexWhere((i) => i['id'] == ilanId);
        if (index != -1) _ilanlar[index]['durum'] = 'bagislandi';
        _islemdekiId = null;
      });
      _bagisPaneliKapat();
    } on PostgrestException catch (e) {
      setState(() {
        _islemdekiId = null;
        _bagisHata = e.message.contains('KOTA_DOLU')
            ? 'Bu kişi son 30 günde zaten 3 eşya aldı, şu an bağış yapılamaz.'
            : 'Kaydedilemedi: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _islemdekiId = null;
        _bagisHata = 'Kaydedilemedi: $e';
      });
    }
  }

  Future<void> _bagisAliciSiz(String ilanId) async {
    await _durumDegistir(ilanId, 'bagislandi');
    _bagisPaneliKapat();
  }

  Future<void> _ilanSil(String id) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı sil'),
        content: const Text('Bu ilanı kalıcı olarak silmek istediğine emin misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: renkHata)),
          ),
        ],
      ),
    );

    if (onay != true) return;

    setState(() => _islemdekiId = id);

    try {
      await supabase.from('ilanlar').delete().eq('id', id);
      setState(() => _ilanlar.removeWhere((i) => i['id'] == id));
    } catch (e) {
      // sessizce yoksay
    } finally {
      setState(() => _islemdekiId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: renkZemin,
      appBar: AppBar(
        title: const Text('İlanlarım'),
        backgroundColor: renkKart,
        foregroundColor: renkInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shape: const Border(bottom: BorderSide(color: renkCizgi)),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: renkOrman))
          : _ilanlar.isEmpty
              ? const Center(child: Text('Henüz ilan vermedin.'))
              : RefreshIndicator(
                  onRefresh: _ilanlariGetir,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _ilanlar.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _ilanKarti(_ilanlar[index]),
                  ),
                ),
    );
  }

  Widget _ilanKarti(Map<String, dynamic> ilan) {
    final id = ilan['id'] as String;
    final aktifMi = ilan['durum'] != 'bagislandi';
    final baslik = ilan['baslik'] as String? ?? '';
    final kategori = ilan['kategori'] as String?;
    final fotografUrl = ilan['fotograf_url'] as String?;
    final goruntulenme = (ilan['goruntulenme_sayisi'] as int?) ?? 0;
    final begeni = (ilan['begeni_sayisi'] as int?) ?? 0;
    final islemVar = _islemdekiId == id;
    final panelAcik = _bagisPaneliId == id;

    return Container(
      decoration: BoxDecoration(
        color: renkKart,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renkCizgi.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: fotografUrl != null
                      ? Image.network(
                          fotografUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => _ng(),
                        )
                      : _ng(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: aktifMi
                            ? renkOrman.withOpacity(0.1)
                            : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        aktifMi ? 'AKTİF' : 'BAĞIŞLANDI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: aktifMi ? renkOrman : Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(baslik,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: renkInk)),
                    if (kategori != null)
                      Text(kategori,
                          style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text('👁 $goruntulenme   ♥ $begeni',
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (aktifMi)
                          _kucukButon(
                            'Bağışlandı İşaretle',
                            renkOrman,
                            Colors.white,
                            islemVar
                                ? null
                                : () => panelAcik
                                    ? _bagisPaneliKapat()
                                    : _bagisPaneliAc(id),
                          )
                        else
                          _kucukButon(
                            'Yeniden Yayınla',
                            Colors.white,
                            renkOrman,
                            islemVar ? null : () => _durumDegistir(id, 'aktif'),
                            kenarRengi: renkOrman,
                          ),
                        _kucukButon(
                          'Sil',
                          Colors.white,
                          renkHata,
                          islemVar ? null : () => _ilanSil(id),
                          kenarRengi: renkHata,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (panelAcik) ...[
            const SizedBox(height: 12),
            _bagisPaneli(id),
          ],
        ],
      ),
    );
  }

  Widget _bagisPaneli(String ilanId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: renkZemin,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renkCizgi),
      ),
      child: _panelYukleniyor
          ? Text('Yükleniyor…',
              style: TextStyle(fontSize: 12, color: renkInk.withOpacity(0.5)))
          : _adaylar.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bu ilana kimse mesaj atmadı. Alıcısız işaretlersen kimseye kota işlenmez.',
                      style: TextStyle(fontSize: 12, color: renkInk.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _kucukButon('Alıcısız işaretle', renkOrman, Colors.white,
                            () => _bagisAliciSiz(ilanId)),
                        const SizedBox(width: 8),
                        _kucukButon('Vazgeç', Colors.white, renkInk,
                            _bagisPaneliKapat,
                            kenarRengi: renkInk.withOpacity(0.2)),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kime bağışladın?',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: renkInk)),
                    const SizedBox(height: 4),
                    for (final aday in _adaylar)
                      RadioListTile<String>(
                        value: aday.gonderenId,
                        groupValue: _seciliAlici,
                        onChanged: aday.kotaDolu
                            ? null
                            : (v) => setState(() => _seciliAlici = v),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          (aday.gonderenEposta ??
                                  aday.gonderenId.substring(0, 8)) +
                              (aday.kotaDolu ? ' — kota dolu' : ''),
                          style: TextStyle(
                            fontSize: 12,
                            color: aday.kotaDolu
                                ? renkInk.withOpacity(0.4)
                                : renkInk,
                          ),
                        ),
                      ),
                    if (_bagisHata.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_bagisHata,
                            style: const TextStyle(fontSize: 12, color: renkHata)),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _kucukButon(
                          'Onayla',
                          renkOrman,
                          Colors.white,
                          (_seciliAlici == null || _islemdekiId == ilanId)
                              ? null
                              : () => _bagisOnayla(ilanId),
                        ),
                        const SizedBox(width: 8),
                        _kucukButon('Vazgeç', Colors.white, renkInk,
                            _bagisPaneliKapat,
                            kenarRengi: renkInk.withOpacity(0.2)),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _ng() => Container(
        color: renkGorselZemin,
        alignment: Alignment.center,
        child: const Text('NG', style: TextStyle(color: Colors.black26)),
      );

  Widget _kucukButon(
    String metin,
    Color arkaPlan,
    Color yaziRengi,
    VoidCallback? onTap, {
    Color? kenarRengi,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: arkaPlan,
            borderRadius: BorderRadius.circular(16),
            border: kenarRengi != null ? Border.all(color: kenarRengi) : null,
          ),
          child: Text(
            metin,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: yaziRengi),
          ),
        ),
      ),
    );
  }
}
