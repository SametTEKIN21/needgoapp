-- ============================================================================
-- NeedGO — Supabase güvenlik kurulumu (RLS + politikalar + RPC)
-- ============================================================================
-- KULLANIM:
--   Supabase paneli > SQL Editor > New query > bu dosyanın TAMAMINI yapıştır > Run
--   Dosya idempotent'tir: istediğin kadar tekrar çalıştırabilirsin.
--
-- NEDEN GEREKLİ:
--   Uygulamadaki anon key (src/lib/supabase.ts) herkese açıktır ve gizlenemez.
--   Güvenliği yalnızca Row Level Security (RLS) sağlar: RLS açık + doğru
--   politikalar olmadan anon key ile herkes tüm tabloyu okuyabilir/silebilir.
--
-- İÇİNDEKİLER:
--   0-8  : RLS, politikalar, sayaç/kota RPC'leri, storage politikaları
--   9-10 : Şifreli profil tablosu (pgcrypto + Vault) + eski veri taşıma
--   11   : Hesap silme RPC'si (mağaza zorunluluğu)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. Kişisel veri temizliği
--    ilanlar.kullanici_email yalnızca insert ediliyor, hiçbir yerde
--    gösterilmiyor. Genel ilan listesi herkese açık olduğu için bu alan
--    bir e-posta sızıntısıdır — kaldırıyoruz. (konusmalar.gonderen_email
--    kalıyor; o tabloyu sadece konuşmanın iki tarafı görebiliyor.)
-- ----------------------------------------------------------------------------
alter table public.ilanlar drop column if exists kullanici_email;


-- ----------------------------------------------------------------------------
-- 1. RLS'i aç
-- ----------------------------------------------------------------------------
alter table public.ilanlar    enable row level security;
alter table public.konusmalar enable row level security;
alter table public.mesajlar   enable row level security;

-- Minimum gerekli tablo yetkileri (RLS satırları ayrıca filtreler).
grant select                     on public.ilanlar    to anon, authenticated;
grant insert, update, delete     on public.ilanlar    to authenticated;
grant select, insert             on public.konusmalar to authenticated;
grant select, insert             on public.mesajlar   to authenticated;


-- ----------------------------------------------------------------------------
-- 2. ilanlar politikaları
-- ----------------------------------------------------------------------------

-- Okuma: herkes "aktif" ilanları görür; sahibi kendi ilanının her durumunu görür.
drop policy if exists ilanlar_select on public.ilanlar;
create policy ilanlar_select on public.ilanlar
  for select
  using ( durum = 'aktif' or user_id = auth.uid() );

-- Ekleme: yalnızca giriş yapmış kullanıcı, yalnızca kendi adına.
drop policy if exists ilanlar_insert on public.ilanlar;
create policy ilanlar_insert on public.ilanlar
  for insert to authenticated
  with check ( user_id = auth.uid() );

-- Güncelleme: yalnızca ilan sahibi. (Görüntülenme/beğeni sayaçları buradan
-- DEĞİL, aşağıdaki SECURITY DEFINER fonksiyonlarından artırılır.)
drop policy if exists ilanlar_update on public.ilanlar;
create policy ilanlar_update on public.ilanlar
  for update to authenticated
  using ( user_id = auth.uid() )
  with check ( user_id = auth.uid() );

-- Silme: yalnızca ilan sahibi.
drop policy if exists ilanlar_delete on public.ilanlar;
create policy ilanlar_delete on public.ilanlar
  for delete to authenticated
  using ( user_id = auth.uid() );


-- ----------------------------------------------------------------------------
-- 3. konusmalar politikaları
-- ----------------------------------------------------------------------------

-- Okuma: yalnızca konuşmanın gönderen'i veya alıcı'sı.
drop policy if exists konusmalar_select on public.konusmalar;
create policy konusmalar_select on public.konusmalar
  for select to authenticated
  using ( gonderen_id = auth.uid() or alici_id = auth.uid() );

-- Ekleme: kullanıcı yalnızca kendi adına konuşma başlatır, kendine değil.
drop policy if exists konusmalar_insert on public.konusmalar;
create policy konusmalar_insert on public.konusmalar
  for insert to authenticated
  with check ( gonderen_id = auth.uid() and alici_id <> auth.uid() );

-- (Güncelleme/silme politikası yok = konusmalar üzerinde update/delete tamamen kapalı.)


-- ----------------------------------------------------------------------------
-- 4. mesajlar politikaları
-- ----------------------------------------------------------------------------

