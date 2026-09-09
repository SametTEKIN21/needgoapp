-- ============================================================================
-- NeedGO — Birleşik güvenlik & şema (v2)
-- ============================================================================
-- guvenlik.sql'in yerini alır. Web'in eski SQL'leri (moderasyon.sql, kota-limiti.sql,
-- mesaj-silme.sql, ilan-silme.sql) ile mobilin guvenlik.sql'i üst üste binmiş,
-- ilanlar tablosunda 3 kuşak çakışan RLS politikası oluşmuştu. Bu dosya hepsini
-- tek temiz sete indirger.
--
-- KULLANIM: Supabase → SQL Editor → tamamını yapıştır → Run. İdempotent.
-- HER İKİ REPODA aynı dosya bulunur (needgoapp/ ve needgo/ supabase/ altında).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. Şema düzeltmeleri
-- ----------------------------------------------------------------------------

-- Web ilan verme / moderasyon / mesaj ekranı bu sütunu kullanıyor. Geri ekle.
alter table public.ilanlar add column if not exists kullanici_email text;

-- Web'in beklediği moderasyon/kota sütunları (yoksa ekle — idempotent güvence)
alter table public.ilanlar
  add column if not exists moderasyon_durumu text not null default 'beklemede',
  add column if not exists moderasyon_notu   text,
  add column if not exists moderasyon_tarihi timestamptz,
  add column if not exists alici_id          uuid references auth.users(id),
  add column if not exists bagis_tarihi      timestamptz,
  add column if not exists goruntulenme_sayisi integer not null default 0,
  add column if not exists begeni_sayisi       integer not null default 0;

alter table public.konusmalar add column if not exists gonderen_email text;

-- Şu ana kadar makine-moderasyonundan geçmemiş ilanları görünür tut
-- (yeni RLS 'onaylandi' değilse gizler; mevcut ilanlar kaybolmasın).
-- Not: moderasyon koruma tetikleyicisi SQL editöründe admin görmediği için bu
-- update'i geri alır → önce tetikleyiciyi düşür, section 6'da yeniden kurulur.
drop trigger if exists trg_moderasyon_koru on public.ilanlar;

update public.ilanlar
   set moderasyon_durumu = 'onaylandi'
 where moderasyon_tarihi is null
   and moderasyon_durumu = 'beklemede';


-- ----------------------------------------------------------------------------
-- 1. Uygulama ayarları — TEK KAYNAK (kota limiti, zorunlu alanlar)
-- ----------------------------------------------------------------------------
create table if not exists public.uygulama_ayarlari (
  anahtar text primary key,
  deger   jsonb not null
);

insert into public.uygulama_ayarlari (anahtar, deger) values
  ('aylik_alma_hakki', '3'::jsonb),
  ('profil_alanlari',  '["ad","soyad","telefon","adres","iletisim_eposta"]'::jsonb)
on conflict (anahtar) do nothing;

alter table public.uygulama_ayarlari enable row level security;
grant select on public.uygulama_ayarlari to anon, authenticated;
drop policy if exists ayarlar_select on public.uygulama_ayarlari;
create policy ayarlar_select on public.uygulama_ayarlari for select using (true);

-- Tek çağrıda tüm ayarlar: rpc('uygulama_ayarlari') -> { aylik_alma_hakki: 3, ... }
create or replace function public.uygulama_ayarlari()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$ select coalesce(jsonb_object_agg(anahtar, deger), '{}'::jsonb) from public.uygulama_ayarlari $$;
grant execute on function public.uygulama_ayarlari() to anon, authenticated;

