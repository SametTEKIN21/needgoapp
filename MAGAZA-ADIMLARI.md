# NeedGO — App Store & Google Play yayın rehberi

Adım adım. Kod tarafındaki hazırlık bitti; buradan sonrası hesap + panel işleri.

> Terminal komutları hep proje klasöründe çalışır:
> `cd ~/Downloads/needgoapp/needgoapp`

---

## Durum özeti

| Konu | Durum |
|---|---|
| Supabase güvenlik (RLS, şifreli profil, hesap silme) | ✅ uygulandı |
| Gizlilik politikası | ✅ https://www.needgo.com.tr/gizlilik-bildirimi |
| Kayıt ekranında KVKK onayı | ✅ |
| `eas.json`, `app.json` şifreleme beyanı | ✅ |
| EAS hesabı + `eas init` | ⬜ (Adım 1) |
| Apple Developer üyeliği | ⬜ (Adım 2) |
| iOS build + App Store | ⬜ (Adım 3–6) |
| Google Play Console + Android | ⬜ (Adım 7–9) |

---

## ADIM 1 — EAS kurulumu (ücretsiz, ~10 dk, şimdi yapılabilir)

EAS = Expo'nun bulut derleme servisi. Mac'te Xcode ile uğraşmadan `.ipa` / `.aab` üretir.

1. **Expo hesabı aç** (yoksa): https://expo.dev/signup
2. Terminalde:
   ```bash
   cd ~/Downloads/needgoapp/needgoapp
   npm install -g eas-cli
   eas login
   ```
   E-posta + şifre sorar (2. adımda açtığın Expo hesabı).
3. Projeyi hesaba bağla:
   ```bash
   eas init
   ```
   - "Would you like to create a project for @kullanıcıadın/needgo?" → **Y**
   - `app.json` içine `extra.eas.projectId` satırı eklenir.
4. Bu değişikliği kaydet:
   ```bash
   git add app.json && git commit -m "eas: projectId" && git push
   ```
5. Kontrol: `eas whoami` → kullanıcı adını yazmalı.

---

## ADIM 2 — Apple Developer üyeliği (99 USD/yıl, 1 saat–2 gün onay)

Bu adım Adım 1 ile paralel yürüyebilir.

1. https://developer.apple.com/programs/enroll adresine git, Apple ID ile giriş yap
   (2 faktörlü doğrulama açık olmalı).
2. **Entity Type** seçimi:
   - **Individual / Sole Proprietor** → hızlı (birkaç saat–2 gün). App Store'da
     geliştirici adı olarak **kendi adın** (Burak Tekin) görünür.
   - **Company / Organization** → App Store'da **şirket adı** görünür ama
     **D-U-N-S numarası** + evrak doğrulaması ister, **haftalar** sürebilir.
   - Öneri: hızlı başlamak için **Individual** seç. Sonradan şirkete geçiş mümkün.
3. 99 USD öde. Onay e-postasını bekle.
4. Onaylanınca https://appstoreconnect.apple.com açılır hale gelir.

---

## ADIM 3 — iOS derlemesi (build)

Apple üyeliği onaylandıktan sonra:

```bash
eas build --platform ios --profile production
```

İlk çalıştırmada sorular:

| Soru | Cevap |
|---|---|
| "Do you want to log in to your Apple account?" | **Y** → Apple ID + şifre + 2FA kodu |
| "Generate a new Apple Distribution Certificate?" | **Y** |
| "Generate a new Provisioning Profile?" | **Y** |
| Bundle Identifier | `com.needgo.app` (otomatik kaydedilir) |

- Derleme **Expo bulutunda** ~15–30 dk sürer. Terminalde bir link verir:
  `https://expo.dev/accounts/.../builds/...` — oradan ilerlemeyi izleyebilirsin.
- Bitince `.ipa` dosyası EAS'te hazır bekler (indirmene gerek yok).

---

