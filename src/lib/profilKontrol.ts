import type { User } from '@supabase/supabase-js';

/** Web `app/lib/profil.ts` ile aynı zorunlu profil alanları. */
export const profilAlanlari = ['ad', 'soyad', 'telefon', 'adres', 'iletisim_eposta'] as const;

/** Kullanıcının zorunlu profil alanları (ad, soyad, telefon, adres, e-posta) dolu mu? */
export function profilTamMi(user: User | null | undefined): boolean {
  if (!user) return false;
  const m = (user.user_metadata ?? {}) as Record<string, unknown>;
  return profilAlanlari.every((alan) => {
    const v = m[alan];
    return typeof v === 'string' && v.trim().length > 0;
  });
}
