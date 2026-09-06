import { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  FlatList,
  Image,
  Pressable,
  Alert,
  RefreshControl,
  StyleSheet,
} from 'react-native';
import { supabase } from '../lib/supabase';
import { alinanEsyaSayisi, aylikAlmaHakki } from '../lib/kota';
import {
  renkZemin,
  renkKart,
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

type Ilan = Record<string, any>;
type Aday = { gonderenId: string; gonderenEposta: string | null; kotaDolu: boolean };

export default function Ilanlarim(_props: EkranProps<'Ilanlarim'>) {
  const [ilanlar, setIlanlar] = useState<Ilan[]>([]);
  const [yukleniyor, setYukleniyor] = useState(true);
  const [yenileniyor, setYenileniyor] = useState(false);
  const [islemdekiId, setIslemdekiId] = useState<string | null>(null);

  const [bagisPaneliId, setBagisPaneliId] = useState<string | null>(null);
  const [adaylar, setAdaylar] = useState<Aday[]>([]);
  const [seciliAlici, setSeciliAlici] = useState<string | null>(null);
  const [panelYukleniyor, setPanelYukleniyor] = useState(false);
  const [bagisHata, setBagisHata] = useState('');

  const ilanlariGetir = useCallback(async () => {
    const { data: kul } = await supabase.auth.getUser();
    const kullanici = kul.user;
    if (!kullanici) {
      setYukleniyor(false);
      return;
    }
    try {
      const { data, error } = await supabase
        .from('ilanlar')
        .select()
        .eq('user_id', kullanici.id)
        .order('olusturulma_tarihi', { ascending: false });
      if (error) throw error;
      setIlanlar((data ?? []) as Ilan[]);
    } catch {
      // yoksay
    } finally {
      setYukleniyor(false);
    }
  }, []);

  useEffect(() => {
    ilanlariGetir();
  }, [ilanlariGetir]);

  const yenile = async () => {
    setYenileniyor(true);
    await ilanlariGetir();
    setYenileniyor(false);
  };

  const durumGuncelleYerel = (id: string, durum: string) => {
    setIlanlar((mevcut) =>
      mevcut.map((i) => (i.id === id ? { ...i, durum } : i))
    );
  };

  const durumDegistir = async (id: string, yeniDurum: string) => {
    setIslemdekiId(id);
    try {
      const guncelleme =
        yeniDurum === 'aktif'
          ? { durum: 'aktif', alici_id: null, bagis_tarihi: null }
          : { durum: yeniDurum };
      await supabase.from('ilanlar').update(guncelleme).eq('id', id);
      durumGuncelleYerel(id, yeniDurum);
    } catch {
      // sessizce yoksay
    } finally {
      setIslemdekiId(null);
    }
  };

  const bagisPaneliKapat = () => {
    setBagisPaneliId(null);
    setAdaylar([]);
    setSeciliAlici(null);
    setBagisHata('');
  };

  const bagisPaneliAc = async (ilanId: string) => {
    setBagisHata('');
    setSeciliAlici(null);
    setBagisPaneliId(ilanId);
    setAdaylar([]);
    setPanelYukleniyor(true);

    try {
      const { data, error } = await supabase
        .from('konusmalar')
        .select('gonderen_id, gonderen_email')
        .eq('ilan_id', ilanId);
      if (error) throw error;

      const benzersiz = new Map<string, string | null>();
      for (const k of data ?? []) {
        const gid = (k as any).gonderen_id as string;
        if (!benzersiz.has(gid)) benzersiz.set(gid, (k as any).gonderen_email ?? null);
      }

      const liste: Aday[] = [];
      for (const [gid, eposta] of benzersiz) {
        const dolu = (await alinanEsyaSayisi(gid)) >= aylikAlmaHakki;
        liste.push({ gonderenId: gid, gonderenEposta: eposta, kotaDolu: dolu });
      }
      setAdaylar(liste);
    } catch {
      setBagisHata('Alıcılar yüklenemedi.');
    } finally {
      setPanelYukleniyor(false);
    }
  };

  const bagisOnayla = async (ilanId: string) => {
    if (!seciliAlici) return;
    setBagisHata('');
    setIslemdekiId(ilanId);

    try {
      const { error } = await supabase
        .from('ilanlar')
        .update({
          durum: 'bagislandi',
          alici_id: seciliAlici,
          bagis_tarihi: new Date().toISOString(),
        })
        .eq('id', ilanId);
      if (error) throw error;

      durumGuncelleYerel(ilanId, 'bagislandi');
      setIslemdekiId(null);
      bagisPaneliKapat();
    } catch (e: any) {
      setIslemdekiId(null);
      const msj = e?.message ?? String(e);
      setBagisHata(
        msj.includes('KOTA_DOLU')
          ? 'Bu kişi son 30 günde zaten 3 eşya aldı, şu an bağış yapılamaz.'
          : `Kaydedilemedi: ${msj}`
      );
    }
  };

  const bagisAliciSiz = async (ilanId: string) => {
    await durumDegistir(ilanId, 'bagislandi');
    bagisPaneliKapat();
  };

  const ilanSil = (id: string) => {
    Alert.alert('İlanı sil', 'Bu ilanı kalıcı olarak silmek istediğine emin misin?', [
      { text: 'Vazgeç', style: 'cancel' },
      {
        text: 'Sil',
        style: 'destructive',
        onPress: async () => {
          setIslemdekiId(id);
          try {
            await supabase.from('ilanlar').delete().eq('id', id);
            setIlanlar((mevcut) => mevcut.filter((i) => i.id !== id));
          } catch {
            // yoksay
          } finally {
            setIslemdekiId(null);
          }
        },
      },
    ]);
  };

  if (yukleniyor) {
    return (
      <View style={styles.kap}>
        <Baslik baslik="İlanlarım" />
        <Yukleniyor />
      </View>
    );
  }

  return (
    <View style={styles.kap}>
      <Baslik baslik="İlanlarım" />
      {ilanlar.length === 0 ? (
        <View style={styles.merkez}>
          <Text>Henüz ilan vermedin.</Text>
        </View>
      ) : (
        <FlatList
          data={ilanlar}
          keyExtractor={(i) => i.id}
          contentContainerStyle={styles.liste}
          ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
          refreshControl={
            <RefreshControl refreshing={yenileniyor} onRefresh={yenile} tintColor={renkOrman} />
          }
          renderItem={({ item }) => (
            <IlanKarti
              ilan={item}
              islemVar={islemdekiId === item.id}
              panelAcik={bagisPaneliId === item.id}
              onBagisAc={() => bagisPaneliAc(item.id)}
              onBagisKapat={bagisPaneliKapat}
              onYenidenYayinla={() => durumDegistir(item.id, 'aktif')}
              onSil={() => ilanSil(item.id)}
              panelYukleniyor={panelYukleniyor}
              adaylar={adaylar}
              seciliAlici={seciliAlici}
              onAliciSec={setSeciliAlici}
              bagisHata={bagisHata}
              onOnayla={() => bagisOnayla(item.id)}
              onAliciSiz={() => bagisAliciSiz(item.id)}
            />
          )}
        />
      )}
    </View>
  );
}

function KucukButon({
  metin,
  arkaPlan,
  yaziRengi,
  kenarRengi,
  onPress,
}: {
  metin: string;
  arkaPlan: string;
  yaziRengi: string;
  kenarRengi?: string;
  onPress?: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.kucukButon,
        { backgroundColor: arkaPlan, borderColor: kenarRengi ?? 'transparent', borderWidth: kenarRengi ? 1 : 0 },
        !onPress && { opacity: 0.5 },
      ]}
    >
      <Text style={[styles.kucukButonYazi, { color: yaziRengi }]}>{metin}</Text>
    </Pressable>
  );
}

