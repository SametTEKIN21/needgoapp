import 'dart:async';
import 'package:flutter/material.dart';
import 'supabase_client.dart';
import 'tema.dart';
import 'ilan_detay.dart';

const kategoriler = [
  'Mobilya',
  'Elektronik',
  'Ev & Yaşam',
  'Giyim',
  'Aksesuar',
  'Kişisel Bakım & Kozmetik',
  'Oyuncak',
  'Ofis & Kırtasiye',
  'Yapı & Market',
  'Pet Shop',
  'Antika',
];

/// Web `page.tsx` hero slider metinleri.
class HeroSlayt {
  final String eyebrow;
  final String baslik;
  final String aciklama;
  final String? altNot;
  final bool ikiTonluEyebrow;
  const HeroSlayt({
    required this.eyebrow,
    required this.baslik,
    required this.aciklama,
    this.altNot,
    this.ikiTonluEyebrow = false,
  });
}

const heroSlaytlari = [
  HeroSlayt(
    eyebrow: 'Atma · Paylaş · Dönüştür',
    baslik: 'Kullanmadığın eşya, birinin ihtiyacı olsun.',
    aciklama: 'NeedGO’da her şey ücretsiz, sadece paylaşım geçer.',
    altNot: 'Paylaşmak iyileştirir.',
  ),
  HeroSlayt(
    eyebrow: 'Neden NeedGO?',
    ikiTonluEyebrow: true,
    baslik: 'Çevre Koruma ve Sıfır Atık',
    aciklama:
        'Kullanılabilir durumdaki eşyaların çöp sahalarına gitmesini engelleyerek atık oluşumunu azaltır ve karbon ayak izini düşürmeye doğrudan katkı sağlar.',
  ),
  HeroSlayt(
    eyebrow: 'Neden NeedGO?',
    ikiTonluEyebrow: true,
    baslik: 'Döngüsel Ekonomi ve Kaynak Verimliliği',
    aciklama:
        'Eşyaların kullanım ömrünü tek bir sahipten öteye taşıyarak kaynakların yeniden ve verimli bir şekilde değerlendirilmesini destekler.',
  ),
  HeroSlayt(
    eyebrow: 'Neden NeedGO?',
    ikiTonluEyebrow: true,
    baslik: 'Sosyal Dayanışma ve Komşuluk',
    aciklama:
        'İhtiyaç sahibi kişilerle eşya paylaşmak isteyenleri para ve komisyon olmaksızın bir araya getirerek toplumsal dayanışmayı güçlendirir.',
  ),
  HeroSlayt(
    eyebrow: 'Neden NeedGO?',
    ikiTonluEyebrow: true,
    baslik: 'Öğrenci ve Ev Kuracaklara Destek',
    aciklama:
        'Öğrencilerin kitap, ders aracı veya eşya ihtiyaçlarını; yeni eve taşınanların ise mobilya ve ev gereksinimlerini bütçe yükü olmadan karşılamalarına imkan tanır.',
  ),
  HeroSlayt(
    eyebrow: 'Neden NeedGO?',
    ikiTonluEyebrow: true,
    baslik: 'STK ve Kurumsal İhtiyaç Kanalları',
    aciklama:
        'Dernekler, topluluklar veya belediyeler için ihtiyaç sahibi ailelere ulaştırılmak üzere toplu eşya temin edilebilecek sürdürülebilir bir kaynak oluşturur.',
  ),
];

class Ilan {
  final String id;
  final String baslik;
  final String? aciklama;
  final String? kategori;
  final String? konum;
  final String? fotografUrl;

  Ilan({
    required this.id,
    required this.baslik,
    this.aciklama,
    this.kategori,
    this.konum,
    this.fotografUrl,
  });

  factory Ilan.fromMap(Map<String, dynamic> map) {
    return Ilan(
      id: map['id'] as String,
      baslik: map['baslik'] as String? ?? '',
      aciklama: map['aciklama'] as String?,
      kategori: map['kategori'] as String?,
      konum: map['konum'] as String?,
      fotografUrl: map['fotograf_url'] as String?,
    );
  }
}

class IlanListesi extends StatefulWidget {
  const IlanListesi({super.key});

  @override
  State<IlanListesi> createState() => _IlanListesiState();
}

class _IlanListesiState extends State<IlanListesi> {
  List<Ilan> _ilanlar = [];
  bool _yukleniyor = true;
  String _hata = '';
  String? _seciliKategori;
  final _aramaController = TextEditingController();
  String _aramaMetni = '';

