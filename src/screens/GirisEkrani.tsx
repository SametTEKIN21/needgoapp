import { useState } from 'react';
import { View, Text, ScrollView, Pressable, StyleSheet, Linking } from 'react-native';
import { supabase } from '../lib/supabase';
import { GIZLILIK_URL } from '../lib/sabitler';
import { renkZemin, renkInk, renkOrman, renkOcre, renkHata, renkCizgi } from '../tema';
import { Girdi, DugmeDolu } from '../components/UI';
import Baslik from '../components/Baslik';
import NeedGoYazi from '../components/NeedGoYazi';
import type { EkranProps } from '../navigation';

type Mod = 'giris' | 'kayit' | 'sifremi-unuttum';

function hataMesajiCevir(mesaj: string): string {
  if (mesaj.includes('Invalid login credentials')) return 'E-posta veya şifre hatalı.';
  if (mesaj.includes('User already registered'))
    return 'Bu e-posta adresi zaten kayıtlı. Giriş yapmayı deneyin.';
  if (mesaj.includes('Password should be at least')) return 'Şifre en az 6 karakter olmalı.';
  if (mesaj.includes('Unable to validate email address')) return 'Geçerli bir e-posta adresi girin.';
  if (mesaj.includes('Email not confirmed'))
    return 'E-posta adresini onaylamadan giriş yapamazsın. Gelen kutunu kontrol et.';
  return 'Bir hata oluştu, lütfen tekrar dene.';
}

