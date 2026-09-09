# NeedGO — Web ↔ Mobil Entegrasyon & Onarım Planı

**Sorun:** Mobil için yaptığım güvenlik değişiklikleri (ortak Supabase DB'de) web'in
bazı yerlerini kırdı. Web'de mobilde olmayan sistemler var (moderasyon, şikayet,
admin, konuşma silme). İki uygulama veritabanı sözleşmesinde ayrışmış.

**Hedef:** Tek birleşik DB katmanı + iki uygulamayı da ona uydur + bir daha
ayrışmasın diye "Supabase tek kaynak" disiplini.

---

## Tespit ettiklerim

Web repoda (`needgo`) daha önce çalıştırılmış 4 SQL dosyası var:
`moderasyon.sql`, `kota-limiti.sql`, `mesaj-silme.sql`, `ilan-silme.sql`.
Benim `guvenlik.sql` bunların üzerine geldi ve kısmen çakıştı.

| # | Hasar / regresyon | Kaynak |
|---|---|---|
| 1 | `ilanlar.kullanici_email` sütununu sildim | web ilan verme + moderasyon + mesaj ekranı kırık |
| 2 | Migration `user_metadata`'daki profil alanlarını sildi | web profil sayfası + `profilTamMi` her yerde kırık |
| 3 | `ilanlar_insert` politikam fazla gevşek | **moderasyon atlatılabiliyor** — client `moderasyon_durumu:'onaylandi'` ile ilan ekleyebilir |
| 4 | `ilanlar_select` politikam fazla gevşek | `durum='aktif'` beklemedeki ilanlar görünür — moderasyon kısmen etkisiz |
| 5 | Web görüntülenme/beğeni sayaçları | zaten kırıktı (moderasyon.sql sahip-only update) — RPC'ye taşınacak |
| 6 | Mobil `moderasyon_durumu` filtrelemiyor | onaylanmamış ilanları gösteriyor |
| 7 | Web'de hesap silme yok | KVKK eksik |

İyi haber: konuşma/mesaj silme, admin moderasyon paneli, kota tetikleyicisi —
bunlar farklı politika isimleri sayesinde **hâlâ çalışıyor** (çakışmadı).

---

## BÖLÜM 0 — Mevcut DB durumunu doğrula (SEN çalıştır)

Supabase SQL Editor'de çalıştır, çıktıyı bana ver:

```sql
select tablename, policyname, cmd from pg_policies
where schemaname='public' and tablename in ('ilanlar','konusmalar','mesajlar','sikayetler','profiller','uygulama_ayarlari')
order by tablename, cmd;

select tgname, tgrelid::regclass from pg_trigger
where tgrelid::regclass::text in ('public.ilanlar') and not tgisinternal;

select column_name from information_schema.columns
where table_schema='public' and table_name='ilanlar' order by column_name;

select proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and proname in
('admin_mi','alinan_esya_sayisi','kota_yenilenme_tarihi','ilan_goruntulendi','ilan_begenildi','profil_getir','profil_kaydet','hesap_sil','uygulama_ayarlari');
```

---

## BÖLÜM 1 — Tek birleşik SQL (`supabase/guvenlik-v2.sql`, her iki repoya)

1. **`ilanlar.kullanici_email` geri ekle** (`add column if not exists`). Web kullanıyor,
   mobil yok sayacak (sadece yazacak).
2. **Gevşek politikalarımı kaldır** — `ilanlar_select`, `ilanlar_insert`, `ilanlar_update`,
   `ilanlar_delete` politikalarımı düşür. `moderasyon.sql`'in politikaları
   (`"ilan gorunurlugu"`, `"ilan ekleme"`, `"ilan guncelleme"`, `"ilan silme"`) canonical olsun.
   → Moderasyon zorlaması geri gelir.
3. **Kota tetikleyicisini tekilleştir** — benim `kota_kontrol_trg`'yi düşür,
   `kota-limiti.sql`'in `trg_bagis_kota`'sını bırak (aynı iş).
