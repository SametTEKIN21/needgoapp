# NeedGO — Mobil Uygulama (React Native / Expo)

Ücretsiz eşya paylaşım uygulaması. Bu depo daha önce bir **Flutter** projesiydi;
tümüyle **React Native + Expo (TypeScript)** ile cross-platform (iOS + Android, Expo
üzerinden web de mümkün) bir projeye çevrildi. Backend aynı: **Supabase**
(auth + Postgres + Storage).

## Gereksinimler

- Node.js 20+
- Expo Go uygulaması (telefonda hızlı deneme için) veya Android/iOS emülatör

## Kurulum & çalıştırma

```bash
npm install
npm start          # Metro bundler + QR kod
npm run android    # Android emülatör / cihaz
npm run ios        # iOS simülatör (yalnızca macOS)
npm run web        # tarayıcı (deneysel)
```

Native derleme (mağaza için) EAS ile:

```bash
npx eas build --platform android
npx eas build --platform ios
```

## Yapılandırma

Supabase bağlantısı [src/lib/supabase.ts](src/lib/supabase.ts) içinde. URL ve
publishable (anon) anahtar Flutter sürümündeki `lib/supabase_client.dart` ile
birebir aynıdır. Farklı bir ortam için buradaki iki sabiti değiştir.

Uygulama; `ilanlar`, `konusmalar`, `mesajlar` tabloları, `ilan-fotograflari`
storage bucket'ı ve `alinan_esya_sayisi` / `kota_yenilenme_tarihi` RPC
fonksiyonlarını bekler (kota RPC'leri yoksa kota "boş" kabul edilir).

## Proje yapısı

| Dosya | Karşılığı (eski Flutter) | Görev |
|---|---|---|
| [App.tsx](App.tsx) | `main.dart` (`NeedGoApp`) | Navigasyon yığını (native-stack) |
| [src/tema.ts](src/tema.ts) | `tema.dart` | Renk paleti + `saydam()` yardımcısı |
| [src/components/NeedGoYazi.tsx](src/components/NeedGoYazi.tsx) | `NeedGoYazi` | İki tonlu kelime markası |
| [src/components/Baslik.tsx](src/components/Baslik.tsx) | tekrar eden `AppBar` | Beyaz, alt çizgili başlık çubuğu |
| [src/components/UI.tsx](src/components/UI.tsx) | `TextField` / `ElevatedButton` / `OutlinedButton` | Ortak girdi & buton bileşenleri |
| [src/lib/supabase.ts](src/lib/supabase.ts) | `supabase_client.dart` | Supabase istemcisi (AsyncStorage oturumu) |
| [src/lib/auth.ts](src/lib/auth.ts) | `onAuthStateChange` aboneliği | `useAuth()` hook'u |
| [src/lib/profilKontrol.ts](src/lib/profilKontrol.ts) | `profil_kontrol.dart` | `profilTamMi()` |
| [src/lib/kota.ts](src/lib/kota.ts) | `kota.dart` | 30 günlük alma kotası |
| [src/lib/mesajDeposu.ts](src/lib/mesajDeposu.ts) | `mesaj_deposu.dart` | Okunmamış mesaj sayacı (AsyncStorage) |
| [src/screens/AnaSayfa.tsx](src/screens/AnaSayfa.tsx) | `main.dart` (`AnaSayfa`) | Başlık, bildirim zili, hesap menüsü, FAB |
| [src/screens/IlanListesi.tsx](src/screens/IlanListesi.tsx) | `ilan_listesi.dart` | Hero slider, arama, kategoriler, ilan grid'i |
| [src/screens/GirisEkrani.tsx](src/screens/GirisEkrani.tsx) | `giris_ekrani.dart` | Giriş / kayıt / şifre sıfırlama |
| [src/screens/IlanDetay.tsx](src/screens/IlanDetay.tsx) | `ilan_detay.dart` | Foto galerisi, beğeni, mesaj başlatma (kota/profil kontrolü) |
| [src/screens/IlanVer.tsx](src/screens/IlanVer.tsx) | `ilan_ver.dart` | Yeni ilan + foto yükleme (`expo-image-picker`) |
| [src/screens/Ilanlarim.tsx](src/screens/Ilanlarim.tsx) | `ilanlarim.dart` | İlan yönetimi + bağış paneli |
| [src/screens/Mesajlar.tsx](src/screens/Mesajlar.tsx) | `mesajlar.dart` (`MesajlarSayfasi`) | Konuşma listesi |
| [src/screens/MesajDetay.tsx](src/screens/MesajDetay.tsx) | `mesajlar.dart` (`MesajDetaySayfasi`) | Tek konuşma / sohbet |
| [src/screens/Profil.tsx](src/screens/Profil.tsx) | `profil.dart` | Zorunlu profil alanları + kota kartı |

### Davranış farkları

- Flutter'da `Navigator.push` sonucuyla yapılan "geri dönünce yenile" mantığı,
  React Navigation'da `useFocusEffect` ile ekran her öne geldiğinde yeniden
  veri çekilerek karşılandı.
- Fotoğraflar Supabase Storage'a `base64-arraybuffer` ile yükleniyor
  (`image_picker` + `readAsBytes` karşılığı).
- `SharedPreferences` yerine `@react-native-async-storage/async-storage`.

## Web projesi

Ayrı yazılmış web istemcisi ileride bu depoya entegre edilecek. Ortak iş
kuralları (kota, zorunlu profil alanları, renk paleti) `src/lib` ve `src/tema.ts`
içinde web ile aynı değerlerle tutuluyor.
