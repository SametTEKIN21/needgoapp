import { useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  Image,
  ScrollView,
  FlatList,
  Pressable,
  useWindowDimensions,
  StyleSheet,
  NativeSyntheticEvent,
  NativeScrollEvent,
} from 'react-native';
import { supabase } from '../lib/supabase';
import { kotaDurumu, tarihMetni, KotaDurumu } from '../lib/kota';
import { profilTamMi } from '../lib/profil';
import {
  renkZemin,
  renkInk,
  renkOrman,
  renkCizgi,
  renkHata,
  renkGorselZemin,
  saydam,
} from '../tema';
import Baslik from '../components/Baslik';
import { Yukleniyor } from '../components/UI';
import type { EkranProps } from '../navigation';

type IlanKaydi = Record<string, any>;

export default function IlanDetay({ route, navigation }: EkranProps<'IlanDetay'>) {
  const { ilanId } = route.params;
  const { width } = useWindowDimensions();

  const [ilan, setIlan] = useState<IlanKaydi | null>(null);
  const [yukleniyor, setYukleniyor] = useState(true);
  const [begenildi, setBegenildi] = useState(false);
  const [aktifFoto, setAktifFoto] = useState(0);
  const [kota, setKota] = useState<KotaDurumu | null>(null);
  const [mevcutKonusmaId, setMevcutKonusmaId] = useState<string | null>(null);
  const [mesajIslemde, setMesajIslemde] = useState(false);
  const [mesajHata, setMesajHata] = useState('');
  const sayacArtirildi = useRef(false);
  const fotoRef = useRef<FlatList>(null);

  const getir = useCallback(async () => {
    try {
      const { data: veri, error } = await supabase
        .from('ilanlar')
        .select()
        .eq('id', ilanId)
        .single();
      if (error) throw error;

      setIlan(veri);
      setYukleniyor(false);

      const { data: kul } = await supabase.auth.getUser();
      const kullanici = kul.user;
      if (kullanici && veri.user_id !== kullanici.id) {
        kotaDurumu(kullanici.id)
          .then((k) => setKota(k))
          .catch(() => {});
        try {
          const { data: k } = await supabase
            .from('konusmalar')
            .select('id')
            .eq('ilan_id', ilanId)
            .eq('gonderen_id', kullanici.id)
            .maybeSingle();
          if (k) setMevcutKonusmaId(k.id as string);
        } catch {
          // yoksay
        }
      }

      if (!sayacArtirildi.current) {
        sayacArtirildi.current = true;
        // Sayaç, ilan sahibi olmayanlar da artırabilsin diye RPC ile güncellenir
        // (ilanlar tablosunda UPDATE yetkisi yalnızca sahibinde).
        await supabase.rpc('ilan_goruntulendi', { p_ilan_id: ilanId });
      }
    } catch {
      setYukleniyor(false);
    }
  }, [ilanId]);

  useEffect(() => {
    getir();
  }, [getir]);

  const fotoListesi: string[] = (() => {
    if (!ilan) return [];
    const fotograflar = ilan.fotograflar;
    if (Array.isArray(fotograflar) && fotograflar.length > 0) {
      return fotograflar.map((e: unknown) => String(e));
    }
    const tek = ilan.fotograf_url as string | null;
    return tek ? [tek] : [];
  })();

  const begen = async () => {
    if (!ilan || begenildi) return;
    const yeni = ((ilan.begeni_sayisi as number | null) ?? 0) + 1;
    try {
      const { error } = await supabase.rpc('ilan_begenildi', { p_ilan_id: ilanId });
      if (error) throw error;
      setIlan({ ...ilan, begeni_sayisi: yeni });
      setBegenildi(true);
    } catch {
      // sessizce yoksay
    }
  };

  const sohbeteGit = (konusmaId: string) => {
    navigation.navigate('MesajDetay', {
      konusmaId,
      ilanId,
      ilanBasligi: (ilan?.baslik as string) ?? 'İlan',
    });
  };

  const mesajGonder = async () => {
    const { data: kul } = await supabase.auth.getUser();
    const kullanici = kul.user;
    if (!ilan || !kullanici) return;

    setMesajHata('');
    setMesajIslemde(true);

    if (mevcutKonusmaId) {
      setMesajIslemde(false);
      sohbeteGit(mevcutKonusmaId);
      return;
    }

    if (!(await profilTamMi())) {
      setMesajIslemde(false);
      navigation.navigate('Profil');
      return;
    }

    if (kota && kota.kalan === 0) {
      setMesajIslemde(false);
      setMesajHata(
        kota.yenilenmeTarihi
          ? `Son 30 günde 3 eşya aldın. Yeni istek gönderebilmen için ${tarihMetni(kota.yenilenmeTarihi)} tarihini beklemelisin.`
          : 'Son 30 günde 3 eşya aldın. Yeni istek gönderemezsin.'
      );
      return;
    }

    try {
      const { data: yeni, error } = await supabase
        .from('konusmalar')
        .insert({
          ilan_id: ilanId,
          gonderen_id: kullanici.id,
          alici_id: ilan.user_id,
          gonderen_email: kullanici.email,
        })
        .select('id')
        .single();
      if (error) throw error;

      setMesajIslemde(false);
      setMevcutKonusmaId(yeni.id as string);
      sohbeteGit(yeni.id as string);
    } catch (e) {
      setMesajIslemde(false);
      setMesajHata(`Bir hata oluştu: ${e}`);
    }
  };

  const onFotoScroll = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    setAktifFoto(Math.round(e.nativeEvent.contentOffset.x / width));
  };

  const fotoGec = (yon: number) => {
    if (fotoListesi.length < 2) return;
    const hedef = (aktifFoto + yon + fotoListesi.length) % fotoListesi.length;
    fotoRef.current?.scrollToOffset({ offset: hedef * width, animated: true });
  };

  if (yukleniyor) {
    return (
      <View style={styles.kap}>
        <Baslik baslik="İlan Detayı" />
        <Yukleniyor />
      </View>
    );
  }

  if (!ilan) {
    return (
      <View style={styles.kap}>
        <Baslik baslik="İlan Detayı" />
        <View style={styles.merkez}>
          <Text>İlan bulunamadı.</Text>
        </View>
      </View>
    );
  }

  const baslik = (ilan.baslik as string) ?? '';
  const aciklama = ilan.aciklama as string | null;
  const kategori = ilan.kategori as string | null;
  const konum = ilan.konum as string | null;
  const goruntulenme = (ilan.goruntulenme_sayisi as number | null) ?? 0;
  const begeni = (ilan.begeni_sayisi as number | null) ?? 0;

  return (
    <View style={styles.kap}>
      <Baslik baslik="İlan Detayı" />
      <ScrollView>
        <View style={[styles.galeriKap, { width, height: (width * 3) / 4 }]}>
          {fotoListesi.length === 0 ? (
            <View style={styles.fotoBos}>
              <Text style={styles.ngYazi}>NG</Text>
            </View>
          ) : (
            <FlatList
              ref={fotoRef}
              data={fotoListesi}
              horizontal
              pagingEnabled
              showsHorizontalScrollIndicator={false}
              onMomentumScrollEnd={onFotoScroll}
              keyExtractor={(_, i) => String(i)}
              renderItem={({ item }) => (
                <Image
                  source={{ uri: item }}
                  style={{ width, height: (width * 3) / 4 }}
                  resizeMode="contain"
                />
              )}
            />
          )}

          {fotoListesi.length > 1 && (
            <>
              <Pressable style={[styles.ok, { left: 8 }]} onPress={() => fotoGec(-1)}>
                <Text style={styles.okYazi}>‹</Text>
              </Pressable>
              <Pressable style={[styles.ok, { right: 8 }]} onPress={() => fotoGec(1)}>
                <Text style={styles.okYazi}>›</Text>
              </Pressable>
              <View style={styles.noktalar}>
                {fotoListesi.map((_, i) => (
                  <View
                    key={i}
                    style={[
                      styles.nokta,
                      { backgroundColor: i === aktifFoto ? '#FFFFFF' : 'rgba(255,255,255,0.5)' },
                    ]}
                  />
                ))}
              </View>
              <View style={styles.sayac}>
                <Text style={styles.sayacYazi}>
                  {aktifFoto + 1}/{fotoListesi.length}
                </Text>
              </View>
            </>
          )}

          <View style={styles.ucretsizRozet}>
            <Text style={styles.ucretsizYazi}>Ücretsiz</Text>
          </View>
        </View>

        <View style={styles.govde}>
          <View style={styles.baslikSatir}>
            <Text style={styles.baslik}>{baslik}</Text>
            <Pressable
              onPress={begenildi ? undefined : begen}
              style={[
                styles.begeniDugme,
                { borderColor: begenildi ? renkOrman : saydam('#000000', 0.26) },
              ]}
            >
              <Text style={{ color: begenildi ? renkOrman : renkInk }}>
                {begenildi ? `♥ ${begeni}` : `♡ ${begeni}`}
              </Text>
            </Pressable>
          </View>

          <View style={styles.metaSatir}>
            {kategori ? <Text style={styles.meta}>{kategori}</Text> : null}
            {konum ? <Text style={styles.meta}>· {konum}</Text> : null}
            <Text style={styles.meta}>· {goruntulenme} görüntülenme</Text>
          </View>

          {aciklama ? <Text style={styles.aciklama}>{aciklama}</Text> : null}

          <View style={styles.ayrac} />

          <MesajBolumu
            ilan={ilan}
            kota={kota}
            mevcutKonusmaId={mevcutKonusmaId}
            mesajIslemde={mesajIslemde}
            mesajHata={mesajHata}
            onGonder={mesajGonder}
            onProfilAc={() => navigation.navigate('Profil')}
          />
        </View>
      </ScrollView>
    </View>
  );
}

