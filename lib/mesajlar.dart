import 'package:flutter/material.dart';
import 'supabase_client.dart';
import 'tema.dart';
import 'mesaj_deposu.dart';
import 'ilan_detay.dart';

AppBar _beyazAppBar(String baslik) => AppBar(
      title: Text(baslik),
      backgroundColor: renkKart,
      foregroundColor: renkInk,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shape: const Border(bottom: BorderSide(color: renkCizgi)),
    );

// ---------------------------------------------------------------------------
// Konuşma listesi
// ---------------------------------------------------------------------------

class MesajlarSayfasi extends StatefulWidget {
  const MesajlarSayfasi({super.key});

  @override
  State<MesajlarSayfasi> createState() => _MesajlarSayfasiState();
}

class _MesajlarSayfasiState extends State<MesajlarSayfasi> {
  List<Map<String, dynamic>> _konusmalar = [];
  bool _yukleniyor = true;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final user = supabase.auth.currentUser;
    _uid = user?.id;

    if (user != null) {
      try {
        final data = await supabase
            .from('konusmalar')
            .select('*, ilanlar(baslik)')
            .or('gonderen_id.eq.${user.id},alici_id.eq.${user.id}')
            .order('olusturulma_tarihi', ascending: false);
        _konusmalar = List<Map<String, dynamic>>.from(data as List);
      } catch (_) {}
    }

    await mesajlariGorulduIsaretle();
    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: renkZemin,
      appBar: _beyazAppBar('Mesajlarım'),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: renkOrman))
          : _uid == null
              ? const Center(
                  child: Text('Bu sayfayı görmek için giriş yapmalısın.'))
              : _konusmalar.isEmpty
                  ? Center(
                      child: Text('Henüz bir mesajlaşman yok.',
                          style: TextStyle(
                              color: renkInk.withOpacity(0.5),
                              fontStyle: FontStyle.italic)))
                  : RefreshIndicator(
                      onRefresh: _yukle,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _konusmalar.length,
                        separatorBuilder: (_, i) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final k = _konusmalar[i];
                          final benBasladim = k['gonderen_id'] == _uid;
                          final baslik =
                              (k['ilanlar'] as Map?)?['baslik'] as String? ??
                                  'İlan';
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MesajDetaySayfasi(
                                    konusmaId: k['id'] as String,
                                    ilanId: k['ilan_id'] as String,
                                    ilanBasligi: baslik,
                                  ),
                                ),
                              );
                              _yukle();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: renkKart,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: renkCizgi),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(baslik,
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: renkInk)),
                                        const SizedBox(height: 2),
                                        Text(
                                          benBasladim
                                              ? 'Sen mesaj gönderdin'
                                              : 'Sana mesaj geldi',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: renkInk.withOpacity(0.5)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      color: renkInk.withOpacity(0.3)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tek konuşma
// ---------------------------------------------------------------------------

class MesajDetaySayfasi extends StatefulWidget {
  final String konusmaId;
  final String ilanId;
  final String ilanBasligi;

  const MesajDetaySayfasi({
    super.key,
    required this.konusmaId,
    required this.ilanId,
    required this.ilanBasligi,
  });

  @override
  State<MesajDetaySayfasi> createState() => _MesajDetaySayfasiState();
}

class _MesajDetaySayfasiState extends State<MesajDetaySayfasi> {
  final _girdi = TextEditingController();
  final _kaydirma = ScrollController();
  List<Map<String, dynamic>> _mesajlar = [];
  bool _yukleniyor = true;
  bool _gonderiliyor = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = supabase.auth.currentUser?.id;
    _mesajlariGetir().then((_) {
      if (mounted) setState(() => _yukleniyor = false);
    });
  }

  Future<void> _mesajlariGetir() async {
    try {
      final data = await supabase
          .from('mesajlar')
          .select('*')
          .eq('konusma_id', widget.konusmaId)
          .order('olusturulma_tarihi', ascending: true);
      _mesajlar = List<Map<String, dynamic>>.from(data as List);
    } catch (_) {}
    await mesajlariGorulduIsaretle();
    if (mounted) setState(() {});
    _sonaKaydir();
  }

  void _sonaKaydir() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_kaydirma.hasClients) {
        _kaydirma.animateTo(
          _kaydirma.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _gonder() async {
    final metin = _girdi.text.trim();
    if (metin.isEmpty || _uid == null) return;

    setState(() => _gonderiliyor = true);
    try {
      await supabase.from('mesajlar').insert({
        'konusma_id': widget.konusmaId,
        'gonderen_id': _uid,
        'icerik': metin,
      });
      _girdi.clear();
      await _mesajlariGetir();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gönderilemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  void dispose() {
    _girdi.dispose();
    _kaydirma.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: renkZemin,
      appBar: AppBar(
        title: Text(widget.ilanBasligi, overflow: TextOverflow.ellipsis),
        backgroundColor: renkKart,
        foregroundColor: renkInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shape: const Border(bottom: BorderSide(color: renkCizgi)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => IlanDetay(ilanId: widget.ilanId))),
            child: const Text('İlanı Gör', style: TextStyle(color: renkOrman)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _yukleniyor
                ? const Center(
                    child: CircularProgressIndicator(color: renkOrman))
                : _mesajlar.isEmpty
                    ? Center(
                        child: Text('Henüz mesaj yok. İlk mesajı sen gönder.',
                            style: TextStyle(
                                color: renkInk.withOpacity(0.5),
                                fontStyle: FontStyle.italic)))
                    : ListView.builder(
                        controller: _kaydirma,
                        padding: const EdgeInsets.all(16),
                        itemCount: _mesajlar.length,
                        itemBuilder: (context, i) {
                          final m = _mesajlar[i];
                          final benimMi = m['gonderen_id'] == _uid;
                          return Align(
                            alignment: benimMi
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: benimMi ? renkOrman : renkKart,
                                borderRadius: BorderRadius.circular(12),
                                border: benimMi
                                    ? null
                                    : Border.all(color: renkCizgi),
                              ),
                              child: Text(
                                m['icerik'] as String? ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      benimMi ? Colors.white : const Color(0xFF111111),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: renkKart,
              border: Border(top: BorderSide(color: renkCizgi)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _girdi,
                      style: const TextStyle(color: Color(0xFF111111)),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _gonder(),
                      decoration: InputDecoration(
                        hintText: 'Mesaj yaz…',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: renkCizgi),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _gonderiliyor ? null : _gonder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: renkOcre,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Gönder',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
