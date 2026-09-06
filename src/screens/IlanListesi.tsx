import { useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  TextInput,
  FlatList,
  ScrollView,
  Pressable,
  Image,
  RefreshControl,
  useWindowDimensions,
  StyleSheet,
  NativeSyntheticEvent,
  NativeScrollEvent,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { supabase } from '../lib/supabase';
import {
  renkZemin,
  renkInk,
  renkOrman,
  renkCizgi,
  renkNeed,
  renkGo,
  renkGorselZemin,
  saydam,
} from '../tema';
import { Yukleniyor } from '../components/UI';

const NG_LOGO = require('../../assets/images/needgo-n.png');

export const kategoriler = [
  'Mobilya',
  'Elektronik',
  'Ev & Yaşam',
  'Giyim',
  'Aksesuar',
  'Kişisel Bakım & Kozmetik',
  'Oyuncak',
  'Ofis & Kırtasiye',
  'Yapı & Market',
  'Pet Shop',
  'Antika',
];

type HeroSlayt = {
  eyebrow: string;
  baslik: string;
  aciklama: string;
  altNot?: string;
  ikiTonluEyebrow?: boolean;
};

const heroSlaytlari: HeroSlayt[] = [
  {
    eyebrow: 'Atma · Paylaş · Dönüştür',
    baslik: 'Kullanmadığın eşya, birinin ihtiyacı olsun.',
    aciklama: 'NeedGO’da her şey ücretsiz, sadece paylaşım geçer.',
    altNot: 'Paylaşmak iyileştirir.',
  },
  {
    eyebrow: 'Neden NeedGO?',
    ikiTonluEyebrow: true,
    baslik: 'Çevre Koruma ve Sıfır Atık',
    aciklama:
      'Kullanılabilir durumdaki eşyaların çöp sahalarına gitmesini engelleyerek atık oluşumunu azaltır ve karbon ayak izini düşürmeye doğrudan katkı sağlar.',
  },
  {
    eyebrow: 'Neden NeedGO?',
    ikiTonluEyebrow: true,
    baslik: 'Döngüsel Ekonomi ve Kaynak Verimliliği',
    aciklama:
      'Eşyaların kullanım ömrünü tek bir sahipten öteye taşıyarak kaynakların yeniden ve verimli bir şekilde değerlendirilmesini destekler.',
  },
  {
    eyebrow: 'Neden NeedGO?',
    ikiTonluEyebrow: true,
    baslik: 'Sosyal Dayanışma ve Komşuluk',
    aciklama:
      'İhtiyaç sahibi kişilerle eşya paylaşmak isteyenleri para ve komisyon olmaksızın bir araya getirerek toplumsal dayanışmayı güçlendirir.',
  },
  {
    eyebrow: 'Neden NeedGO?',
    ikiTonluEyebrow: true,
    baslik: 'Öğrenci ve Ev Kuracaklara Destek',
    aciklama:
      'Öğrencilerin kitap, ders aracı veya eşya ihtiyaçlarını; yeni eve taşınanların ise mobilya ve ev gereksinimlerini bütçe yükü olmadan karşılamalarına imkan tanır.',
  },
  {
    eyebrow: 'Neden NeedGO?',
    ikiTonluEyebrow: true,
    baslik: 'STK ve Kurumsal İhtiyaç Kanalları',
    aciklama:
      'Dernekler, topluluklar veya belediyeler için ihtiyaç sahibi ailelere ulaştırılmak üzere toplu eşya temin edilebilecek sürdürülebilir bir kaynak oluşturur.',
  },
];

export type Ilan = {
  id: string;
  baslik: string;
  aciklama: string | null;
  kategori: string | null;
  konum: string | null;
  fotograf_url: string | null;
};

type Props = {
  onIlanPress: (ilanId: string) => void;
};

export default function IlanListesi({ onIlanPress }: Props) {
  const [ilanlar, setIlanlar] = useState<Ilan[]>([]);
  const [yukleniyor, setYukleniyor] = useState(true);
  const [hata, setHata] = useState('');
  const [seciliKategori, setSeciliKategori] = useState<string | null>(null);
  const [aramaMetni, setAramaMetni] = useState('');
  const [yenileniyor, setYenileniyor] = useState(false);

  const ilanlariGetir = useCallback(async () => {
    setHata('');
    try {
      const { data, error } = await supabase
        .from('ilanlar')
        .select()
        .eq('durum', 'aktif')
        .order('olusturulma_tarihi', { ascending: false });
      if (error) throw error;
      setIlanlar((data ?? []) as Ilan[]);
    } catch (e) {
      setHata(`İlanlar yüklenemedi: ${e}`);
    } finally {
      setYukleniyor(false);
    }
  }, []);

  useEffect(() => {
    ilanlariGetir();
  }, [ilanlariGetir]);

  useFocusEffect(
    useCallback(() => {
      ilanlariGetir();
    }, [ilanlariGetir])
  );

  const yenile = async () => {
    setYenileniyor(true);
    await ilanlariGetir();
    setYenileniyor(false);
  };

  const gosterilenIlanlar = ilanlar.filter((ilan) => {
    const kategoriUyuyor =
      seciliKategori == null ||
      (ilan.kategori?.toLowerCase() ?? '') === seciliKategori.toLowerCase();
    const aramaUyuyor =
      aramaMetni.trim() === '' ||
      ilan.baslik.toLowerCase().includes(aramaMetni.toLowerCase());
    return kategoriUyuyor && aramaUyuyor;
  });

  const kategoriCip = (etiket: string, aktif: boolean, onPress: () => void) => (
    <Pressable
      key={etiket}
      onPress={onPress}
      style={[styles.cip, aktif ? styles.cipAktif : styles.cipPasif]}
    >
      <Text
        style={[styles.cipYazi, { color: aktif ? '#FFFFFF' : saydam(renkInk, 0.7) }]}
      >
        {etiket}
      </Text>
    </Pressable>
  );

  const baslikBolumu = (
    <View>
      <HeroSlider />
      <View style={styles.aramaKap}>
        <TextInput
          value={aramaMetni}
          onChangeText={setAramaMetni}
          placeholder="İlan, kategori ara"
          placeholderTextColor={saydam(renkInk, 0.4)}
          style={styles.arama}
        />
      </View>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.cipSatir}
      >
        {kategoriCip('Tümü', seciliKategori == null, () => setSeciliKategori(null))}
        {kategoriler.map((kat) =>
          kategoriCip(kat, seciliKategori === kat, () => setSeciliKategori(kat))
        )}
      </ScrollView>
      <View style={styles.bolumBaslik}>
        <Text style={styles.bolumBaslikYazi}>{seciliKategori ?? 'Güncel İlanlar'}</Text>
        <Text style={styles.bolumSayi}>{gosterilenIlanlar.length} ilan</Text>
      </View>
      {hata ? <Text style={styles.hata}>{hata}</Text> : null}
      {!yukleniyor && !hata && gosterilenIlanlar.length === 0 ? (
        <Text style={styles.bosYazi}>Bu kriterlere uyan ilan yok.</Text>
      ) : null}
    </View>
  );

  if (yukleniyor) {
    return (
      <View style={styles.kap}>
        {baslikBolumu}
        <Yukleniyor />
      </View>
    );
  }

  return (
    <FlatList
      style={styles.kap}
      data={gosterilenIlanlar}
      keyExtractor={(item) => item.id}
      numColumns={2}
      columnWrapperStyle={styles.satirBosluk}
      contentContainerStyle={styles.listeIcerik}
      ListHeaderComponent={baslikBolumu}
      refreshControl={
        <RefreshControl refreshing={yenileniyor} onRefresh={yenile} tintColor={renkOrman} />
      }
      renderItem={({ item }) => (
        <Pressable style={styles.kartKap} onPress={() => onIlanPress(item.id)}>
          <IlanKarti ilan={item} />
        </Pressable>
      )}
    />
  );
}