function MesajBolumu({
  ilan,
  kota,
  mevcutKonusmaId,
  mesajIslemde,
  mesajHata,
  onGonder,
  onProfilAc,
}: {
  ilan: IlanKaydi;
  kota: KotaDurumu | null;
  mevcutKonusmaId: string | null;
  mesajIslemde: boolean;
  mesajHata: string;
  onGonder: () => void;
  onProfilAc: () => void;
}) {
  const [kullaniciId, setKullaniciId] = useState<string | null | undefined>(undefined);
  const [profilTam, setProfilTam] = useState(false);

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => setKullaniciId(data.user?.id ?? null));
    profilTamMi().then(setProfilTam);
  }, []);

  if (kullaniciId === undefined) return null;

  if (kullaniciId === null) {
    return (
      <Text style={styles.mesajNot}>İlan sahibiyle mesajlaşmak için giriş yapmalısın.</Text>
    );
  }

  if (ilan.user_id === kullaniciId) {
    return <Text style={styles.mesajNot}>Bu senin kendi ilanın.</Text>;
  }

  const mevcutSohbet = mevcutKonusmaId != null;
  const profilEksik = !profilTam && !mevcutSohbet;
  const kotaDolu = !profilEksik && !mevcutSohbet && kota != null && kota.kalan === 0;

  return (
    <View>
      <Pressable
        onPress={mesajIslemde || kotaDolu || profilEksik ? undefined : onGonder}
        style={[
          styles.mesajDugme,
          (mesajIslemde || kotaDolu || profilEksik) && { opacity: 0.5 },
        ]}
      >
        <Text style={styles.mesajDugmeYazi}>
          {mesajIslemde ? 'Açılıyor…' : mevcutSohbet ? 'Sohbete Dön' : 'Mesaj Gönder'}
        </Text>
      </Pressable>

      {profilEksik && (
        <Pressable onPress={onProfilAc}>
          <Text style={styles.mesajUyari}>
            Mesaj göndermeden önce profil bilgilerini tamamlamalısın.
          </Text>
        </Pressable>
      )}

      {kotaDolu && (
        <Text style={styles.mesajUyari}>
          {kota?.yenilenmeTarihi
            ? `Son 30 günde 3 eşya aldın. Yeni istek gönderebilmen için ${tarihMetni(kota.yenilenmeTarihi)} tarihini beklemelisin.`
            : 'Son 30 günde 3 eşya aldın. Yeni istek gönderemezsin.'}
        </Text>
      )}

      {!kotaDolu && !!mesajHata && <Text style={styles.mesajUyari}>{mesajHata}</Text>}

      {!kotaDolu &&
        !mevcutSohbet &&
        kota != null &&
        kota.kalan > 0 &&
        kota.kalan < 3 && (
          <Text style={styles.kotaNot}>Kalan alma hakkın: {kota.kalan}/3 (son 30 gün)</Text>
        )}
    </View>
  );
}