-- Kota limitini config'ten okuyan yardımcı
create or replace function public.aylik_alma_hakki()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select (deger #>> '{}')::int from public.uygulama_ayarlari where anahtar = 'aylik_alma_hakki'), 3)
$$;
grant execute on function public.aylik_alma_hakki() to anon, authenticated;


-- ----------------------------------------------------------------------------
-- 2. admin_mi()  (moderasyon.sql'den — yoksa kur)
-- ----------------------------------------------------------------------------
create table if not exists public.adminler (
  email    text primary key,
  eklenme  timestamptz not null default now()
);
alter table public.adminler enable row level security;  -- politika yok = sadece SQL editöründen yönetilir

create or replace function public.admin_mi()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(auth.role() = 'service_role', false)
      or exists (select 1 from public.adminler where email = coalesce(auth.jwt() ->> 'email', ''));
$$;
grant execute on function public.admin_mi() to anon, authenticated, service_role;


-- ----------------------------------------------------------------------------
-- 3. RLS'i aç + minimum yetkiler
-- ----------------------------------------------------------------------------
alter table public.ilanlar    enable row level security;
alter table public.konusmalar enable row level security;
alter table public.mesajlar   enable row level security;
alter table public.sikayetler enable row level security;

grant select                 on public.ilanlar    to anon, authenticated;
grant insert, update, delete on public.ilanlar    to authenticated;
grant select, insert, delete on public.konusmalar to authenticated;
grant select, insert, delete on public.mesajlar   to authenticated;
grant select, insert, update on public.sikayetler to authenticated;


-- ----------------------------------------------------------------------------
-- 4. ESKİ/ÇAKIŞAN POLİTİKALARI TEMİZLE
-- ----------------------------------------------------------------------------
-- ilanlar
drop policy if exists "Herkes goruntulenme ve begeni guncelleyebilir" on public.ilanlar;
drop policy if exists "Herkes ilanlari gorebilir" on public.ilanlar;
drop policy if exists "Kullanicilar kendi ilanlarini guncelleyebilir" on public.ilanlar;
drop policy if exists "Sadece giris yapanlar ilan ekleyebilir" on public.ilanlar;
drop policy if exists "ilan ekleme" on public.ilanlar;
drop policy if exists "ilan gorunurlugu" on public.ilanlar;
drop policy if exists "ilan guncelleme" on public.ilanlar;
drop policy if exists "ilan silme" on public.ilanlar;
drop policy if exists ilanlar_select on public.ilanlar;
drop policy if exists ilanlar_insert on public.ilanlar;
drop policy if exists ilanlar_update on public.ilanlar;
drop policy if exists ilanlar_delete on public.ilanlar;

-- konusmalar
drop policy if exists "Kullanicilar kendi konusmalarini gorebilir" on public.konusmalar;
drop policy if exists "Kullanicilar konusma baslatabilir" on public.konusmalar;
drop policy if exists "taraflar konusmayi silebilir" on public.konusmalar;
drop policy if exists konusmalar_select on public.konusmalar;
drop policy if exists konusmalar_insert on public.konusmalar;
drop policy if exists konusmalar_delete on public.konusmalar;

-- mesajlar
drop policy if exists "Kullanicilar kendi konusmalarina mesaj gonderebilir" on public.mesajlar;
drop policy if exists "Kullanicilar kendi konusmalarindaki mesajlari gorebilir" on public.mesajlar;
drop policy if exists "taraflar mesajlari silebilir" on public.mesajlar;
drop policy if exists mesajlar_select on public.mesajlar;
drop policy if exists mesajlar_insert on public.mesajlar;
drop policy if exists mesajlar_delete on public.mesajlar;


-- ----------------------------------------------------------------------------
-- 5. TEK TEMİZ POLİTİKA SETİ
-- ----------------------------------------------------------------------------

-- === ilanlar ===
-- Okuma: onaylı ilanları herkes; sahibi ve admin her durumu görür
create policy ilanlar_select on public.ilanlar
  for select
  using ( moderasyon_durumu = 'onaylandi' or user_id = auth.uid() or public.admin_mi() );

-- Ekleme: giriş yapmış, kendi adına, yalnızca 'beklemede' (kendi ilanını onaylayamaz)
create policy ilanlar_insert on public.ilanlar
  for insert to authenticated
  with check ( user_id = auth.uid() and moderasyon_durumu = 'beklemede' );

-- Güncelleme: yalnızca sahibi veya admin.  (Görüntülenme/beğeni sayaçları
-- ilan_goruntulendi/ilan_begenildi RPC'lerinden — SECURITY DEFINER, RLS'i aşar.)
-- Moderasyon alanlarını sahibin kurcalaması trg_moderasyon_koru ile engellenir.
create policy ilanlar_update on public.ilanlar
  for update to authenticated
  using      ( user_id = auth.uid() or public.admin_mi() )
  with check ( user_id = auth.uid() or public.admin_mi() );

-- Silme: sahibi veya admin
create policy ilanlar_delete on public.ilanlar
  for delete to authenticated
  using ( user_id = auth.uid() or public.admin_mi() );

-- === konusmalar ===
create policy konusmalar_select on public.konusmalar
  for select to authenticated
  using ( gonderen_id = auth.uid() or alici_id = auth.uid() );

create policy konusmalar_insert on public.konusmalar
  for insert to authenticated
  with check ( gonderen_id = auth.uid() );

create policy konusmalar_delete on public.konusmalar
  for delete to authenticated
  using ( gonderen_id = auth.uid() or alici_id = auth.uid() );

-- === mesajlar ===
create policy mesajlar_select on public.mesajlar
  for select to authenticated
  using ( exists (
    select 1 from public.konusmalar k
    where k.id = mesajlar.konusma_id
      and ( k.gonderen_id = auth.uid() or k.alici_id = auth.uid() )
  ) );

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

create policy mesajlar_delete on public.mesajlar
  for delete to authenticated
  using ( exists (
    select 1 from public.konusmalar k
    where k.id = mesajlar.konusma_id
      and ( k.gonderen_id = auth.uid() or k.alici_id = auth.uid() )
  ) );

-- === sikayetler ===  (moderasyon.sql ile aynı — güvence için yeniden)
drop policy if exists "sikayet olustur" on public.sikayetler;
drop policy if exists "sikayet oku" on public.sikayetler;
drop policy if exists "sikayet guncelle" on public.sikayetler;
create policy "sikayet olustur" on public.sikayetler
  for insert to authenticated with check ( auth.uid() = sikayet_eden_id );
create policy "sikayet oku" on public.sikayetler
  for select using ( public.admin_mi() );
create policy "sikayet guncelle" on public.sikayetler
  for update using ( public.admin_mi() ) with check ( public.admin_mi() );


-- ----------------------------------------------------------------------------
-- 6. Moderasyon alanı koruması (moderasyon.sql'den)
-- ----------------------------------------------------------------------------
create or replace function public.moderasyon_alanlarini_koru()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.moderasyon_durumu is distinct from old.moderasyon_durumu
      or new.moderasyon_notu is distinct from old.moderasyon_notu)
     and not public.admin_mi()
  then
    new.moderasyon_durumu := old.moderasyon_durumu;
    new.moderasyon_notu   := old.moderasyon_notu;
    new.moderasyon_tarihi := old.moderasyon_tarihi;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_moderasyon_koru on public.ilanlar;
create trigger trg_moderasyon_koru
  before update on public.ilanlar
  for each row execute function public.moderasyon_alanlarini_koru();


-- ----------------------------------------------------------------------------
-- 7. Sayaç RPC'leri  (her iki app kullanır)
-- ----------------------------------------------------------------------------
create or replace function public.ilan_goruntulendi(p_ilan_id uuid)
returns void language sql security definer set search_path = '' as $$
  update public.ilanlar set goruntulenme_sayisi = coalesce(goruntulenme_sayisi,0) + 1 where id = p_ilan_id;
$$;
create or replace function public.ilan_begenildi(p_ilan_id uuid)
returns void language sql security definer set search_path = '' as $$
  update public.ilanlar set begeni_sayisi = coalesce(begeni_sayisi,0) + 1 where id = p_ilan_id;
$$;
revoke all on function public.ilan_goruntulendi(uuid) from public;
revoke all on function public.ilan_begenildi(uuid)   from public;
grant execute on function public.ilan_goruntulendi(uuid) to anon, authenticated;
grant execute on function public.ilan_begenildi(uuid)   to anon, authenticated;


-- ----------------------------------------------------------------------------
-- 8. Kota RPC'leri + tek tetikleyici
-- ----------------------------------------------------------------------------
create or replace function public.alinan_esya_sayisi(kisi uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.ilanlar
  where alici_id = kisi and durum = 'bagislandi' and bagis_tarihi >= now() - interval '30 days';
$$;
create or replace function public.kota_yenilenme_tarihi(kisi uuid)
returns timestamptz language sql stable security definer set search_path = '' as $$
  select min(bagis_tarihi) + interval '30 days' from public.ilanlar
  where alici_id = kisi and durum = 'bagislandi' and bagis_tarihi >= now() - interval '30 days';
$$;
grant execute on function public.alinan_esya_sayisi(uuid)    to anon, authenticated;
grant execute on function public.kota_yenilenme_tarihi(uuid) to anon, authenticated;

-- Kota kontrolü — limiti config'ten okur
create or replace function public.bagis_kota_kontrol()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.alici_id is not null
     and new.durum = 'bagislandi'
     and (old.alici_id is distinct from new.alici_id or old.durum is distinct from new.durum)
     and public.alinan_esya_sayisi(new.alici_id) >= public.aylik_alma_hakki()
  then
    raise exception 'KOTA_DOLU';
  end if;
  return new;
end;
$$;

-- İki kota tetikleyicisi vardı (kota_kontrol_trg + trg_bagis_kota) — tek bırak
drop trigger if exists kota_kontrol_trg on public.ilanlar;
drop function if exists public.kota_kontrol();
drop trigger if exists trg_bagis_kota on public.ilanlar;
create trigger trg_bagis_kota
  before update on public.ilanlar
  for each row execute function public.bagis_kota_kontrol();


-- ----------------------------------------------------------------------------
-- 9. FK cascade — ilan/konuşma silinince bağlılar da gitsin
-- ----------------------------------------------------------------------------
-- Bir tablonun verili kolonundaki tüm FK'lerini kaldırıp cascade ile yeniden kurar
create or replace function public._fk_cascade_kur(p_tablo text, p_kolon text, p_hedef text)
returns void language plpgsql as $$
declare c text;
begin
  if to_regclass('public.' || p_tablo) is null then return; end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name=p_tablo and column_name=p_kolon) then return; end if;
  -- Öksüz satırları temizle (FK eklenince validasyonu geçebilsin)
  execute format(
    'delete from public.%I t where t.%I is not null and not exists (select 1 from public.%I h where h.id = t.%I)',
    p_tablo, p_kolon, p_hedef, p_kolon);
  for c in
    select con.conname from pg_constraint con
    join pg_class r on r.oid = con.conrelid
    join pg_namespace n on n.oid = r.relnamespace
    where n.nspname='public' and r.relname=p_tablo and con.contype='f'
      and (select attname from pg_attribute where attrelid=con.conrelid and attnum=con.conkey[1]) = p_kolon
  loop
    execute format('alter table public.%I drop constraint %I', p_tablo, c);
  end loop;
  execute format(
    'alter table public.%I add constraint %I foreign key (%I) references public.%I(id) on delete cascade',
    p_tablo, p_tablo || '_' || p_kolon || '_fkey', p_kolon, p_hedef);
end $$;

select public._fk_cascade_kur('mesajlar',   'konusma_id', 'konusmalar');
select public._fk_cascade_kur('konusmalar', 'ilan_id',    'ilanlar');
select public._fk_cascade_kur('sikayetler', 'ilan_id',    'ilanlar');

drop function public._fk_cascade_kur(text, text, text);


-- ============================================================================
-- Not: profiller tablosu + profil_getir/profil_kaydet/hesap_sil guvenlik.sql'de
-- kuruldu, dokunmaya gerek yok. Onlar da bu dosyaya taşınabilir ama zaten uygulanmış.
-- ============================================================================