function IlanKarti({ ilan }: { ilan: Ilan }) {
  const altBilgi = [ilan.konum, ilan.kategori]
    .filter((e) => e && e.trim() !== '')
    .join(' · ');

  return (
    <View>
      <View style={styles.gorselKap}>
        {ilan.fotograf_url ? (
          <Image source={{ uri: ilan.fotograf_url }} style={styles.gorsel} resizeMode="cover" />
        ) : (
          <View style={styles.yerTutucu}>
            <Image source={NG_LOGO} style={styles.yerTutucuLogo} />
          </View>
        )}
        <View style={styles.kalpRozet}>
          <Text style={{ color: saydam(renkInk, 0.5), fontSize: 15 }}>♡</Text>
        </View>
      </View>
      <Text style={styles.kartBaslik} numberOfLines={1}>
        {ilan.baslik}
      </Text>
      <Text style={styles.kartUcretsiz}>Ücretsiz</Text>
      {altBilgi ? (
        <Text style={styles.kartAlt} numberOfLines={1}>
          {altBilgi}
        </Text>
      ) : null}
    </View>
  );
}

function HeroSlider() {
  const { width } = useWindowDimensions();
  const genislik = width - 32; // yatay 16 margin
  const listRef = useRef<FlatList>(null);
  const [aktif, setAktif] = useState(0);
  const aktifRef = useRef(0);

  useEffect(() => {
    const t = setInterval(() => {
      const sonraki = (aktifRef.current + 1) % heroSlaytlari.length;
      listRef.current?.scrollToOffset({ offset: sonraki * genislik, animated: true });
    }, 6500);
    return () => clearInterval(t);
  }, [genislik]);

  const onScroll = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    const i = Math.round(e.nativeEvent.contentOffset.x / genislik);
    if (i !== aktifRef.current) {
      aktifRef.current = i;
      setAktif(i);
    }
  };

  return (
    <View style={styles.heroKap}>
      <FlatList
        ref={listRef}
        data={heroSlaytlari}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={onScroll}
        keyExtractor={(_, i) => String(i)}
        renderItem={({ item }) => (
          <View style={[styles.heroSlayt, { width: genislik }]}>
            <View style={styles.eyebrowKap}>
              {item.ikiTonluEyebrow ? (
                <Text style={styles.eyebrowIkiTonlu}>
                  <Text style={{ color: saydam(renkInk, 0.7) }}>Neden </Text>
                  <Text style={{ color: renkNeed }}>Need</Text>
                  <Text style={{ color: renkGo }}>GO</Text>
                  <Text style={{ color: saydam(renkInk, 0.7) }}>?</Text>
                </Text>
              ) : (
                <Text style={styles.eyebrow}>{item.eyebrow.toUpperCase()}</Text>
              )}
            </View>
            <Text style={styles.heroBaslik} numberOfLines={2}>
              {item.baslik}
            </Text>
            <Text style={styles.heroAciklama} numberOfLines={3}>
              {item.aciklama}
            </Text>
            {item.altNot ? <Text style={styles.heroAltNot}>{item.altNot}</Text> : null}
          </View>
        )}
      />
      <View style={styles.noktalar}>
        {heroSlaytlari.map((_, i) => (
          <View
            key={i}
            style={[
              styles.nokta,
              i === aktif
                ? { width: 20, backgroundColor: renkOrman }
                : { width: 7, backgroundColor: saydam(renkInk, 0.2) },
            ]}
          />
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  kap: { flex: 1, backgroundColor: renkZemin },
  listeIcerik: { paddingHorizontal: 16, paddingBottom: 96 },
  satirBosluk: { gap: 14 },
  kartKap: { flex: 1, marginBottom: 22 },

  aramaKap: { paddingHorizontal: 0, paddingTop: 16, paddingBottom: 8 },
  arama: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: renkCizgi,
    borderRadius: 24,
    paddingHorizontal: 18,
    paddingVertical: 12,
    fontSize: 14,
    color: '#111111',
  },
  cipSatir: { gap: 6, paddingVertical: 4 },
  cip: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 20,
    borderWidth: 1,
    justifyContent: 'center',
  },
  cipAktif: { backgroundColor: renkOrman, borderColor: renkOrman },
  cipPasif: { backgroundColor: '#FFFFFF', borderColor: renkCizgi },
  cipYazi: { fontSize: 11, fontWeight: '600' },

  bolumBaslik: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: 12,
    paddingBottom: 8,
  },
  bolumBaslikYazi: { fontSize: 20, fontWeight: '700', color: renkInk },
  bolumSayi: { fontSize: 12, color: saydam('#000000', 0.54) },
  hata: { color: 'red', paddingVertical: 24, textAlign: 'center' },
  bosYazi: { paddingVertical: 24, textAlign: 'center', color: saydam(renkInk, 0.6) },

  gorselKap: {
    aspectRatio: 4 / 5,
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: renkGorselZemin,
  },
  gorsel: { width: '100%', height: '100%' },
  yerTutucu: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: renkGorselZemin,
  },
  yerTutucuLogo: { width: 44, height: 44, opacity: 0.15 },
  kalpRozet: {
    position: 'absolute',
    top: 10,
    right: 10,
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255,255,255,0.75)',
  },
  kartBaslik: {
    marginTop: 10,
    fontSize: 15,
    fontWeight: '600',
    color: renkInk,
  },
  kartUcretsiz: { marginTop: 2, fontSize: 13, color: saydam(renkInk, 0.7) },
  kartAlt: { marginTop: 6, fontSize: 11, color: saydam(renkInk, 0.4) },

  heroKap: {
    marginTop: 16,
    paddingVertical: 20,
    borderRadius: 18,
    backgroundColor: saydam(renkNeed, 0.1),
  },
  heroSlayt: { paddingHorizontal: 20, alignItems: 'center' },
  eyebrowKap: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: saydam(renkOrman, 0.3),
    backgroundColor: saydam(renkOrman, 0.05),
    marginBottom: 12,
  },
  eyebrow: {
    fontSize: 10,
    fontWeight: '600',
    letterSpacing: 1.5,
    color: renkOrman,
  },
  eyebrowIkiTonlu: { fontSize: 11, fontWeight: '600' },
  heroBaslik: {
    fontSize: 19,
    fontWeight: '700',
    color: renkInk,
    textAlign: 'center',
    lineHeight: 23,
  },
  heroAciklama: {
    marginTop: 8,
    fontSize: 12.5,
    lineHeight: 18,
    color: saydam(renkInk, 0.6),
    textAlign: 'center',
  },
  heroAltNot: {
    marginTop: 8,
    fontSize: 13,
    fontStyle: 'italic',
    color: renkOrman,
  },
  noktalar: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: 12,
    gap: 6,
  },
  nokta: { height: 7, borderRadius: 999 },
});