type KartProps = {
  ilan: Ilan;
  islemVar: boolean;
  panelAcik: boolean;
  onBagisAc: () => void;
  onBagisKapat: () => void;
  onYenidenYayinla: () => void;
  onSil: () => void;
  panelYukleniyor: boolean;
  adaylar: Aday[];
  seciliAlici: string | null;
  onAliciSec: (id: string) => void;
  bagisHata: string;
  onOnayla: () => void;
  onAliciSiz: () => void;
};

function IlanKarti(p: KartProps) {
  const { ilan } = p;
  const aktifMi = ilan.durum !== 'bagislandi';
  const baslik = (ilan.baslik as string) ?? '';
  const kategori = ilan.kategori as string | null;
  const fotografUrl = ilan.fotograf_url as string | null;
  const goruntulenme = (ilan.goruntulenme_sayisi as number | null) ?? 0;
  const begeni = (ilan.begeni_sayisi as number | null) ?? 0;

  return (
    <View style={styles.kart}>
      <View style={styles.kartUst}>
        <View style={styles.kartGorsel}>
          {fotografUrl ? (
            <Image source={{ uri: fotografUrl }} style={styles.kartGorselImg} />
          ) : (
            <View style={styles.ng}>
              <Text style={styles.ngYazi}>NG</Text>
            </View>
          )}
        </View>
        <View style={{ flex: 1 }}>
          <View
            style={[
              styles.durumRozet,
              { backgroundColor: aktifMi ? saydam(renkOrman, 0.1) : 'rgba(0,0,0,0.06)' },
            ]}
          >
            <Text
              style={[
                styles.durumRozetYazi,
                { color: aktifMi ? renkOrman : 'rgba(0,0,0,0.54)' },
              ]}
            >
              {aktifMi ? 'AKTİF' : 'BAĞIŞLANDI'}
            </Text>
          </View>
          <Text style={styles.kartBaslik}>{baslik}</Text>
          {kategori ? <Text style={styles.kartKategori}>{kategori}</Text> : null}
          <Text style={styles.kartIstatistik}>
            👁 {goruntulenme}   ♥ {begeni}
          </Text>
          <View style={styles.butonSatir}>
            {aktifMi ? (
              <KucukButon
                metin="Bağışlandı İşaretle"
                arkaPlan={renkOrman}
                yaziRengi="#FFFFFF"
                onPress={
                  p.islemVar ? undefined : p.panelAcik ? p.onBagisKapat : p.onBagisAc
                }
              />
            ) : (
              <KucukButon
                metin="Yeniden Yayınla"
                arkaPlan="#FFFFFF"
                yaziRengi={renkOrman}
                kenarRengi={renkOrman}
                onPress={p.islemVar ? undefined : p.onYenidenYayinla}
              />
            )}
            <KucukButon
              metin="Sil"
              arkaPlan="#FFFFFF"
              yaziRengi={renkHata}
              kenarRengi={renkHata}
              onPress={p.islemVar ? undefined : p.onSil}
            />
          </View>
        </View>
      </View>

      {p.panelAcik && (
        <View style={styles.panel}>
          {p.panelYukleniyor ? (
            <Text style={styles.panelNot}>Yükleniyor…</Text>
          ) : p.adaylar.length === 0 ? (
            <View>
              <Text style={styles.panelNot}>
                Bu ilana kimse mesaj atmadı. Alıcısız işaretlersen kimseye kota işlenmez.
              </Text>
              <View style={styles.panelButonSatir}>
                <KucukButon
                  metin="Alıcısız işaretle"
                  arkaPlan={renkOrman}
                  yaziRengi="#FFFFFF"
                  onPress={p.onAliciSiz}
                />
                <KucukButon
                  metin="Vazgeç"
                  arkaPlan="#FFFFFF"
                  yaziRengi={renkInk}
                  kenarRengi={saydam(renkInk, 0.2)}
                  onPress={p.onBagisKapat}
                />
              </View>
            </View>
          ) : (
            <View>
              <Text style={styles.panelSoru}>Kime bağışladın?</Text>
              {p.adaylar.map((aday) => {
                const secili = p.seciliAlici === aday.gonderenId;
                return (
                  <Pressable
                    key={aday.gonderenId}
                    disabled={aday.kotaDolu}
                    onPress={() => p.onAliciSec(aday.gonderenId)}
                    style={styles.radyoSatir}
                  >
                    <View
                      style={[
                        styles.radyoDis,
                        { borderColor: secili ? renkOrman : saydam(renkInk, 0.4) },
                      ]}
                    >
                      {secili && <View style={styles.radyoIc} />}
                    </View>
                    <Text
                      style={[
                        styles.radyoYazi,
                        { color: aday.kotaDolu ? saydam(renkInk, 0.4) : renkInk },
                      ]}
                    >
                      {(aday.gonderenEposta ?? aday.gonderenId.slice(0, 8)) +
                        (aday.kotaDolu ? ' — kota dolu' : '')}
                    </Text>
                  </Pressable>
                );
              })}
              {!!p.bagisHata && <Text style={styles.panelHata}>{p.bagisHata}</Text>}
              <View style={styles.panelButonSatir}>
                <KucukButon
                  metin="Onayla"
                  arkaPlan={renkOrman}
                  yaziRengi="#FFFFFF"
                  onPress={
                    p.seciliAlici == null || p.islemVar ? undefined : p.onOnayla
                  }
                />
                <KucukButon
                  metin="Vazgeç"
                  arkaPlan="#FFFFFF"
                  yaziRengi={renkInk}
                  kenarRengi={saydam(renkInk, 0.2)}
                  onPress={p.onBagisKapat}
                />
              </View>
            </View>
          )}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  kap: { flex: 1, backgroundColor: renkZemin },
  merkez: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  liste: { padding: 16 },

  kart: {
    backgroundColor: renkKart,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: saydam(renkCizgi, 0.5),
    padding: 12,
  },
  kartUst: { flexDirection: 'row', gap: 12 },
  kartGorsel: { width: 72, height: 72, borderRadius: 8, overflow: 'hidden' },
  kartGorselImg: { width: 72, height: 72 },
  ng: {
    width: 72,
    height: 72,
    backgroundColor: renkGorselZemin,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ngYazi: { color: 'rgba(0,0,0,0.26)' },
  durumRozet: {
    alignSelf: 'flex-start',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 12,
  },
  durumRozetYazi: { fontSize: 9, fontWeight: '700' },
  kartBaslik: { marginTop: 4, fontWeight: '700', color: renkInk },
  kartKategori: { fontSize: 11, color: 'rgba(0,0,0,0.54)' },
  kartIstatistik: { marginTop: 4, fontSize: 11, color: 'rgba(0,0,0,0.54)' },
  butonSatir: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 8 },

  kucukButon: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 16,
  },
  kucukButonYazi: { fontSize: 10, fontWeight: '700' },

  panel: {
    marginTop: 12,
    padding: 12,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: renkCizgi,
    backgroundColor: renkZemin,
  },
  panelNot: { fontSize: 12, color: saydam(renkInk, 0.6) },
  panelSoru: { fontSize: 12, fontWeight: '600', color: renkInk, marginBottom: 4 },
  panelButonSatir: { flexDirection: 'row', gap: 8, marginTop: 8 },
  panelHata: { marginTop: 4, fontSize: 12, color: renkHata },
  radyoSatir: { flexDirection: 'row', alignItems: 'center', paddingVertical: 6, gap: 10 },
  radyoDis: {
    width: 18,
    height: 18,
    borderRadius: 9,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  radyoIc: { width: 8, height: 8, borderRadius: 4, backgroundColor: renkOrman },
  radyoYazi: { fontSize: 12, flexShrink: 1 },
});