export default function GirisEkrani({ navigation }: EkranProps<'Giris'>) {
  const [mod, setMod] = useState<Mod>('giris');
  const [email, setEmail] = useState('');
  const [sifre, setSifre] = useState('');
  const [yukleniyor, setYukleniyor] = useState(false);
  const [hata, setHata] = useState('');
  const [mesaj, setMesaj] = useState('');
  const [kvkkOnay, setKvkkOnay] = useState(false);

  const modDegistir = (m: Mod) => {
    setMod(m);
    setHata('');
    setMesaj('');
    setKvkkOnay(false);
  };

  const gonder = async () => {
    setHata('');
    setMesaj('');

    if (mod === 'kayit' && !kvkkOnay) {
      setHata('Devam etmek için Gizlilik Bildirimi’ni onaylaman gerekiyor.');
      return;
    }

    setYukleniyor(true);

    const eposta = email.trim();
    try {
      if (mod === 'kayit') {
        const { error } = await supabase.auth.signUp({ email: eposta, password: sifre });
        if (error) throw error;
        setMesaj('Kayıt başarılı! E-postanı kontrol edip hesabını onayla.');
      } else if (mod === 'sifremi-unuttum') {
        const { error } = await supabase.auth.resetPasswordForEmail(eposta);
        if (error) throw error;
        setMesaj('Şifre sıfırlama linki e-postana gönderildi.');
      } else {
        const { error } = await supabase.auth.signInWithPassword({
          email: eposta,
          password: sifre,
        });
        if (error) throw error;
        navigation.goBack();
      }
    } catch (e) {
      setHata(hataMesajiCevir(String(e)));
    } finally {
      setYukleniyor(false);
    }
  };

  const baslik =
    mod === 'giris' ? 'Giriş Yap' : mod === 'kayit' ? 'Kayıt Ol' : 'Şifremi Unuttum';
  const butonMetni = yukleniyor
    ? 'Bekleyin…'
    : mod === 'giris'
      ? 'Giriş Yap'
      : mod === 'kayit'
        ? 'Kayıt Ol'
        : 'Sıfırlama Linki Gönder';

  return (
    <View style={styles.kap}>
      <Baslik baslik={baslik} />
      <ScrollView contentContainerStyle={styles.icerik} keyboardShouldPersistTaps="handled">
        <NeedGoYazi boyut={26} />
        <View style={{ height: 24 }} />

        <Girdi
          value={email}
          onChangeText={setEmail}
          placeholder="E-posta adresi"
          keyboardType="email-address"
          autoCapitalize="none"
          autoCorrect={false}
        />

        {mod !== 'sifremi-unuttum' && (
          <>
            <View style={{ height: 12 }} />
            <Girdi
              value={sifre}
              onChangeText={setSifre}
              placeholder="Şifre"
              secureTextEntry
              autoCapitalize="none"
            />
          </>
        )}

        {mod === 'giris' && (
          <Pressable
            onPress={() => modDegistir('sifremi-unuttum')}
            style={styles.sifremiUnuttum}
          >
            <Text style={styles.sifremiUnuttumYazi}>Şifremi unuttum</Text>
          </Pressable>
        )}

        {mod === 'kayit' && (
          <Pressable style={styles.kvkkSatir} onPress={() => setKvkkOnay((v) => !v)}>
            <View style={[styles.kutu, kvkkOnay && styles.kutuDolu]}>
              {kvkkOnay && <Text style={styles.kutuTik}>✓</Text>}
            </View>
            <Text style={styles.kvkkYazi}>
              <Text style={styles.kvkkLink} onPress={() => Linking.openURL(GIZLILIK_URL)}>
                Gizlilik Bildirimi
              </Text>
              ’ni okudum, kişisel verilerimin işlenmesini kabul ediyorum.
            </Text>
          </Pressable>
        )}

        {!!hata && <Text style={styles.hata}>{hata}</Text>}
        {!!mesaj && <Text style={styles.mesaj}>{mesaj}</Text>}

        <View style={{ height: 16 }} />
        <DugmeDolu
          metin={butonMetni}
          onPress={gonder}
          pasif={yukleniyor || (mod === 'kayit' && !kvkkOnay)}
          arkaPlan={renkOcre}
        />

        <View style={{ height: 16 }} />
        {mod === 'giris' && (
          <Pressable style={styles.altLink} onPress={() => modDegistir('kayit')}>
            <Text style={styles.altLinkYazi}>Hesabın yok mu? Kayıt Ol</Text>
          </Pressable>
        )}
        {mod === 'kayit' && (
          <Pressable style={styles.altLink} onPress={() => modDegistir('giris')}>
            <Text style={styles.altLinkYazi}>Zaten hesabın var mı? Giriş Yap</Text>
          </Pressable>
        )}
        {mod === 'sifremi-unuttum' && (
          <Pressable style={styles.altLink} onPress={() => modDegistir('giris')}>
            <Text style={styles.altLinkYazi}>Giriş ekranına dön</Text>
          </Pressable>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  kap: { flex: 1, backgroundColor: renkZemin },
  icerik: { padding: 24 },
  sifremiUnuttum: { alignSelf: 'flex-end', paddingVertical: 8 },
  sifremiUnuttumYazi: { color: renkInk, fontSize: 12 },
  kvkkSatir: { flexDirection: 'row', alignItems: 'flex-start', gap: 10, marginTop: 14 },
  kutu: {
    width: 22,
    height: 22,
    borderRadius: 5,
    borderWidth: 1.5,
    borderColor: renkCizgi,
    backgroundColor: '#FFFFFF',
    alignItems: 'center',
    justifyContent: 'center',
  },
  kutuDolu: { backgroundColor: renkOcre, borderColor: renkOcre },
  kutuTik: { color: '#FFFFFF', fontSize: 13, fontWeight: '900', lineHeight: 16 },
  kvkkYazi: { flex: 1, color: renkInk, fontSize: 12, lineHeight: 17 },
  kvkkLink: { color: renkOrman, textDecorationLine: 'underline' },
  hata: { color: renkHata, fontSize: 12, marginTop: 8 },
  mesaj: { color: renkOrman, fontSize: 12, marginTop: 8 },
  altLink: { alignSelf: 'center', paddingVertical: 8 },
  altLinkYazi: { color: renkOrman, fontSize: 14 },
});