-- Okuma: yalnızca ilgili konuşmanın iki tarafından biri.
drop policy if exists mesajlar_select on public.mesajlar;
create policy mesajlar_select on public.mesajlar
  for select to authenticated
  using ( exists (
    select 1 from public.konusmalar k
    where k.id = mesajlar.konusma_id
      and ( k.gonderen_id = auth.uid() or k.alici_id = auth.uid() )
  ) );

-- Ekleme: gönderen kendisi olmalı VE o konuşmanın bir tarafı olmalı.
drop policy if exists mesajlar_insert on public.mesajlar;
create policy mesajlar_insert on public.mesajlar
  for insert to authenticated
  with check (
    gonderen_id = auth.uid()
    and exists (
      select 1 from public.konusmalar k
      where k.id = mesajlar.konusma_id
        and ( k.gonderen_id = auth.uid() or k.alici_id = auth.uid() )
    )
  );

-- (Güncelleme/silme politikası yok = mesajlar değiştirilemez/silinemez.)


-- ----------------------------------------------------------------------------
-- 5. Sayaç RPC'leri  (ilan sahibi olmayanlar da artırabilsin diye)
--    Client: supabase.rpc('ilan_goruntulendi', { p_ilan_id })
--            supabase.rpc('ilan_begenildi',   { p_ilan_id })
-- ----------------------------------------------------------------------------
create or replace function public.ilan_goruntulendi(p_ilan_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.ilanlar
     set goruntulenme_sayisi = coalesce(goruntulenme_sayisi, 0) + 1
   where id = p_ilan_id;
$$;

create or replace function public.ilan_begenildi(p_ilan_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.ilanlar
     set begeni_sayisi = coalesce(begeni_sayisi, 0) + 1
   where id = p_ilan_id;
$$;

revoke all on function public.ilan_goruntulendi(uuid) from public;
revoke all on function public.ilan_begenildi(uuid)   from public;
grant execute on function public.ilan_goruntulendi(uuid) to anon, authenticated;
grant execute on function public.ilan_begenildi(uuid)   to anon, authenticated;


-- ----------------------------------------------------------------------------
-- 6. Kota RPC'leri  (30 günlük "eşya alma" kotası)
--    Client: supabase.rpc('alinan_esya_sayisi',   { kisi })
--            supabase.rpc('kota_yenilenme_tarihi', { kisi })
-- ----------------------------------------------------------------------------
create or replace function public.alinan_esya_sayisi(kisi uuid)
returns integer
language sql
security definer
set search_path = public
as $$
  select count(*)::int
    from public.ilanlar
   where alici_id = kisi
     and durum = 'bagislandi'
     and bagis_tarihi >= now() - interval '30 days';
$$;

create or replace function public.kota_yenilenme_tarihi(kisi uuid)
returns timestamptz
language sql
security definer
set search_path = public
as $$
  select min(bagis_tarihi) + interval '30 days'
    from public.ilanlar
   where alici_id = kisi
     and durum = 'bagislandi'
     and bagis_tarihi >= now() - interval '30 days';
$$;

revoke all on function public.alinan_esya_sayisi(uuid)   from public;
revoke all on function public.kota_yenilenme_tarihi(uuid) from public;
grant execute on function public.alinan_esya_sayisi(uuid)   to anon, authenticated;
grant execute on function public.kota_yenilenme_tarihi(uuid) to anon, authenticated;


-- ----------------------------------------------------------------------------
-- 7. Kota tetikleyicisi  (sunucu tarafında da zorla)
--    Bir ilana alıcı atanırken alıcının 30 günlük kotası dolmuşsa reddet.
--    Client bu hatayı 'KOTA_DOLU' metnine bakarak yakalıyor (Ilanlarim.tsx).
-- ----------------------------------------------------------------------------
create or replace function public.kota_kontrol()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.alici_id is not null
     and new.durum = 'bagislandi'
     and (old.alici_id is distinct from new.alici_id)
     and public.alinan_esya_sayisi(new.alici_id) >= 3
  then
    raise exception 'KOTA_DOLU';
  end if;
  return new;
end;
$$;

drop trigger if exists kota_kontrol_trg on public.ilanlar;
create trigger kota_kontrol_trg
  before update on public.ilanlar
  for each row execute function public.kota_kontrol();


-- ----------------------------------------------------------------------------
-- 8. Storage: ilan-fotograflari bucket'ı
--    Dosya yolu şeması: "{user_id}/{zaman}-{index}.{uzanti}"  (IlanVer.tsx)
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('ilan-fotograflari', 'ilan-fotograflari', true)
on conflict (id) do update set public = true;

-- Okuma: herkese açık (getPublicUrl kullanılıyor).
drop policy if exists ilan_foto_select on storage.objects;
create policy ilan_foto_select on storage.objects
  for select
  using ( bucket_id = 'ilan-fotograflari' );

-- Yükleme: giriş yapmış kullanıcı yalnızca kendi klasörüne.
drop policy if exists ilan_foto_insert on storage.objects;
create policy ilan_foto_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'ilan-fotograflari'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Güncelleme / silme: yalnızca kendi klasöründeki dosyalar.
drop policy if exists ilan_foto_update on storage.objects;
create policy ilan_foto_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'ilan-fotograflari'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists ilan_foto_delete on storage.objects;
create policy ilan_foto_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'ilan-fotograflari'
    and (storage.foldername(name))[1] = auth.uid()::text
  );


-- ----------------------------------------------------------------------------
-- 9. Şifreli profil tablosu  (ad, soyad, telefon, adres, iletişim e-postası)
--    - Alanlar pgcrypto ile şifreli (bytea) saklanır.
--    - Anahtar Supabase Vault'ta; panelde/yedekte düz metin GÖRÜNMEZ.
--    - Tabloya doğrudan erişim yok; her şey aşağıdaki RPC'lerden geçer.
-- ----------------------------------------------------------------------------
create extension if not exists pgcrypto with schema extensions;

-- Şifreleme anahtarı (yoksa rastgele üret; varsa dokunma).
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'profil_anahtari') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'profil_anahtari',
      'NeedGO — profil alanları şifreleme anahtarı'
    );
  end if;