4. **`uygulama_ayarlari` config tablosu** (tek kaynak):
   ```
   aylik_alma_hakki = 3
   profil_alanlari  = ["ad","soyad","telefon","adres","iletisim_eposta"]
   ```
   + `uygulama_ayarlari()` RPC. `bagis_kota_kontrol` ve `profil_kaydet` bu tablodan `3`'ü okusun.
5. **`profiller` + `profil_getir`/`profil_kaydet`/`hesap_sil`** — zaten var, dokunma.
6. **`sikayetler`, konuşma/mesaj silme politikaları** — dokunma, çalışıyor.

Bu dosya `guvenlik.sql`'in yerini alır (idempotent, tekrar çalıştırılabilir).

---

## BÖLÜM 2 — Mobil kod (`needgoapp`)

| Dosya | Değişiklik |
|---|---|
| `src/screens/IlanVer.tsx` | `kullanici_email` insert'i geri ekle; ilan sonrası `https://www.needgo.com.tr/api/moderasyon`'a istek at (web'deki gibi) → mobil ilanlar da otomatik moderasyondan geçsin |
| `src/screens/IlanListesi.tsx` | `.eq('moderasyon_durumu','onaylandi')` filtresi (fallback'li) |
| `src/screens/IlanDetay.tsx` | Onaylanmamış ilanı sahibi/admin dışına gösterme |
| `src/lib/kota.ts` | `aylikAlmaHakki`'yı `uygulama_ayarlari()` RPC'den al (fallback 3) |
| `src/screens/Ilanlarim.tsx` | Moderasyon durumu rozeti (küçük dokunuş) |

---

## BÖLÜM 3 — Web kod (`~/Downloads/needgo/needgo`)

| Dosya | Değişiklik |
|---|---|
| `app/lib/profil.ts` | Yeniden yaz: `profilGetir`/`profilKaydet`/`profilTamMi` (async, RPC) + `hesabiSil` |
| `app/profil/page.tsx` | RPC kullan; "Hesabımı sil" ekle |
| `app/page.tsx` | `profilTamMi(kullanici)` → `await profilTamMi()` (state'e al) |
| `app/ilan/[id]/IlanDetayClient.tsx` | `profilTamMi` async'e; sayaçlar `.update()` → `.rpc('ilan_goruntulendi'/'ilan_begenildi')` |
| `app/hesap-ayarlari/page.tsx` | Hesap silme bağlantısı/bölümü |
| `app/lib/kota.ts` | `AYLIK_ALMA_HAKKI` → `uygulama_ayarlari()` RPC (fallback 3) |
| `AuthForm.tsx` | KVKK onayı — zaten var ✓ |

---

## BÖLÜM 4 — "Tek kaynak" disiplini

- **Kurallar** → `uygulama_ayarlari()` RPC (kota, zorunlu alanlar)
- **Admin** → `adminler` tablosu + `admin_mi()` (zaten DB'de)
- **Moderasyon** → `https://www.needgo.com.tr/api/moderasyon` (ortak endpoint, iki app de kullanır)
- **SQL migration** → `supabase/guvenlik-v2.sql` her iki repoda birebir aynı; değişince ikisine de kopyalanır
- İki README'ye "DB değişikliği = iki repoda da güncelle" notu

---

## BÖLÜM 5 — Test + deploy

1. `guvenlik-v2.sql`'i Supabase'de çalıştır
2. Mobil: simülatörde profil kaydet / mesaj / ilan ver / beğen / moderasyon
3. Web: `npm run dev` → aynı akışlar + admin paneli + konuşma silme
4. `needgoapp` commit + push
5. `needgo` commit + push (Vercel otomatik deploy)

---

## Tahmini kapsam

Büyük. SQL + ~5 mobil dosya + ~7 web dosya + test. Birkaç saatlik iş.
Adım adım gideceğim, her bölüm sonunda dururuz.
