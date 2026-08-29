import 'package:flutter/material.dart';

/// NeedGO renk paleti — web `app/globals.css` ile aynı.
const renkZemin = Color(0xFFEEF1EF); // sayfa zemini (web --renk-kraft, kırık beyaz)
const renkKart = Color(0xFFFFFFFF); // kart / girdi yüzeyi
const renkInk = Color(0xFF003BCA); // ana metin / koyu mavi
const renkOrman = Color(0xFF0066FF); // vurgu mavi
const renkOcre = Color(0xFF00A3FF); // aksiyon (İlan Ver, buton)
const renkCizgi = Color(0xFFB3DFFF); // ince çizgi / kenarlık
const renkHata = Color(0xFFB5533C); // hata / sil

/// Logo kelime markası tonları (web: Need = #2099FF, GO = #004CD6).
const renkNeed = Color(0xFF2099FF);
const renkGo = Color(0xFF004CD6);

/// İlan kartı görsel alanının nötr zemini (web: #f3f1ec).
const renkGorselZemin = Color(0xFFF3F1EC);

/// İki tonlu "NeedGO" kelime markası — web başlığındaki logonun aynısı.
class NeedGoYazi extends StatelessWidget {
  final double boyut;
  final FontWeight kalinlik;

  const NeedGoYazi({super.key, this.boyut = 20, this.kalinlik = FontWeight.w700});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: const [
          TextSpan(text: 'Need', style: TextStyle(color: renkNeed)),
          TextSpan(text: 'GO', style: TextStyle(color: renkGo)),
        ],
      ),
      style: TextStyle(
        fontSize: boyut,
        fontWeight: kalinlik,
        letterSpacing: -0.5,
      ),
    );
  }
}
