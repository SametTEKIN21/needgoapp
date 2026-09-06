import { useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  TextInput,
  FlatList,
  Pressable,
  KeyboardAvoidingView,
  Platform,
  useWindowDimensions,
  StyleSheet,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { supabase } from '../lib/supabase';
import { mesajlariGorulduIsaretle } from '../lib/mesajDeposu';
import { renkZemin, renkKart, renkInk, renkOrman, renkOcre, renkCizgi, saydam } from '../tema';
import Baslik from '../components/Baslik';
import { Yukleniyor } from '../components/UI';
import type { EkranProps } from '../navigation';

type Mesaj = Record<string, any>;

export default function MesajDetay({ route, navigation }: EkranProps<'MesajDetay'>) {
  const { konusmaId, ilanId, ilanBasligi } = route.params;
  const { width } = useWindowDimensions();
  const insets = useSafeAreaInsets();

  const [mesajlar, setMesajlar] = useState<Mesaj[]>([]);
  const [yukleniyor, setYukleniyor] = useState(true);
  const [gonderiliyor, setGonderiliyor] = useState(false);
  const [girdi, setGirdi] = useState('');
  const [uid, setUid] = useState<string | null>(null);
  const listRef = useRef<FlatList>(null);

  const mesajlariGetir = useCallback(async () => {
    try {
      const { data } = await supabase
        .from('mesajlar')
        .select('*')
        .eq('konusma_id', konusmaId)
        .order('olusturulma_tarihi', { ascending: true });
      setMesajlar((data ?? []) as Mesaj[]);
    } catch {
      // yoksay
    }
    await mesajlariGorulduIsaretle();
    setTimeout(() => listRef.current?.scrollToEnd({ animated: true }), 80);
  }, [konusmaId]);

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => setUid(data.user?.id ?? null));
    mesajlariGetir().then(() => setYukleniyor(false));
  }, [mesajlariGetir]);

  const gonder = async () => {
    const metin = girdi.trim();
    if (metin === '' || !uid) return;

    setGonderiliyor(true);
    try {
      const { error } = await supabase.from('mesajlar').insert({
        konusma_id: konusmaId,
        gonderen_id: uid,
        icerik: metin,
      });
      if (error) throw error;
      setGirdi('');
      await mesajlariGetir();
    } catch {
      // yoksay
    } finally {
      setGonderiliyor(false);
    }
  };

  return (
    <View style={styles.kap}>
      <Baslik
        baslik={ilanBasligi}
        saglar={
          <Pressable
            onPress={() => navigation.navigate('IlanDetay', { ilanId })}
            hitSlop={8}
            style={{ paddingHorizontal: 8 }}
          >
            <Text style={{ color: renkOrman, fontWeight: '600' }}>İlanı Gör</Text>
          </Pressable>
        }
      />

      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={insets.top + 52}
      >
        {yukleniyor ? (
          <Yukleniyor />
        ) : mesajlar.length === 0 ? (
          <View style={styles.merkez}>
            <Text style={styles.bosYazi}>Henüz mesaj yok. İlk mesajı sen gönder.</Text>
          </View>
        ) : (
          <FlatList
            ref={listRef}
            data={mesajlar}
            keyExtractor={(m) => m.id}
            contentContainerStyle={styles.liste}
            onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: false })}
            renderItem={({ item }) => {
              const benimMi = item.gonderen_id === uid;
              return (
                <View
                  style={[
                    styles.balon,
                    {
                      alignSelf: benimMi ? 'flex-end' : 'flex-start',
                      maxWidth: width * 0.75,
                      backgroundColor: benimMi ? renkOrman : renkKart,
                      borderWidth: benimMi ? 0 : 1,
                    },
                  ]}
                >
                  <Text style={{ fontSize: 14, color: benimMi ? '#FFFFFF' : '#111111' }}>
                    {(item.icerik as string) ?? ''}
                  </Text>
                </View>
              );
            }}
          />
        )}

        <View style={[styles.girdiKap, { paddingBottom: 12 + insets.bottom }]}>
          <TextInput
            value={girdi}
            onChangeText={setGirdi}
            placeholder="Mesaj yaz…"
            placeholderTextColor={saydam(renkInk, 0.4)}
            style={styles.girdi}
            returnKeyType="send"
            onSubmitEditing={gonder}
          />
          <Pressable
            onPress={gonderiliyor ? undefined : gonder}
            style={[styles.gonderDugme, gonderiliyor && { opacity: 0.5 }]}
          >
            <Text style={styles.gonderYazi}>Gönder</Text>
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  kap: { flex: 1, backgroundColor: renkZemin },
  merkez: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  bosYazi: { color: saydam(renkInk, 0.5), fontStyle: 'italic' },
  liste: { padding: 16 },
  balon: {
    marginBottom: 8,
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 12,
    borderColor: renkCizgi,
  },
  girdiKap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 12,
    paddingTop: 8,
    backgroundColor: renkKart,
    borderTopWidth: 1,
    borderTopColor: renkCizgi,
  },
  girdi: {
    flex: 1,
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: renkCizgi,
    borderRadius: 999,
    paddingHorizontal: 16,
    paddingVertical: 12,
    color: '#111111',
  },
  gonderDugme: {
    backgroundColor: renkOcre,
    borderRadius: 999,
    paddingHorizontal: 18,
    paddingVertical: 14,
  },
  gonderYazi: { color: '#FFFFFF', fontWeight: '600' },
});
