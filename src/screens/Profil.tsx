import { useEffect, useState } from 'react';
import { View, Text, ScrollView, StyleSheet, Alert } from 'react-native';
import type { User } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import { profilGetir, profilKaydet, hesabiSil } from '../lib/profil';
import { kotaDurumu, tarihMetni, aylikAlmaHakki, KotaDurumu } from '../lib/kota';
import { renkZemin, renkKart, renkInk, renkOrman, renkCizgi, renkHata, saydam } from '../tema';
import { Girdi, DugmeDolu, DugmeCizgili, Yukleniyor } from '../components/UI';
import Baslik from '../components/Baslik';
import type { EkranProps } from '../navigation';

type Alan = {
  anahtar: string;
  etiket: string;
  cokSatir?: boolean;
  klavye?: 'default' | 'phone-pad' | 'email-address';
};

const ALANLAR: Alan[] = [
  { anahtar: 'ad', etiket: 'Ad' },
  { anahtar: 'soyad', etiket: 'Soyad' },
  { anahtar: 'telefon', etiket: 'Telefon', klavye: 'phone-pad' },
  { anahtar: 'iletisim_eposta', etiket: 'E-posta', klavye: 'email-address' },
  { anahtar: 'adres', etiket: 'Adres', cokSatir: true },
];

type Form = Record<string, string>;

