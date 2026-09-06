import { useEffect, useState } from 'react';
import type { User } from '@supabase/supabase-js';
import { supabase } from './supabase';

/**
 * Oturumdaki kullanıcıyı takip eden hook.
 * Flutter'daki `supabase.auth.onAuthStateChange` aboneliğinin karşılığı.
 */
export function useAuth() {
  const [kullanici, setKullanici] = useState<User | null>(null);
  const [hazir, setHazir] = useState(false);

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      setKullanici(data.user ?? null);
      setHazir(true);
    });

    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      setKullanici(session?.user ?? null);
      setHazir(true);
    });

    return () => sub.subscription.unsubscribe();
  }, []);

  return { kullanici, hazir };
}
