import { supabase } from './supabase';

/** Zorunlu profil alanları. */
export const profilAlanlari = ['ad', 'soyad', 'telefon', 'adres', 'iletisim_eposta'] as const;

export type Profil = {
  ad: string;
  soyad: string;
  telefon: string;
  adres: string;
  iletisim_eposta: string;
  profil_tam: boolean;
};

const bosProfil: Profil = {
  ad: '',
  soyad: '',
  telefon: '',
  adres: '',
  iletisim_eposta: '',
  profil_tam: false,
};

/**
 * Giriş yapan kullanıcının profilini getirir.
 * Alanlar Supabase'de şifreli (pgcrypto + Vault) saklanır; çözme işlemi
 * `profil_getir` RPC'si içinde, yalnızca çağıran kullanıcının kendi satırı için yapılır.
 */
export async function profilGetir(): Promise<Profil> {
  const { data, error } = await supabase.rpc('profil_getir');
  if (error || !data) return bosProfil;
  return { ...bosProfil, ...(data as Partial<Profil>) };
}

/** Profili şifreleyerek kaydeder (`profil_kaydet` RPC). */
export async function profilKaydet(p: Omit<Profil, 'profil_tam'>): Promise<void> {
  const { error } = await supabase.rpc('profil_kaydet', {
    p_ad: p.ad.trim(),
    p_soyad: p.soyad.trim(),
    p_telefon: p.telefon.trim(),
    p_adres: p.adres.trim(),
    p_iletisim_eposta: p.iletisim_eposta.trim(),
  });
  if (error) throw error;
}

/** Zorunlu profil alanları dolu mu? (sunucudaki `profil_tam` bayrağı) */
export async function profilTamMi(): Promise<boolean> {
  const { data, error } = await supabase.rpc('profil_getir');
  if (error || !data) return false;
  return Boolean((data as { profil_tam?: boolean }).profil_tam);
}

/**
 * Hesabı ve tüm verisini (ilanlar, konuşmalar, mesajlar, fotoğraflar, auth kaydı)
 * kalıcı olarak siler. Fotoğraflar önce storage'dan temizlenir, sonra `hesap_sil` RPC'si çalışır.
 */
export async function hesabiSil(): Promise<void> {
  const { data: kul } = await supabase.auth.getUser();
  const uid = kul.user?.id;

  // En iyi çaba: kullanıcının yüklediği fotoğrafları storage'dan sil.
  if (uid) {
    try {
      const { data: dosyalar } = await supabase.storage
        .from('ilan-fotograflari')
        .list(uid, { limit: 1000 });
      const yollar = (dosyalar ?? []).map((d) => `${uid}/${d.name}`);
      if (yollar.length > 0) {
        await supabase.storage.from('ilan-fotograflari').remove(yollar);
      }
    } catch {
      // yoksay — RPC yine de DB kayıtlarını siler
    }
  }

  const { error } = await supabase.rpc('hesap_sil');
  if (error) throw error;

  // Sunucudaki oturum artık geçersiz; yerel oturumu temizle (hata olursa yoksay).
  try {
    await supabase.auth.signOut();
  } catch {
    // yoksay
  }
}