export default function Profil({ navigation }: EkranProps<'Profil'>) {
  const [kullanici, setKullanici] = useState<User | null>(null);
  const [kontrolBitti, setKontrolBitti] = useState(false);
  const [duzenleme, setDuzenleme] = useState(true);
  const [form, setForm] = useState<Form>(() =>
    Object.fromEntries(ALANLAR.map((a) => [a.anahtar, '']))
  );
  const [kayitli, setKayitli] = useState<Form | null>(null);
  const [kaydediliyor, setKaydediliyor] = useState(false);
  const [siliniyor, setSiliniyor] = useState(false);
  const [hata, setHata] = useState('');
  const [kota, setKota] = useState<KotaDurumu | null>(null);

  useEffect(() => {
    (async () => {
      const { data } = await supabase.auth.getUser();
      const user = data.user;
      setKullanici(user);

      const p = await profilGetir();
      const yeni: Form = {};
      for (const a of ALANLAR) {
        let deger = (p as unknown as Record<string, string>)[a.anahtar] ?? '';
        if (a.anahtar === 'iletisim_eposta' && deger === '') deger = user?.email ?? '';
        yeni[a.anahtar] = deger;
      }
      setForm(yeni);

      const tam = ALANLAR.every((a) => (yeni[a.anahtar] ?? '').trim() !== '');
      setDuzenleme(!tam);
      if (tam) setKayitli(yeni);
      setKontrolBitti(true);

      if (user) {
        try {
          setKota(await kotaDurumu(user.id));
        } catch {
          // yoksay
        }
      }
    })();
  }, []);

  const alanDegistir = (anahtar: string, deger: string) =>
    setForm((f) => ({ ...f, [anahtar]: deger }));

  const formTamMi = () => ALANLAR.every((a) => (form[a.anahtar] ?? '').trim() !== '');

  const kaydet = async () => {
    setHata('');
    if (!formTamMi()) {
      setHata('Tüm alanları doldurman gerekiyor.');
      return;
    }
    const temiz: Form = Object.fromEntries(
      ALANLAR.map((a) => [a.anahtar, (form[a.anahtar] ?? '').trim()])
    );

    setKaydediliyor(true);
    try {
      await profilKaydet({
        ad: temiz.ad,
        soyad: temiz.soyad,
        telefon: temiz.telefon,
        adres: temiz.adres,
        iletisim_eposta: temiz.iletisim_eposta,
      });
      navigation.goBack();
    } catch (e) {
      setKaydediliyor(false);
      setHata(`Kaydedilemedi: ${e}`);
    }
  };

  const hesabiSilOnay = () => {
    Alert.alert(
      'Hesabımı sil',
      'Hesabın ve tüm verilerin (ilanların, mesajların, fotoğrafların) kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      [
        { text: 'Vazgeç', style: 'cancel' },
        {
          text: 'Hesabımı sil',
          style: 'destructive',
          onPress: async () => {
            setSiliniyor(true);
            try {
              await hesabiSil();
              navigation.reset({ index: 0, routes: [{ name: 'AnaSayfa' }] });
            } catch (e) {
              setSiliniyor(false);
              Alert.alert('Silinemedi', `Bir hata oluştu: ${e}`);
            }
          },
        },
      ]
    );
  };

  if (!kontrolBitti) {
    return (
      <View style={styles.kap}>
        <Baslik baslik="Profil" />
        <Yukleniyor />
      </View>
    );
  }

  if (!kullanici) {
    return (
      <View style={styles.kap}>
        <Baslik baslik="Profil" />
        <View style={styles.merkez}>
          <Text>Bu sayfayı görmek için giriş yapmalısın.</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.kap}>
      <Baslik baslik="Profil" />
      <ScrollView contentContainerStyle={styles.icerik} keyboardShouldPersistTaps="handled">
        <Text style={styles.aciklama}>
          Bu bilgiler seninle iletişim kurmak isteyenler için kullanılır ve zorunludur.
        </Text>

        {kota && <KotaKarti kota={kota} />}

        {!duzenleme && kayitli ? (
          <Ozet
            k={kayitli}
            onDuzenle={() => {
              setForm(kayitli);
              setHata('');
              setDuzenleme(true);
            }}
          />
        ) : (
          <View style={styles.karti}>
            {ALANLAR.map((a) => (
              <View key={a.anahtar} style={{ marginBottom: 14 }}>
                <Text style={styles.etiket}>{a.etiket} *</Text>
                <Girdi
                  value={form[a.anahtar]}
                  onChangeText={(v) => alanDegistir(a.anahtar, v)}
                  keyboardType={a.klavye ?? 'default'}
                  autoCapitalize={a.klavye === 'email-address' ? 'none' : 'sentences'}
                  multiline={a.cokSatir}
                  numberOfLines={a.cokSatir ? 3 : 1}
                  radius={8}
                  style={a.cokSatir ? styles.cokSatir : undefined}
                />
                {a.anahtar === 'iletisim_eposta' && (
                  <Text style={styles.ipucu}>Giriş e-postan: {kullanici.email ?? '-'}</Text>
                )}
              </View>
            ))}

            {!!hata && <Text style={styles.hata}>{hata}</Text>}

            <View style={styles.butonSatir}>
              <DugmeDolu
                metin={kaydediliyor ? 'Kaydediliyor…' : 'Kaydet'}
                onPress={kaydet}
                yukleniyor={kaydediliyor}
                radius={999}
                dikeyBosluk={12}
              />
              {kayitli && (
                <DugmeCizgili
                  metin="Vazgeç"
                  kenarRengi={saydam(renkInk, 0.2)}
                  onPress={() => {
                    setForm(kayitli);
                    setHata('');
                    setDuzenleme(false);
                  }}
                />
              )}
            </View>
          </View>
        )}

        <View style={styles.tehlikeKart}>
          <Text style={styles.tehlikeBaslik}>Hesabı sil</Text>
          <Text style={styles.tehlikeMetin}>
            Hesabın ve tüm verilerin (ilanların, mesajların, fotoğrafların) kalıcı
            olarak silinir. Bu işlem geri alınamaz.
          </Text>
          <DugmeCizgili
            metin={siliniyor ? 'Siliniyor…' : 'Hesabımı sil'}
            kenarRengi={renkHata}
            yaziRengi={renkHata}
            onPress={hesabiSilOnay}
            pasif={siliniyor}
            style={{ alignSelf: 'flex-start', marginTop: 12 }}
          />
        </View>
      </ScrollView>
    </View>
  );
}

function KotaKarti({ kota }: { kota: KotaDurumu }) {
  return (
    <View style={styles.karti}>
      <Text style={styles.kotaBaslik}>Eşya alma hakkın</Text>
      <Text style={styles.kotaMetin}>
        Son 30 günde {kota.alinan} eşya aldın · kalan hakkın {kota.kalan}/{aylikAlmaHakki}
      </Text>
      {kota.kalan === 0 && kota.yenilenmeTarihi && (
        <Text style={styles.kotaAlt}>
          Hakların {tarihMetni(kota.yenilenmeTarihi)} tarihinden itibaren yenilenmeye başlar.
        </Text>
      )}
      <Text style={styles.kotaAlt}>
        Fırsatçılığı önlemek için her hesap 30 günde en fazla {aylikAlmaHakki} eşya alabilir.
      </Text>
    </View>
  );
}

