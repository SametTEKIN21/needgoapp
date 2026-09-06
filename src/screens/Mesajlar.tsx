import { useCallback, useEffect, useState } from 'react';
import { View, Text, FlatList, Pressable, RefreshControl, StyleSheet } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { supabase } from '../lib/supabase';
import { mesajlariGorulduIsaretle } from '../lib/mesajDeposu';
import { renkZemin, renkKart, renkInk, renkOrman, renkCizgi, saydam } from '../tema';
import Baslik from '../components/Baslik';
import { Yukleniyor } from '../components/UI';
import type { EkranProps } from '../navigation';

type Konusma = Record<string, any>;

export default function Mesajlar({ navigation }: EkranProps<'Mesajlar'>) {
  const [konusmalar, setKonusmalar] = useState<Konusma[]>([]);
  const [yukleniyor, setYukleniyor] = useState(true);
  const [yenileniyor, setYenileniyor] = useState(false);
  const [uid, setUid] = useState<string | null>(null);

  const yukle = useCallback(async () => {
    const { data: kul } = await supabase.auth.getUser();
    const user = kul.user;
    setUid(user?.id ?? null);

    if (user) {
      try {
        const { data } = await supabase
          .from('konusmalar')
          .select('*, ilanlar(baslik)')
          .or(`gonderen_id.eq.${user.id},alici_id.eq.${user.id}`)
          .order('olusturulma_tarihi', { ascending: false });
        setKonusmalar((data ?? []) as Konusma[]);
      } catch {
        // yoksay
      }
    }

    await mesajlariGorulduIsaretle();
    setYukleniyor(false);
  }, []);

  useEffect(() => {
    yukle();
  }, [yukle]);

  useFocusEffect(
    useCallback(() => {
      yukle();
    }, [yukle])
  );

  const yenile = async () => {
    setYenileniyor(true);
    await yukle();
    setYenileniyor(false);
  };

  if (yukleniyor) {
    return (
      <View style={styles.kap}>
        <Baslik baslik="Mesajlarım" />
        <Yukleniyor />
      </View>
    );
  }

  return (
    <View style={styles.kap}>
      <Baslik baslik="Mesajlarım" />
      {uid == null ? (
        <View style={styles.merkez}>
          <Text>Bu sayfayı görmek için giriş yapmalısın.</Text>
        </View>
      ) : konusmalar.length === 0 ? (
        <View style={styles.merkez}>
          <Text style={styles.bosYazi}>Henüz bir mesajlaşman yok.</Text>
        </View>
      ) : (
        <FlatList
          data={konusmalar}
          keyExtractor={(k) => k.id}
          contentContainerStyle={styles.liste}
          ItemSeparatorComponent={() => <View style={{ height: 10 }} />}
          refreshControl={
            <RefreshControl refreshing={yenileniyor} onRefresh={yenile} tintColor={renkOrman} />
          }
          renderItem={({ item }) => {
            const benBasladim = item.gonderen_id === uid;
            const baslik = (item.ilanlar?.baslik as string) ?? 'İlan';
            return (
              <Pressable
                style={styles.satir}
                onPress={() =>
                  navigation.navigate('MesajDetay', {
                    konusmaId: item.id as string,
                    ilanId: item.ilan_id as string,
                    ilanBasligi: baslik,
                  })
                }
              >
                <View style={{ flex: 1 }}>
                  <Text style={styles.satirBaslik}>{baslik}</Text>
                  <Text style={styles.satirAlt}>
                    {benBasladim ? 'Sen mesaj gönderdin' : 'Sana mesaj geldi'}
                  </Text>
                </View>
                <Text style={styles.chevron}>›</Text>
              </Pressable>
            );
          }}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  kap: { flex: 1, backgroundColor: renkZemin },
  merkez: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  bosYazi: { color: saydam(renkInk, 0.5), fontStyle: 'italic' },
  liste: { padding: 16 },
  satir: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 14,
    backgroundColor: renkKart,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: renkCizgi,
  },
  satirBaslik: { fontSize: 15, fontWeight: '600', color: renkInk },
  satirAlt: { marginTop: 2, fontSize: 11, color: saydam(renkInk, 0.5) },
  chevron: { fontSize: 22, color: saydam(renkInk, 0.3) },
});
