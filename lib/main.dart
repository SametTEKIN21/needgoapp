import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import 'tema.dart';
import 'giris_ekrani.dart';
import 'ilan_listesi.dart';
import 'ilan_ver.dart';
import 'ilanlarim.dart';
import 'profil.dart';
import 'profil_kontrol.dart';
import 'mesajlar.dart';
import 'mesaj_deposu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await supabaseBaslat();
  runApp(const NeedGoApp());
}

class NeedGoApp extends StatelessWidget {
  const NeedGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeedGO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: renkOrman),
        scaffoldBackgroundColor: renkZemin,
        useMaterial3: true,
      ),
      home: const AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> with WidgetsBindingObserver {
  User? _kullanici;
  int _yenilemeSayaci = 0;
  int _okunmamisMesaj = 0;
  StreamSubscription<AuthState>? _authAbone;
  Timer? _mesajZamanlayici;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _kullanici = supabase.auth.currentUser;
    _okunmamisGetir();

    _authAbone = supabase.auth.onAuthStateChange.listen((data) {
      setState(() => _kullanici = data.session?.user);
      _okunmamisGetir();
    });

    _mesajZamanlayici =
        Timer.periodic(const Duration(seconds: 30), (_) => _okunmamisGetir());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authAbone?.cancel();
    _mesajZamanlayici?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _okunmamisGetir();
  }

  Future<void> _okunmamisGetir() async {
    final sayi = await okunmamisMesajSayisi(supabase.auth.currentUser?.id);
    if (mounted) setState(() => _okunmamisMesaj = sayi);
  }

  Future<void> _cikisYap() async {
    await supabase.auth.signOut();
  }

  void _girisEkraniniAc() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const GirisEkrani()),
    );
  }

  Future<void> _mesajlariAc() async {
    setState(() => _okunmamisMesaj = 0);
    await mesajlariGorulduIsaretle();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MesajlarSayfasi()),
    );
    _okunmamisGetir();
  }

  Future<void> _profiliAc() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProfilSayfasi()),
    );
    setState(() {}); // profil güncellenmiş olabilir
  }

  void _ilanlarimiAc() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const Ilanlarim()),
    );
  }

  Future<void> _ilanVerTiklandi() async {
    if (_kullanici == null) {
      _girisEkraniniAc();
      return;
    }

    if (!profilTamMi(supabase.auth.currentUser)) {
      await _profiliAc();
      return;
    }

    final sonuc = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const IlanVer()),
    );

    if (sonuc == true) {
      setState(() => _yenilemeSayaci++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset('assets/images/needgo-n.png', height: 34, width: 34),
            const SizedBox(width: 8),
            const NeedGoYazi(boyut: 22),
          ],
        ),
        backgroundColor: renkKart,
        foregroundColor: renkInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shape: const Border(bottom: BorderSide(color: renkCizgi)),
        actions: [
          if (_kullanici != null) ...[
            _bildirimCani(),
            _hesapMenusu(),
            const SizedBox(width: 4),
          ] else
            TextButton(
              onPressed: _girisEkraniniAc,
              child: const Text('Giriş Yap', style: TextStyle(color: renkOrman)),
            ),
        ],
      ),
      body: IlanListesi(key: ValueKey(_yenilemeSayaci)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ilanVerTiklandi,
        backgroundColor: renkOcre,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('İlan Ver'),
      ),
    );
  }

  Widget _bildirimCani() {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: _mesajlariAc,
          icon: const Icon(Icons.notifications_none),
          color: renkInk,
          tooltip: 'Mesajlar',
        ),
        if (_okunmamisMesaj > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: renkHata,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _okunmamisMesaj > 9 ? '9+' : '$_okunmamisMesaj',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  Widget _hesapMenusu() {
    final harf = (_kullanici?.email ?? '?').trim();
    return PopupMenuButton<String>(
      tooltip: 'Hesap',
      offset: const Offset(0, 48),
      onSelected: (v) {
        switch (v) {
          case 'profil':
            _profiliAc();
            break;
          case 'ilanlarim':
            _ilanlarimiAc();
            break;
          case 'mesajlar':
            _mesajlariAc();
            break;
          case 'cikis':
            _cikisYap();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'profil', child: Text('Profil')),
        PopupMenuItem(value: 'ilanlarim', child: Text('İlanlarım')),
        PopupMenuItem(value: 'mesajlar', child: Text('Mesajlar')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'cikis', child: Text('Çıkış Yap')),
      ],
      child: CircleAvatar(
        radius: 16,
        backgroundColor: renkOrman,
        child: Text(
          harf.isEmpty ? '?' : harf.characters.first.toUpperCase(),
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
