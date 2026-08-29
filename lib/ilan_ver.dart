import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'supabase_client.dart';
import 'tema.dart';

class IlanVer extends StatefulWidget {
  const IlanVer({super.key});

  @override
  State<IlanVer> createState() => _IlanVerState();
}

class _IlanVerState extends State<IlanVer> {
  static const maksFoto = 5;

  final _baslikController = TextEditingController();
  final _aciklamaController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _konumController = TextEditingController();

  final List<XFile> _secilenFotolar = [];
  bool _yukleniyor = false;

  Future<void> _fotografSec() async {
    if (_secilenFotolar.length >= maksFoto) return;

    final picker = ImagePicker();
    final secilenler = await picker.pickMultiImage();

    if (secilenler.isEmpty) return;

    setState(() {
      final kalanYer = maksFoto - _secilenFotolar.length;
      _secilenFotolar.addAll(secilenler.take(kalanYer));
    });
  }

  void _fotografSil(int index) {
    setState(() {
      _secilenFotolar.removeAt(index);
    });
  }

  Future<void> _gonder() async {
    final baslik = _baslikController.text.trim();
    if (baslik.isEmpty) return;

    final kullanici = supabase.auth.currentUser;
    if (kullanici == null) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      final List<String> yuklenenUrller = [];

      for (final dosya in _secilenFotolar) {
        final Uint8List baytlar = await dosya.readAsBytes();
        final uzanti = dosya.name.contains('.') ? dosya.name.split('.').last : 'jpg';
        final dosyaAdi =
            '${kullanici.id}/${DateTime.now().millisecondsSinceEpoch}-${yuklenenUrller.length}.$uzanti';

        await supabase.storage.from('ilan-fotograflari').uploadBinary(dosyaAdi, baytlar);

        final url = supabase.storage.from('ilan-fotograflari').getPublicUrl(dosyaAdi);
        yuklenenUrller.add(url);
      }

      await supabase.from('ilanlar').insert({
        'baslik': baslik,
        'aciklama': _aciklamaController.text.trim(),
        'kategori': _kategoriController.text.trim(),
        'konum': _konumController.text.trim(),
        'user_id': kullanici.id,
        'kullanici_email': kullanici.email,
        'fotograf_url': yuklenenUrller.isNotEmpty ? yuklenenUrller.first : null,
        'fotograflar': yuklenenUrller,
      });

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _baslikController.dispose();
    _aciklamaController.dispose();
    _kategoriController.dispose();
    _konumController.dispose();
    super.dispose();
  }

  InputDecoration _girdiStili(String ipucu) {
    return InputDecoration(
      hintText: ipucu,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: renkCizgi),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: renkZemin,
      appBar: AppBar(
        title: const Text('Yeni İlan'),
        backgroundColor: renkKart,
        foregroundColor: renkInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shape: const Border(bottom: BorderSide(color: renkCizgi)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_secilenFotolar.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _secilenFotolar.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: FutureBuilder<Uint8List>(
                            future: _secilenFotolar[index].readAsBytes(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Container(width: 64, height: 64, color: Colors.white);
                              }
                              return Image.memory(
                                snapshot.data!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () => _fotografSil(index),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Color(0xFFB5533C),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            if (_secilenFotolar.isNotEmpty) const SizedBox(height: 12),
            if (_secilenFotolar.length < maksFoto)
              OutlinedButton.icon(
                onPressed: _fotografSec,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('Fotoğraf Ekle (${_secilenFotolar.length}/$maksFoto)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: renkInk,
                  side: const BorderSide(color: renkCizgi),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            const SizedBox(height: 12),
            TextField(controller: _baslikController, decoration: _girdiStili('Eşyanın adı (örn. Kitaplık)')),
            const SizedBox(height: 12),
            TextField(
              controller: _aciklamaController,
              maxLines: 3,
              decoration: _girdiStili('Açıklama'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _kategoriController, decoration: _girdiStili('Kategori (örn. Mobilya)')),
            const SizedBox(height: 12),
            TextField(controller: _konumController, decoration: _girdiStili('Konum (örn. Kadıköy, İstanbul)')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _yukleniyor ? null : _gonder,
              style: ElevatedButton.styleFrom(
                backgroundColor: renkOcre,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(
                _yukleniyor ? 'Ekleniyor…' : 'İlan Ver',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}