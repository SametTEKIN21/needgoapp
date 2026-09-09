import { supabase } from './supabase';

/** Varsayılan/yedek değer. Asıl kaynak: DB `uygulama_ayarlari` → `aylik_alma_hakki`. */
export const AYLIK_ALMA_HAKKI = 3;

export type KotaDurumu = {
  alinan: number;
  kalan: number;
  limit: number;
  yenilenmeTarihi: Date | null;
};

/** Aylık alma hakkı — `uygulama_ayarlari()` RPC'den (fallback: AYLIK_ALMA_HAKKI). */
export async function aylikAlmaHakki(): Promise<number> {
  try {
    const { data } = await supabase.rpc('uygulama_ayarlari');
    const v = (data as { aylik_alma_hakki?: unknown } | null)?.aylik_alma_hakki;
    const n = typeof v === 'number' ? v : Number(v);
    return Number.isFinite(n) && n > 0 ? n : AYLIK_ALMA_HAKKI;
  } catch {
    return AYLIK_ALMA_HAKKI;
  }
}

/** Bir hesabın son 30 gündeki eşya alma kotası durumu. */
export async function kotaDurumu(uid: string): Promise<KotaDurumu> {
  let alinan = 0;
  {
    const { data, error } = await supabase.rpc('alinan_esya_sayisi', { kisi: uid });
    if (!error && typeof data === 'number') alinan = data;
  }

  const limit = await aylikAlmaHakki();
  const kalan = limit - alinan < 0 ? 0 : limit - alinan;

  let yenilenmeTarihi: Date | null = null;
  if (kalan === 0) {
    const { data, error } = await supabase.rpc('kota_yenilenme_tarihi', { kisi: uid });
    if (!error && typeof data === 'string') {
      const t = new Date(data);
      if (!Number.isNaN(t.getTime())) yenilenmeTarihi = t;
    }
  }

  return { alinan, kalan, limit, yenilenmeTarihi };
}

/** Belirli bir kişinin son 30 günde aldığı eşya sayısı (bağış alıcı listesi için). */
export async function alinanEsyaSayisi(uid: string): Promise<number> {
  const { data, error } = await supabase.rpc('alinan_esya_sayisi', { kisi: uid });
  if (!error && typeof data === 'number') return data;
  return 0;
}

const aylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

export function tarihMetni(tarih: Date | null | undefined): string {
  if (!tarih) return '';
  return `${tarih.getDate()} ${aylar[tarih.getMonth()]} ${tarih.getFullYear()}`;
}