## ADIM 4 — App Store Connect'te uygulama kaydı

https://appstoreconnect.apple.com → **Apps** → sol üstte **＋** → **New App**

| Alan | Değer |
|---|---|
| Platforms | iOS |
| Name | `NeedGO` (App Store'da benzersiz olmalı; alınmışsa `NeedGO: Ücretsiz Eşya` gibi) |
| Primary Language | Turkish (Türkçe) |
| Bundle ID | `com.needgo.app` — listeden seç (Adım 3'te kaydedilmiş olur) |
| SKU | `needgo-001` (kendine özel kod, önemi yok) |
| User Access | Full Access |

---

## ADIM 5 — Derlemeyi yükle + TestFlight

```bash
eas submit --platform ios --latest
```

- Apple ID sorar. "App-specific password" isteyebilir:
  https://account.apple.com → Oturum aç ve Güvenlik → Uygulamaya özel parolalar → yeni oluştur.
- Yüklenen build **App Store Connect → TestFlight** sekmesinde ~5–15 dk içinde "Processing" → hazır olur.
- **Export Compliance**: `ITSAppUsesNonExemptEncryption: false` ayarladığımız için soru çıkmaz.

### Önce TestFlight ile test et (önerilir)
App Store Connect → **TestFlight** → **Internal Testing** → grup oluştur → kendini ve
test edecekleri **e-posta ile** ekle. Onlar telefonlarında **TestFlight** uygulamasını
kurup NeedGO'yu oradan indirir. (100 kişiye kadar, anında.)

---

## ADIM 6 — App Store bilgileri + inceleme

App Store Connect → uygulaman → sol menü:

### App Information
- Category: **Lifestyle** (ikincil: Shopping)
- Content Rights: "Does not contain third-party content" (kendi içeriğin)

### Pricing and Availability
- Price: **Free** / Türkiye + istediğin ülkeler

### App Privacy → "Get Started"
Toplanan veriler (hepsi **App Functionality** amaçlı, **tracking DEĞİL**, kimliğe **bağlı**):
- Contact Info → **Email Address**, **Name**, **Phone Number**, **Physical Address**
- User Content → **Photos or Videos**, **Customer Support**
- Identifiers → **User ID**

### Sürüm sayfası (1.0 Prepare for Submission)
- **Screenshots** — 6.7" iPhone (**1290 × 2796**) zorunlu, 3–10 adet.
  Simülatörde uygulamayı aç → `Cmd + S` ile kaydet.
- **Description** — uygulamanın ne yaptığı (Türkçe)
- **Keywords** — `eşya,paylaşım,bağış,ücretsiz,ikinci el,ihtiyaç` gibi (virgülle, 100 karakter)
- **Support URL** — `https://www.needgo.com.tr`
- **Marketing URL** — opsiyonel
- **Privacy Policy URL** — `https://www.needgo.com.tr/gizlilik-bildirimi`
- **Build** — "＋" ile TestFlight'tan gelen build'i seç
- **Age Rating** — anketi doldur (muhtemelen **4+**)
- **App Review Information** — ⚠️ **ÖNEMLİ**:
  - "Sign-in required" → **Yes**
  - Demo hesap: incelemeci için hazır bir **e-posta + şifre** gir (Supabase'de bir test
    kullanıcısı oluştur, profilini tam doldur). Bu olmadan **kesin red**.
  - Notes: "Ücretsiz eşya paylaşım uygulaması. Test hesabıyla giriş yapıp ilanları,
    mesajlaşmayı ve profil/hesap silmeyi görebilirsiniz."

### Submit for Review
Sağ üstte **Add for Review** → **Submit**. İnceleme **24–72 saat**.
Red gelirse sebep yazılır → düzelt → tekrar gönder. Onaylanınca yayında.

---

## ADIM 7 — Google Play Console kaydı (25 USD, tek sefer)

1. https://play.google.com/console/signup → 25 USD öde
2. **Account type**:
   - **Personal** → hızlı ama: Kasım 2023 sonrası açılan kişisel hesaplarda
     **Production'dan önce 20 test kullanıcısı + 14 gün kapalı test** zorunlu.
   - **Organization** → bu kuraldan muaf ama D-U-N-S numarası ister.
3. **Create app**: Name `NeedGO`, dil Türkçe, tür **App**, **Free**.

---

## ADIM 8 — Android derleme + yükleme

```bash
eas build --platform android --profile production   # .aab üretir (~15-30 dk)
```

### Google servis hesabı (eas submit için bir kez)
1. Play Console → **Setup → API access** → **Create new service account**
   (Google Cloud Console'a yönlendirir)
2. Google Cloud'da servis hesabı oluştur → **Keys → Add key → JSON** → indir
3. Play Console'a dön → o servis hesabına **Admin (all permissions)** veya en az
   **Release manager** yetkisi ver
4. İndirdiğin JSON'u proje dışında güvenli bir yere koy (repoya EKLEME).
   `eas.json` → `submit.production.android.serviceAccountKeyPath` alanına yolunu yaz
   veya `eas submit` sırasında sorulunca ver.

```bash
eas submit --platform android --latest
```

---

## ADIM 9 — Play Console formları + yayın

Play Console → uygulaman → sol menü:

### App content (hepsi zorunlu)
- **Privacy policy**: `https://www.needgo.com.tr/gizlilik-bildirimi`
- **Ads**: Hayır (reklam yok)
- **App access**: "All functionality is restricted" → incelemeci için test hesabı
  e-posta + şifre gir
- **Content rating**: anketi doldur (sonuç muhtemelen "Everyone / 3+")
- **Target audience**: 18+ (uygulama 18 yaş altına yönelik değil)
- **Data safety**: App Privacy ile aynı listeyi doldur (topladığın veriler,
  şifreli aktarım evet, kullanıcı silme talep edebilir evet)
- **Government app / Financial features / Health**: hepsi Hayır

### Store listing (Ana Store girişi)
- Kısa açıklama (80 karakter)
- Uzun açıklama (4000 karakter)
- **Uygulama simgesi** 512 × 512 PNG
- **Öne çıkan grafik** 1024 × 500 PNG
- **Telefon ekran görüntüleri** en az 2 (simülatör/emülatörden)

### Test → Production
1. **Testing → Internal testing** → yeni sürüm oluştur → `.aab`'yi seç
   (veya `eas submit` bunu yaptı) → test e-posta listesi ekle
2. Test linkini aç, kendi telefonunda dene
3. Personal hesapsan: **Closed testing**'te 20 kişi / 14 gün şartını tamamla
4. **Production → Create new release** → incele → **Send for review**

Play incelemesi genelde **birkaç saat – 2 gün**.

---

## Sonraki sürümler

1. `app.json` → `version` artır (`1.0.0` → `1.0.1`)
2. `eas build --platform ios --profile production` (ve/veya android)
3. `eas submit --platform ios --latest`
4. App Store Connect / Play Console'da yeni sürümü "What's New" ile gönder

Build numarası EAS tarafından otomatik artırılır (`eas.json` → `appVersionSource: remote`).

---

## Açık işler

- [ ] Adım 1: `eas login` + `eas init`
- [ ] Adım 2: Apple Developer üyeliği
- [ ] Adım 7: Google Play Console kaydı
- [ ] Supabase'de bir **demo/test hesabı** oluştur (profili tam), inceleme için
- [ ] Mağaza görselleri: ikon 512×512, feature graphic 1024×500, ekran görüntüleri
- [ ] Hesap silme akışını gerçek test hesabıyla dene
- [ ] (opsiyonel) `konusmalar.gonderen_email` bağış panelinde e-posta gösteriyor —
      RLS korumalı, mağaza açısından sorun değil; istersen takma ada çevrilir
