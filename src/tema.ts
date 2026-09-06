/**
 * NeedGO renk paleti — web `app/globals.css` ve eski Flutter `tema.dart` ile aynı.
 */
export const renkZemin = '#EEF1EF'; // sayfa zemini (kırık beyaz)
export const renkKart = '#FFFFFF'; // kart / girdi yüzeyi
export const renkInk = '#003BCA'; // ana metin / koyu mavi
export const renkOrman = '#0066FF'; // vurgu mavi
export const renkOcre = '#00A3FF'; // aksiyon (İlan Ver, buton)
export const renkCizgi = '#B3DFFF'; // ince çizgi / kenarlık
export const renkHata = '#B5533C'; // hata / sil

/** Logo kelime markası tonları (web: Need = #2099FF, GO = #004CD6). */
export const renkNeed = '#2099FF';
export const renkGo = '#004CD6';

/** İlan kartı görsel alanının nötr zemini (web: #f3f1ec). */
export const renkGorselZemin = '#F3F1EC';

/**
 * RGBA yardımcı — Flutter'daki `renk.withOpacity(x)` karşılığı.
 * Sadece 6 haneli hex ("#RRGGBB") girdileriyle çalışır.
 */
export function saydam(hex: string, opacity: number): string {
  const h = hex.replace('#', '');
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${opacity})`;
}