function Ozet({ k, onDuzenle }: { k: Form; onDuzenle: () => void }) {
  const ilkHarf = (s?: string) => (s ?? '').trim().charAt(0);
  const bas = (ilkHarf(k.ad) + ilkHarf(k.soyad)).toUpperCase();

  const satir = (etiket: string, deger: string) => (
    <View style={styles.ozetSatir} key={etiket}>
      <Text style={styles.ozetEtiket}>{etiket}</Text>
      <Text style={styles.ozetDeger}>{deger}</Text>
    </View>
  );

  return (
    <View style={styles.ozetKart}>
      <View style={styles.ozetUst}>
        <View style={styles.ozetAvatar}>
          <Text style={styles.ozetAvatarYazi}>{bas}</Text>
        </View>
        <View style={{ flex: 1 }}>
          <Text style={styles.ozetAd}>
            {k.ad} {k.soyad}
          </Text>
          <Text style={styles.ozetUye}>NeedGO üyesi</Text>
        </View>
      </View>
      <View style={styles.ozetGovde}>
        {satir('Telefon', k.telefon ?? '')}
        {satir('E-posta', k.iletisim_eposta ?? '')}
        {satir('Adres', k.adres ?? '')}
      </View>
      <View style={{ padding: 18, paddingTop: 0 }}>
        <DugmeCizgili
          metin="Düzenle"
          kenarRengi={renkOrman}
          yaziRengi={renkOrman}
          onPress={onDuzenle}
          style={{ alignSelf: 'flex-start' }}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  kap: { flex: 1, backgroundColor: renkZemin },
  merkez: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  icerik: { padding: 20 },
  aciklama: { fontSize: 13, color: saydam(renkInk, 0.5), marginBottom: 20 },

  karti: {
    backgroundColor: renkKart,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: renkCizgi,
    padding: 16,
    marginBottom: 20,
  },
  etiket: { fontSize: 13, fontWeight: '500', color: renkInk, marginBottom: 6 },
  cokSatir: { minHeight: 80, textAlignVertical: 'top' },
  ipucu: { marginTop: 4, fontSize: 11, color: saydam(renkInk, 0.45) },
  hata: { fontSize: 12, color: renkHata, marginBottom: 8 },
  butonSatir: { flexDirection: 'row', gap: 8, alignItems: 'center' },

  kotaBaslik: { fontSize: 15, fontWeight: '600', color: renkInk },
  kotaMetin: { marginTop: 4, fontSize: 13, color: saydam(renkInk, 0.7) },
  kotaAlt: { marginTop: 4, fontSize: 11, color: saydam(renkInk, 0.45) },

  tehlikeKart: {
    backgroundColor: renkKart,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: saydam(renkHata, 0.4),
    padding: 16,
    marginTop: 4,
  },
  tehlikeBaslik: { fontSize: 15, fontWeight: '600', color: renkHata, marginBottom: 6 },
  tehlikeMetin: { fontSize: 12, color: saydam(renkInk, 0.6), lineHeight: 17 },

  ozetKart: {
    backgroundColor: renkKart,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: renkCizgi,
    overflow: 'hidden',
    marginBottom: 20,
  },
  ozetUst: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    padding: 18,
    backgroundColor: saydam(renkOrman, 0.06),
    borderBottomWidth: 1,
    borderBottomColor: renkCizgi,
  },
  ozetAvatar: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: renkOrman,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ozetAvatarYazi: { color: '#FFFFFF', fontSize: 18, fontWeight: '600' },
  ozetAd: { fontSize: 17, fontWeight: '600', color: renkInk },
  ozetUye: { fontSize: 11, color: saydam(renkInk, 0.5) },
  ozetGovde: { padding: 18, paddingBottom: 4 },
  ozetSatir: { marginBottom: 16 },
  ozetEtiket: { fontSize: 11, color: saydam(renkInk, 0.45) },
  ozetDeger: { marginTop: 2, fontSize: 14, color: renkInk },
});
