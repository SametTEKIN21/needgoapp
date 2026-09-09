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

Uygulama; `ilanlar`, `konusmalar`, `mesajlar` tabloları ve `ilan-fotograflari`
storage bucket'ını bekler.

### Güvenlik (RLS) — yayına çıkmadan önce zorunlu

[supabase/guvenlik.sql](supabase/guvenlik.sql) dosyasını Supabase paneli >
**SQL Editor** içinde bir kez çalıştır. Bu dosya:

- `ilanlar` / `konusmalar` / `mesajlar` tablolarında RLS'i açar ve politikaları kurar,
- `ilan-fotograflari` bucket'ı için storage politikalarını kurar,
- sayaç RPC'lerini (`ilan_goruntulendi`, `ilan_begenildi`) ve kota RPC'lerini
  (`alinan_esya_sayisi`, `kota_yenilenme_tarihi`) + kota tetikleyicisini oluşturur,
- kişisel veri sızıntısı olan `ilanlar.kullanici_email` sütununu kaldırır,
- **şifreli `profiller` tablosunu** (pgcrypto + Vault anahtarı) ve
  `profil_getir` / `profil_kaydet` RPC'lerini oluşturur; eski `user_metadata`
  profillerini bu tabloya taşıyıp düz metin kopyaları siler,
- **`hesap_sil` RPC'sini** oluşturur (uygulama içi hesap silme — mağaza zorunluluğu).

Profil alanları (ad, soyad, telefon, adres, iletişim e-postası) artık
`user_metadata`'da değil; şifreli olarak `profiller` tablosunda tutulur ve
yalnızca `profil_getir` RPC'si içinde, ilgili kullanıcı için çözülür.

Anon key gizli değildir (uygulama paketinden çıkarılabilir); veritabanını
koruyan tek şey bu RLS politikalarıdır.

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
| [src/lib/profil.ts](src/lib/profil.ts) | `profil_kontrol.dart` | Şifreli profil: `profilGetir()` / `profilKaydet()` / `profilTamMi()` / `hesabiSil()` |
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