  @override
  void initState() {
    super.initState();
    _ilanlariGetir();
    _aramaController.addListener(() {
      setState(() {
        _aramaMetni = _aramaController.text;
      });
    });
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  Future<void> _ilanlariGetir() async {
    setState(() {
      _yukleniyor = true;
      _hata = '';
    });

    try {
      final data = await supabase
          .from('ilanlar')
          .select()
          .eq('durum', 'aktif')
          .order('olusturulma_tarihi', ascending: false);

      final liste = (data as List)
          .map((satir) => Ilan.fromMap(satir as Map<String, dynamic>))
          .toList();

      setState(() {
        _ilanlar = liste;
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _hata = 'İlanlar yüklenemedi: $e';
        _yukleniyor = false;
      });
    }
  }

  void _detayaGit(String ilanId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => IlanDetay(ilanId: ilanId)),
    );
  }

  List<Ilan> get _gosterilenIlanlar {
    return _ilanlar.where((ilan) {
      final kategoriUyuyor = _seciliKategori == null ||
          (ilan.kategori?.toLowerCase() == _seciliKategori!.toLowerCase());
      final aramaUyuyor = _aramaMetni.trim().isEmpty ||
          ilan.baslik.toLowerCase().contains(_aramaMetni.toLowerCase());
      return kategoriUyuyor && aramaUyuyor;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final gosterilenIlanlar = _gosterilenIlanlar;

    return Container(
      color: renkZemin,
      child: RefreshIndicator(
        onRefresh: _ilanlariGetir,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _HeroSlider()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: _aramaController,
                  decoration: InputDecoration(
                    hintText: 'İlan, kategori ara',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: renkCizgi),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _kategoriCip('Tümü', _seciliKategori == null, () {
                      setState(() => _seciliKategori = null);
                    }),
                    const SizedBox(width: 6),
                    for (final kat in kategoriler) ...[
                      _kategoriCip(kat, _seciliKategori == kat, () {
                        setState(() => _seciliKategori = kat);
                      }),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _seciliKategori ?? 'Güncel İlanlar',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: renkInk,
                      ),
                    ),
                    Text(
                      '${gosterilenIlanlar.length} ilan',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            if (_yukleniyor)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: renkOrman)),
              )
            else if (_hata.isNotEmpty)
              SliverFillRemaining(
                child: Center(child: Text(_hata, style: const TextStyle(color: Colors.red))),
              )
            else if (gosterilenIlanlar.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Bu kriterlere uyan ilan yok.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 22,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.60,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => GestureDetector(
                      onTap: () => _detayaGit(gosterilenIlanlar[index].id),
                      child: _IlanKarti(ilan: gosterilenIlanlar[index]),
                    ),
                    childCount: gosterilenIlanlar.length,
                  ),
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }

  Widget _kategoriCip(String etiket, bool aktif, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: aktif ? renkOrman : Colors.white,
          border: Border.all(color: aktif ? renkOrman : renkCizgi),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          etiket,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: aktif ? Colors.white : renkInk.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}

class _IlanKarti extends StatelessWidget {
  final Ilan ilan;

  const _IlanKarti({required this.ilan});

  @override
  Widget build(BuildContext context) {
    final altBilgi = [ilan.konum, ilan.kategori]
        .where((e) => e != null && e.trim().isNotEmpty)
        .join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: renkGorselZemin,
                    child: ilan.fotografUrl != null
                        ? Image.network(
                            ilan.fotografUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _yerTutucu(),
                          )
                        : _yerTutucu(),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_border,
                    size: 17,
                    color: renkInk.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          ilan.baslik,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: renkInk,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Ücretsiz',
          style: TextStyle(fontSize: 13, color: renkInk.withOpacity(0.7)),
        ),
        if (altBilgi.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            altBilgi,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: renkInk.withOpacity(0.4)),
          ),
        ],
      ],
    );
  }

  Widget _yerTutucu() {
    return Container(
      color: renkGorselZemin,
      alignment: Alignment.center,
      child: Opacity(
        opacity: 0.15,
        child: Image.asset('assets/images/needgo-n.png', width: 44, height: 44),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero slider (web page.tsx karşılığı)
// ---------------------------------------------------------------------------

class _HeroSlider extends StatefulWidget {
  const _HeroSlider();

  @override
  State<_HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<_HeroSlider> {
  final _sayfa = PageController();
  int _aktif = 0;
  Timer? _zamanlayici;

  @override
  void initState() {
    super.initState();
    _zamanlayici = Timer.periodic(const Duration(milliseconds: 6500), (_) {
      if (!mounted || !_sayfa.hasClients) return;
      final sonraki = (_aktif + 1) % heroSlaytlari.length;
      _sayfa.animateToPage(
        sonraki,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    _sayfa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [renkNeed.withOpacity(0.10), renkCizgi.withOpacity(0.35)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: PageView.builder(
              controller: _sayfa,
              onPageChanged: (i) => setState(() => _aktif = i),
              itemCount: heroSlaytlari.length,
              itemBuilder: (context, i) => _slaytGovde(heroSlaytlari[i]),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < heroSlaytlari.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _aktif ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _aktif ? renkOrman : renkInk.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slaytGovde(HeroSlayt s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: renkOrman.withOpacity(0.05),
              border: Border.all(color: renkOrman.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: s.ikiTonluEyebrow
                ? Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: 'Neden ',
                          style: TextStyle(color: renkInk.withOpacity(0.7))),
                      const TextSpan(
                          text: 'Need', style: TextStyle(color: renkNeed)),
                      const TextSpan(
                          text: 'GO', style: TextStyle(color: renkGo)),
                      TextSpan(
                          text: '?',
                          style: TextStyle(color: renkInk.withOpacity(0.7))),
                    ]),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                  )
                : Text(
                    s.eyebrow.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: renkOrman,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            s.baslik,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: renkInk,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.aciklama,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: renkInk.withOpacity(0.6)),
          ),
          if (s.altNot != null) ...[
            const SizedBox(height: 8),
            Text(
              s.altNot!,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: renkOrman,
              ),
            ),
          ],
        ],
      ),
    );
  }
}