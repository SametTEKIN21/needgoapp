import AsyncStorage from '@react-native-async-storage/async-storage';
import { supabase } from './supabase';

/** Web'deki `needgo-mesaj-son-goruldu` localStorage anahtarının mobil karşılığı. */
const sonGorulduAnahtar = 'needgo-mesaj-son-goruldu';

/** Mesajlar ekranına girildiğinde "şu ana kadar görüldü" damgası basılır. */
export async function mesajlariGorulduIsaretle(): Promise<void> {
  try {
    await AsyncStorage.setItem(sonGorulduAnahtar, new Date().toISOString());
  } catch {
    // yoksay
  }
}

/** Kullanıcının okunmamış (kendi göndermediği, son görülmeden sonra gelen) mesaj sayısı. */
export async function okunmamisMesajSayisi(uid: string | null | undefined): Promise<number> {
  if (!uid) return 0;

  try {
    const { data: konusmalar } = await supabase
      .from('konusmalar')
      .select('id')
      .or(`gonderen_id.eq.${uid},alici_id.eq.${uid}`);

    const ids = (konusmalar ?? []).map((k: { id: string }) => k.id);
    if (ids.length === 0) return 0;

    let sonGoruldu = '1970-01-01T00:00:00Z';
    try {
      sonGoruldu = (await AsyncStorage.getItem(sonGorulduAnahtar)) ?? sonGoruldu;
    } catch {
      // yoksay
    }

    const { data: yeniMesajlar } = await supabase
      .from('mesajlar')
      .select('id')
      .in('konusma_id', ids)
      .neq('gonderen_id', uid)
      .gt('olusturulma_tarihi', sonGoruldu);

    return (yeniMesajlar ?? []).length;
  } catch {
    return 0;
  }
}