end $$;

create table if not exists public.profiller (
  id                      uuid primary key references auth.users(id) on delete cascade,
  ad_sifreli              bytea,
  soyad_sifreli           bytea,
  telefon_sifreli         bytea,
  adres_sifreli           bytea,
  iletisim_eposta_sifreli bytea,
  profil_tam              boolean not null default false,
  guncellenme             timestamptz not null default now()
);

alter table public.profiller enable row level security;
-- Politika YOK + yetki YOK = anon/authenticated tabloya hiç dokunamaz.
revoke all on public.profiller from anon, authenticated;

-- Profili şifreleyerek kaydet.  Client: rpc('profil_kaydet', { p_ad, ... })
create or replace function public.profil_kaydet(
  p_ad text, p_soyad text, p_telefon text, p_adres text, p_iletisim_eposta text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  k   text;
  tam boolean;
begin
  if uid is null then raise exception 'AUTH_YOK'; end if;
  select decrypted_secret into k from vault.decrypted_secrets where name = 'profil_anahtari' limit 1;
  if k is null then raise exception 'ANAHTAR_YOK'; end if;

  tam := (coalesce(btrim(p_ad),'') <> '' and coalesce(btrim(p_soyad),'') <> ''
      and coalesce(btrim(p_telefon),'') <> '' and coalesce(btrim(p_adres),'') <> ''
      and coalesce(btrim(p_iletisim_eposta),'') <> '');

  insert into public.profiller (
    id, ad_sifreli, soyad_sifreli, telefon_sifreli, adres_sifreli,
    iletisim_eposta_sifreli, profil_tam, guncellenme
  ) values (
    uid,
    extensions.pgp_sym_encrypt(coalesce(p_ad,''), k),
    extensions.pgp_sym_encrypt(coalesce(p_soyad,''), k),
    extensions.pgp_sym_encrypt(coalesce(p_telefon,''), k),
    extensions.pgp_sym_encrypt(coalesce(p_adres,''), k),
    extensions.pgp_sym_encrypt(coalesce(p_iletisim_eposta,''), k),
    tam, now()
  )
  on conflict (id) do update set
    ad_sifreli              = excluded.ad_sifreli,
    soyad_sifreli           = excluded.soyad_sifreli,
    telefon_sifreli         = excluded.telefon_sifreli,
    adres_sifreli           = excluded.adres_sifreli,
    iletisim_eposta_sifreli = excluded.iletisim_eposta_sifreli,
    profil_tam              = excluded.profil_tam,
    guncellenme             = now();
end;
$$;

-- Giriş yapan kullanıcının kendi profilini çözerek getir.  Client: rpc('profil_getir')
create or replace function public.profil_getir()
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  k   text;
  r   public.profiller%rowtype;
begin
  if uid is null then return null; end if;
  select * into r from public.profiller where id = uid;
  if not found then
    return json_build_object('ad','','soyad','','telefon','','adres','',
                             'iletisim_eposta','','profil_tam',false);
  end if;
  select decrypted_secret into k from vault.decrypted_secrets where name = 'profil_anahtari' limit 1;
  return json_build_object(
    'ad',              coalesce(extensions.pgp_sym_decrypt(r.ad_sifreli, k), ''),
    'soyad',           coalesce(extensions.pgp_sym_decrypt(r.soyad_sifreli, k), ''),
    'telefon',         coalesce(extensions.pgp_sym_decrypt(r.telefon_sifreli, k), ''),
    'adres',           coalesce(extensions.pgp_sym_decrypt(r.adres_sifreli, k), ''),
    'iletisim_eposta', coalesce(extensions.pgp_sym_decrypt(r.iletisim_eposta_sifreli, k), ''),
    'profil_tam',      r.profil_tam
  );
end;
$$;

revoke all on function public.profil_kaydet(text,text,text,text,text) from public;
revoke all on function public.profil_getir() from public;
grant execute on function public.profil_kaydet(text,text,text,text,text) to authenticated;
grant execute on function public.profil_getir() to authenticated;


-- ----------------------------------------------------------------------------
-- 10. Eski düz-metin profilleri şifreli tabloya taşı ve auth metadata'dan sil
--     (bir kez; tekrar çalıştırmak zararsız)
-- ----------------------------------------------------------------------------
do $$
declare
  u record;
  k text;
begin
  select decrypted_secret into k from vault.decrypted_secrets where name = 'profil_anahtari' limit 1;
  for u in
    select id, raw_user_meta_data as m
    from auth.users
    where raw_user_meta_data ?| array['ad','soyad','telefon','adres','iletisim_eposta']
  loop
    insert into public.profiller (
      id, ad_sifreli, soyad_sifreli, telefon_sifreli, adres_sifreli,
      iletisim_eposta_sifreli, profil_tam
    ) values (
      u.id,
      extensions.pgp_sym_encrypt(coalesce(u.m->>'ad',''), k),
      extensions.pgp_sym_encrypt(coalesce(u.m->>'soyad',''), k),
      extensions.pgp_sym_encrypt(coalesce(u.m->>'telefon',''), k),
      extensions.pgp_sym_encrypt(coalesce(u.m->>'adres',''), k),
      extensions.pgp_sym_encrypt(coalesce(u.m->>'iletisim_eposta',''), k),
      (coalesce(btrim(u.m->>'ad'),'') <> '' and coalesce(btrim(u.m->>'soyad'),'') <> ''
       and coalesce(btrim(u.m->>'telefon'),'') <> '' and coalesce(btrim(u.m->>'adres'),'') <> ''
       and coalesce(btrim(u.m->>'iletisim_eposta'),'') <> '')
    )
    on conflict (id) do nothing;
  end loop;

  update auth.users
     set raw_user_meta_data = raw_user_meta_data - 'ad' - 'soyad' - 'telefon' - 'adres' - 'iletisim_eposta'
   where raw_user_meta_data ?| array['ad','soyad','telefon','adres','iletisim_eposta'];
end $$;


-- ----------------------------------------------------------------------------
-- 11. Hesap silme  (App Store / Play Store zorunluluğu)
--     Kullanıcının tüm verisini + auth kaydını kalıcı siler.
--     Client: rpc('hesap_sil')  (öncesinde fotoğrafları storage'dan temizle)
-- ----------------------------------------------------------------------------
create or replace function public.hesap_sil()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'AUTH_YOK'; end if;

  delete from public.mesajlar m using public.konusmalar k
   where m.konusma_id = k.id and (k.gonderen_id = uid or k.alici_id = uid);
  delete from public.konusmalar where gonderen_id = uid or alici_id = uid;
  delete from public.ilanlar    where user_id = uid;
  delete from public.profiller  where id = uid;
  delete from storage.objects
   where bucket_id = 'ilan-fotograflari'
     and (storage.foldername(name))[1] = uid::text;

  -- Not: Bu satır Supabase'de 'postgres' rolüyle çalışır ve genelde yeterlidir.
  -- İzin hatası alırsan bunun yerine bir Edge Function (service_role) kullan.
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.hesap_sil() from public;
grant execute on function public.hesap_sil() to authenticated;


-- ============================================================================
-- KONTROL SORGULARI (isteğe bağlı — çalıştırıp doğrulayabilirsin)
-- ============================================================================
-- RLS açık mı?
--   select relname, relrowsecurity from pg_class
--   where relname in ('ilanlar','konusmalar','mesajlar');
-- Politikalar:
--   select schemaname, tablename, policyname, cmd from pg_policies
--   where tablename in ('ilanlar','konusmalar','mesajlar','objects');
-- ============================================================================
