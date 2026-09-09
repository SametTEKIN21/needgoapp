# NeedGO — App Store & Google Play yayın adımları

Sıralı kontrol listesi. Kod tarafındaki hazırlık bitti; kalanlar hesap/panel işleri.

---

## 0. Kod tarafında yapılanlar ✅

- [x] `supabase/guvenlik.sql` — RLS politikaları, storage politikaları, RPC'ler
- [x] `IlanDetay.tsx` — görüntülenme/beğeni sayaçları RPC'ye taşındı
- [x] `IlanVer.tsx` — `kullanici_email` artık yazılmıyor (PII sızıntısı kapandı)
- [x] **Şifreli profil** — `profiller` tablosu (pgcrypto + Vault), `src/lib/profil.ts`,
      `Profil.tsx` RPC'leri kullanıyor; ad/telefon/adres panelde düz metin görünmez
- [x] **Uygulama içi hesap silme** — `Profil.tsx` → "Hesabımı sil", `hesap_sil` RPC
- [x] **Gizlilik politikası taslağı** — `docs/gizlilik-politikasi.html` (köşeli
      parantezli alanları doldur, sonra bir URL'de yayınla)
- [x] `eas.json` — build profilleri
- [x] `app.json` — `ITSAppUsesNonExemptEncryption: false` (şifreleme beyanı)

---

## 1. Supabase güvenliğini uygula (ÖNCE BU)

1. Supabase paneli → proje → **SQL Editor** → **New query**
2. `supabase/guvenlik.sql` dosyasının tamamını yapıştır → **Run**
3. Doğrula: **Authentication → Policies** altında `ilanlar`, `konusmalar`,
   `mesajlar` için politikalar görünmeli; **Storage → Policies** altında
   `ilan-fotograflari` politikaları görünmeli.
4. Uygulamada test et: ilan aç, mesaj gönder, ilan ver, fotoğraf yükle,
   beğen — hepsi çalışmalı. (RPC'ler eklenmeden beğeni/görüntülenme sessizce
   çalışmaz; SQL çalıştıktan sonra düzelir.)

---

## 2. Hesaplar

| Hesap | Ücret | Link |
|---|---|---|
| Apple Developer Program | 99 USD / yıl | https://developer.apple.com/programs/enroll/ |
| Google Play Console | 25 USD tek sefer | https://play.google.com/console/signup |
| Expo (EAS) | ücretsiz | https://expo.dev/signup |

Apple: bireysel kayıt daha hızlı (birkaç saat–2 gün). Şirket kaydı D-U-N-S
numarası ister, haftalar sürebilir.

---

## 3. Gizlilik politikası (zorunlu — iki mağaza da ister)

Taslak hazır: [docs/gizlilik-politikasi.html](docs/gizlilik-politikasi.html)

1. Dosyadaki sarı `[...]` alanlarını doldur (veri sorumlusu adı, e-posta,
   adres, Supabase sunucu bölgesi, tarihler, saklama süreleri).
2. Bir URL'de yayınla — GitHub Pages (repo → Settings → Pages → `docs/`),
   Notion, Vercel veya Netlify.
3. URL'yi App Store Connect + Play Console'a gir.

---

## 4. EAS kurulumu (yerel terminalde, proje klasöründe)

```bash
cd ~/Downloads/needgoapp/needgoapp
npm install -g eas-cli
eas login
eas init                     # projeyi expo.dev hesabına bağlar, app.json'a projectId ekler
```

---

## 5. iOS derleme + gönderme

```bash
# 1) Üretim derlemesi (Apple sertifikalarını EAS otomatik oluşturur)
eas build --platform ios --profile production
#   - "Apple hesabınla giriş yap" → Apple ID + uygulama şifresi
#   - Bundle ID com.needgo.app'i EAS otomatik kaydeder

# 2) App Store Connect'te uygulama kaydı aç:
#    https://appstoreconnect.apple.com → Apps → +  → New App
#    - Platform: iOS, Bundle ID: com.needgo.app, SKU: needgo-001
#    - İsim: NeedGO

# 3) Derlemeyi TestFlight/App Store'a yükle
eas submit --platform ios --latest
```

Sonra App Store Connect'te doldur:
- **App Privacy** anketi: toplanan veri = E-posta, Ad, Telefon, Adres, Foto,
  Kullanıcı İçeriği; kullanım = uygulama işlevselliği; kimliğe bağlı: evet
- Ekran görüntüleri: **6.7" iPhone (1290×2796)** zorunlu — en az 2-3 adet
  (simülatörden `Cmd+S` ile alınabilir), 6.5" ve iPad opsiyonel
- Açıklama, anahtar kelimeler, kategori (Lifestyle / Shopping), destek URL'si
- Yaş derecelendirmesi anketi
- **Test hesabı**: Apple'ın inceleme ekibi için hazır bir e-posta/şifre gir
  (Review Notes alanına), yoksa reddedilir

### TestFlight ile önce test ettir
Yüklenen build birkaç dk sonra TestFlight'ta çıkar:
- **App Store Connect → TestFlight → Internal Testing**: 100 kişiye kadar,
  anında. Test edecek kişileri e-posta ile ekle → onlar telefonda
  **TestFlight** uygulamasından indirir.
- **External Testing**: 10.000 kişiye kadar, kısa Apple ön incelemesi + paylaşılabilir link.

### Yayına al
App Store Connect → uygulama sürümü → **Add for Review** → **Submit**.
İnceleme genelde 24–72 saat. Onaylanınca App Store'da yayında; herkes arayıp indirir.

---

## 6. Android derleme + gönderme

```bash
eas build --platform android --profile production   # .aab üretir
```

1. Play Console → **Create app** → NeedGO, kategori, ücretsiz
2. İlk yükleme genelde **Internal testing** track'ine:
   ```bash
   eas submit --platform android --latest
   ```
   İlk seferde bir Google Cloud servis hesabı JSON'u istenir
   (Play Console → Setup → API access → yeni servis hesabı → JSON indir).
3. Play Console'da doldur: Gizlilik politikası URL'si, **Data safety** formu,
   içerik derecelendirme anketi, hedef kitle, ekran görüntüleri
   (telefon: en az 2), 512×512 ikon, 1024×500 özellik grafiği
4. Test akışı: **Internal testing** (anında, e-posta listesi) →
   **Closed/Open testing** → **Production**
5. Yeni hesaplarda **Production öncesi 12 test kullanıcısı + 14 gün kapalı
   test** zorunluluğu olabilir (bireysel geliştirici hesapları için).

Play incelemesi genelde birkaç saat–1 gün.

---

## 7. Sonraki sürümler

`app.json`'daki `version`'ı artır (örn. `1.0.1`). Build numarası EAS tarafından
otomatik artırılır (`eas.json` → `appVersionSource: remote` + `autoIncrement`).
Tekrar `eas build` + `eas submit`.

---

## Açık kalan işler (senin kararın)

- [ ] `supabase/guvenlik.sql`'i Supabase SQL Editor'de çalıştır (henüz uygulanmadı)
- [ ] `docs/gizlilik-politikasi.html` içindeki `[...]` alanlarını doldur + yayınla
- [ ] Uygulama ekran görüntüleri (mağaza görselleri)
- [ ] Apple / Google hesap kayıtları ve ödemeleri
- [ ] Hesap silme akışını gerçek bir test hesabıyla dene (SQL çalıştıktan sonra)
- [ ] `konusmalar.gonderen_email` bağış panelinde e-posta gösteriyor — bu
      sadece ilan sahibine görünür (RLS ile korumalı), App Store açısından
      sorun değil ama istersen takma ada çevrilebilir
