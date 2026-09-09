import { useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  Pressable,
  Image,
  Alert,
  StyleSheet,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { decode } from 'base64-arraybuffer';
import { supabase } from '../lib/supabase';
import { MODERASYON_API } from '../lib/sabitler';
import { renkZemin, renkInk, renkOcre, renkCizgi, renkHata } from '../tema';
import { Girdi, DugmeDolu } from '../components/UI';
import Baslik from '../components/Baslik';
import type { EkranProps } from '../navigation';

const MAKS_FOTO = 5;

type SeciliFoto = { uri: string; base64: string; uzanti: string };

export default function IlanVer({ navigation }: EkranProps<'IlanVer'>) {
  const [baslik, setBaslik] = useState('');
  const [aciklama, setAciklama] = useState('');
  const [kategori, setKategori] = useState('');
  const [konum, setKonum] = useState('');
  const [fotolar, setFotolar] = useState<SeciliFoto[]>([]);
  const [yukleniyor, setYukleniyor] = useState(false);

  const fotografSec = async () => {
    if (fotolar.length >= MAKS_FOTO) return;

    const izin = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!izin.granted) {
      Alert.alert('İzin gerekli', 'Fotoğraf seçmek için galeri erişimine izin vermelisin.');
      return;
    }

    const kalanYer = MAKS_FOTO - fotolar.length;
    const sonuc = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsMultipleSelection: true,
      selectionLimit: kalanYer,
      base64: true,
      quality: 0.8,
    });

    if (sonuc.canceled) return;

    const yeniler: SeciliFoto[] = sonuc.assets
      .filter((a) => a.base64)
      .slice(0, kalanYer)
      .map((a) => {
        const ad = a.fileName ?? a.uri;
        const uzanti = ad.includes('.') ? ad.split('.').pop()!.toLowerCase() : 'jpg';
        return { uri: a.uri, base64: a.base64!, uzanti };
      });

    setFotolar((mevcut) => [...mevcut, ...yeniler].slice(0, MAKS_FOTO));
  };

  const fotografSil = (index: number) => {
    setFotolar((mevcut) => mevcut.filter((_, i) => i !== index));
  };

  const gonder = async () => {
    const bas = baslik.trim();
    if (bas === '') return;

    const { data: kul } = await supabase.auth.getUser();
    const kullanici = kul.user;
    if (!kullanici) return;

    setYukleniyor(true);
    try {
      const yuklenenUrller: string[] = [];

      for (const foto of fotolar) {
        const contentType = foto.uzanti === 'png' ? 'image/png' : 'image/jpeg';
        const dosyaAdi = `${kullanici.id}/${Date.now()}-${yuklenenUrller.length}.${foto.uzanti}`;

        const { error: yuklemeHata } = await supabase.storage
          .from('ilan-fotograflari')
          .upload(dosyaAdi, decode(foto.base64), { contentType });
        if (yuklemeHata) throw yuklemeHata;

        const { data: pub } = supabase.storage.from('ilan-fotograflari').getPublicUrl(dosyaAdi);
        yuklenenUrller.push(pub.publicUrl);
      }

      const { data: yeni, error } = await supabase
        .from('ilanlar')
        .insert({
          baslik: bas,
          aciklama: aciklama.trim(),
          kategori: kategori.trim(),
          konum: konum.trim(),
          user_id: kullanici.id,
          kullanici_email: kullanici.email,
          fotograf_url: yuklenenUrller.length > 0 ? yuklenenUrller[0] : null,
          fotograflar: yuklenenUrller,
        })
        .select('id')
        .single();
      if (error) throw error;

      // Fotoğrafları otomatik moderasyondan geçir (web ile ortak endpoint).
      // Başarısız olursa ilan 'beklemede' kalır → admin onayına düşer.
      let durum: 'onaylandi' | 'beklemede' | 'reddedildi' = 'beklemede';
      let not: string | null = null;
      try {
        const { data: oturum } = await supabase.auth.getSession();
        const yanit = await fetch(MODERASYON_API, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${oturum.session?.access_token ?? ''}`,
          },
          body: JSON.stringify({ ilanId: yeni.id }),
        });
        if (yanit.ok) {
          const sonuc = await yanit.json();
          durum = sonuc.durum ?? 'beklemede';
          not = sonuc.not ?? null;
        }
      } catch {
        // moderasyon isteği başarısız — ilan 'beklemede' kalır
      }

      setYukleniyor(false);
      Alert.alert(
        durum === 'onaylandi'
          ? 'İlanın yayında!'
          : durum === 'reddedildi'
            ? 'İlan yayınlanamadı'
            : 'İlanın incelemeye alındı',
        durum === 'onaylandi'
          ? 'Fotoğraflar otomatik kontrolden geçti, ilanın yayınlandı.'
          : durum === 'reddedildi'
            ? not ?? 'Fotoğraflar içerik kurallarına uymuyor.'
            : (not ? not + ' ' : '') +
              'Ekibimiz kısa sürede kontrol edip yayınlayacak. Durumu "İlanlarım"dan takip edebilirsin.',
        [{ text: 'Tamam', onPress: () => navigation.goBack() }]
      );
      return;
    } catch (e) {
      Alert.alert('Hata', `Bir hata oluştu: ${e}`);
    } finally {
      setYukleniyor(false);
    }
  };

  return (
    <View style={styles.kap}>
      <Baslik baslik="Yeni İlan" />
      <ScrollView contentContainerStyle={styles.icerik} keyboardShouldPersistTaps="handled">
        {fotolar.length > 0 && (
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.fotoSerit}
          >
            {fotolar.map((foto, i) => (
              <View key={i} style={styles.fotoKutu}>
                <Image source={{ uri: foto.uri }} style={styles.foto} />
                <Pressable style={styles.fotoSil} onPress={() => fotografSil(i)}>
                  <Text style={styles.fotoSilYazi}>×</Text>
                </Pressable>
              </View>
            ))}
          </ScrollView>
        )}

        {fotolar.length < MAKS_FOTO && (
          <Pressable style={styles.fotoEkle} onPress={fotografSec}>
            <Text style={styles.fotoEkleYazi}>
              ＋ Fotoğraf Ekle ({fotolar.length}/{MAKS_FOTO})
            </Text>
          </Pressable>
        )}

        <View style={{ height: 12 }} />
        <Girdi value={baslik} onChangeText={setBaslik} placeholder="Eşyanın adı (örn. Kitaplık)" />
        <View style={{ height: 12 }} />
        <Girdi
          value={aciklama}
          onChangeText={setAciklama}
          placeholder="Açıklama"
          multiline
          numberOfLines={3}
          style={styles.cokSatir}
        />
        <View style={{ height: 12 }} />
        <Girdi value={kategori} onChangeText={setKategori} placeholder="Kategori (örn. Mobilya)" />
        <View style={{ height: 12 }} />
        <Girdi
          value={konum}
          onChangeText={setKonum}
          placeholder="Konum (örn. Kadıköy, İstanbul)"
        />
        <View style={{ height: 20 }} />
        <DugmeDolu
          metin={yukleniyor ? 'Ekleniyor…' : 'İlan Ver'}
          onPress={gonder}
          yukleniyor={yukleniyor}
          arkaPlan={renkOcre}
        />
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  kap: { flex: 1, backgroundColor: renkZemin },
  icerik: { padding: 16 },
  fotoSerit: { gap: 8, paddingTop: 6, paddingRight: 6 },
  fotoKutu: { width: 64, height: 64 },
  foto: { width: 64, height: 64, borderRadius: 6 },
  fotoSil: {
    position: 'absolute',
    top: -6,
    right: -6,
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: renkHata,
    alignItems: 'center',
    justifyContent: 'center',
  },
  fotoSilYazi: { color: '#FFFFFF', fontSize: 13, lineHeight: 15 },
  fotoEkle: {
    marginTop: 12,
    borderWidth: 1,
    borderColor: renkCizgi,
    borderRadius: 6,
    backgroundColor: '#FFFFFF',
    paddingVertical: 14,
    alignItems: 'center',
  },
  fotoEkleYazi: { color: renkInk, fontWeight: '600' },
  cokSatir: { minHeight: 84, textAlignVertical: 'top' },
});
