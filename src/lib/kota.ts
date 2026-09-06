import { supabase } from './supabase';

/** Web `app/lib/kota.ts` ile aynı: bir hesap son 30 günde en fazla 3 eşya alabilir. */
export const aylikAlmaHakki = 3;

export type KotaDurumu = {
  alinan: number;
  kalan: number;
  yenilenmeTarihi: Date | null;
};

/** Bir hesabın son 30 gündeki eşya alma kotası durumu. */
export async function kotaDurumu(uid: string): Promise<KotaDurumu> {
  let alinan = 0;
  {
    const { data, error } = await supabase.rpc('alinan_esya_sayisi', { kisi: uid });
    // kota-limiti.sql henüz çalıştırılmadıysa RPC yok — kotayı boş say
    if (!error && typeof data === 'number') alinan = data;
  }

  const kalan = aylikAlmaHakki - alinan < 0 ? 0 : aylikAlmaHakki - alinan;

  let yenilenmeTarihi: Date | null = null;
  if (kalan === 0) {
    const { data, error } = await supabase.rpc('kota_yenilenme_tarihi', { kisi: uid });
    if (!error && typeof data === 'string') {
      const t = new Date(data);
      if (!Number.isNaN(t.getTime())) yenilenmeTarihi = t;
    }
  }

  return { alinan, kalan, yenilenmeTarihi };
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
