import 'package:flutter/material.dart';
import 'supabase_client.dart';
import 'tema.dart';

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  String _mod = 'giris';
  final _emailController = TextEditingController();
  final _sifreController = TextEditingController();
  bool _yukleniyor = false;
  String _hata = '';
  String _mesaj = '';

  String _hataMesajiCevir(String mesaj) {
    if (mesaj.contains('Invalid login credentials')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (mesaj.contains('User already registered')) {
      return 'Bu e-posta adresi zaten kayıtlı. Giriş yapmayı deneyin.';
    }
    if (mesaj.contains('Password should be at least')) {
      return 'Şifre en az 6 karakter olmalı.';
    }
    if (mesaj.contains('Unable to validate email address')) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    if (mesaj.contains('Email not confirmed')) {
      return 'E-posta adresini onaylamadan giriş yapamazsın. Gelen kutunu kontrol et.';
    }
    return 'Bir hata oluştu, lütfen tekrar dene.';
  }

  Future<void> _gonder() async {
    setState(() {
      _hata = '';
      _mesaj = '';
      _yukleniyor = true;
    });

    final email = _emailController.text.trim();
    final sifre = _sifreController.text;

    try {
      if (_mod == 'kayit') {
        await supabase.auth.signUp(email: email, password: sifre);
        setState(() {
          _mesaj = 'Kayıt başarılı! E-postanı kontrol edip hesabını onayla.';
        });
      } else if (_mod == 'sifremi-unuttum') {
        await supabase.auth.resetPasswordForEmail(email);
        setState(() {
          _mesaj = 'Şifre sıfırlama linki e-postana gönderildi.';
        });
      } else {
        await supabase.auth.signInWithPassword(email: email, password: sifre);
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() {
        _hata = _hataMesajiCevir(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
        });
      }
    }
  }

  String get _baslik {
    if (_mod == 'giris') return 'Giriş Yap';
    if (_mod == 'kayit') return 'Kayıt Ol';
    return 'Şifremi Unuttum';
  }

  String get _butonMetni {
    if (_yukleniyor) return 'Bekleyin…';
    if (_mod == 'giris') return 'Giriş Yap';
    if (_mod == 'kayit') return 'Kayıt Ol';
    return 'Sıfırlama Linki Gönder';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: renkZemin,
      appBar: AppBar(
        backgroundColor: renkKart,
        foregroundColor: renkInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shape: const Border(bottom: BorderSide(color: renkCizgi)),
        title: Text(_baslik),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NeedGoYazi(boyut: 26),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'E-posta adresi',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: renkCizgi),
                ),
              ),
            ),
            if (_mod != 'sifremi-unuttum') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _sifreController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Şifre',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: renkCizgi),
                  ),
                ),
              ),
            ],
            if (_mod == 'giris') ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _mod = 'sifremi-unuttum';
                      _hata = '';
                      _mesaj = '';
                    });
                  },
                  child: const Text(
                    'Şifremi unuttum',
                    style: TextStyle(color: renkInk, fontSize: 12),
                  ),
                ),
              ),
            ],
            if (_hata.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_hata, style: const TextStyle(color: Color(0xFFB5533C), fontSize: 12)),
            ],
            if (_mesaj.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_mesaj, style: const TextStyle(color: renkOrman, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _yukleniyor ? null : _gonder,
              style: ElevatedButton.styleFrom(
                backgroundColor: renkOcre,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(_butonMetni, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            if (_mod == 'giris')
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _mod = 'kayit';
                      _hata = '';
                      _mesaj = '';
                    });
                  },
                  child: const Text('Hesabın yok mu? Kayıt Ol'),
                ),
              ),
            if (_mod == 'kayit')
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _mod = 'giris';
                      _hata = '';
                      _mesaj = '';
                    });
                  },
                  child: const Text('Zaten hesabın var mı? Giriş Yap'),
                ),
              ),
            if (_mod == 'sifremi-unuttum')
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _mod = 'giris';
                      _hata = '';
                      _mesaj = '';
                    });
                  },
                  child: const Text('Giriş ekranına dön'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}