const styles = StyleSheet.create({
  kap: { flex: 1, backgroundColor: renkZemin },
  merkez: { flex: 1, alignItems: 'center', justifyContent: 'center' },

  galeriKap: { backgroundColor: renkGorselZemin },
  fotoBos: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  ngYazi: { fontSize: 40, color: 'rgba(0,0,0,0.15)' },
  ok: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
    width: 32,
  },
  okYazi: {
    fontSize: 34,
    color: renkInk,
    backgroundColor: 'rgba(255,255,255,0.85)',
    borderRadius: 999,
    width: 32,
    height: 32,
    textAlign: 'center',
    lineHeight: 34,
    overflow: 'hidden',
  },
  noktalar: {
    position: 'absolute',
    bottom: 12,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 6,
  },
  nokta: { width: 7, height: 7, borderRadius: 999 },
  sayac: {
    position: 'absolute',
    bottom: 12,
    right: 12,
    backgroundColor: 'rgba(0,0,0,0.55)',
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  sayacYazi: { color: '#FFFFFF', fontSize: 11, fontWeight: '600' },
  ucretsizRozet: {
    position: 'absolute',
    top: 12,
    right: 12,
    backgroundColor: 'rgba(255,255,255,0.9)',
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 5,
  },
  ucretsizYazi: { fontSize: 11, fontWeight: '600', color: renkInk },

  govde: { padding: 16 },
  baslikSatir: { flexDirection: 'row', alignItems: 'flex-start', gap: 8 },
  baslik: { flex: 1, fontSize: 22, fontWeight: '700', color: renkInk },
  begeniDugme: {
    borderWidth: 1,
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 6,
  },
  metaSatir: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 8 },
  meta: { fontSize: 11, color: 'rgba(0,0,0,0.54)' },
  aciklama: { marginTop: 16, fontSize: 14, lineHeight: 21, color: renkInk },
  ayrac: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: renkCizgi,
    marginVertical: 20,
  },

  mesajNot: { fontSize: 12, color: saydam(renkInk, 0.5) },
  mesajDugme: {
    alignSelf: 'flex-start',
    backgroundColor: renkOrman,
    borderRadius: 999,
    paddingHorizontal: 22,
    paddingVertical: 12,
  },
  mesajDugmeYazi: { color: '#FFFFFF', fontWeight: '600' },
  mesajUyari: { marginTop: 8, fontSize: 12, color: renkHata },
  kotaNot: { marginTop: 8, fontSize: 12, color: saydam(renkInk, 0.5) },
});
