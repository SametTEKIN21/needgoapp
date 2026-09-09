import { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  Image,
  Pressable,
  Modal,
  StyleSheet,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { supabase } from '../lib/supabase';
import { useAuth } from '../lib/auth';
import { profilTamMi } from '../lib/profil';
import { okunmamisMesajSayisi, mesajlariGorulduIsaretle } from '../lib/mesajDeposu';
import {
  renkZemin,
  renkKart,
  renkInk,
  renkOrman,
  renkOcre,
  renkCizgi,
  renkHata,
} from '../tema';
import Baslik from '../components/Baslik';
import NeedGoYazi from '../components/NeedGoYazi';
import IlanListesi from './IlanListesi';
import type { EkranProps } from '../navigation';

const NG_LOGO = require('../../assets/images/needgo-n.png');

export default function AnaSayfa({ navigation }: EkranProps<'AnaSayfa'>) {
  const { kullanici } = useAuth();
  const [okunmamis, setOkunmamis] = useState(0);
  const [menuAcik, setMenuAcik] = useState(false);

  const okunmamisGetir = useCallback(async () => {
    const { data } = await supabase.auth.getUser();
    setOkunmamis(await okunmamisMesajSayisi(data.user?.id));
  }, []);

  useEffect(() => {
    okunmamisGetir();
    const t = setInterval(okunmamisGetir, 30000);
    return () => clearInterval(t);
  }, [okunmamisGetir, kullanici]);

  useFocusEffect(
    useCallback(() => {
      okunmamisGetir();
    }, [okunmamisGetir])
  );

  const girisEkraniniAc = () => navigation.navigate('Giris');

  const mesajlariAc = async () => {
    setOkunmamis(0);
    await mesajlariGorulduIsaretle();
    navigation.navigate('Mesajlar');
  };

  const ilanVerTiklandi = async () => {
    const { data } = await supabase.auth.getUser();
    if (!data.user) {
      girisEkraniniAc();
      return;
    }
    if (!(await profilTamMi())) {
      navigation.navigate('Profil');
      return;
    }
    navigation.navigate('IlanVer');
  };

  const cikisYap = async () => {
    setMenuAcik(false);
    await supabase.auth.signOut();
  };

  const menuGit = (ekran: 'Profil' | 'Ilanlarim' | 'Mesajlar') => {
    setMenuAcik(false);
    if (ekran === 'Mesajlar') {
      mesajlariAc();
    } else {
      navigation.navigate(ekran);
    }
  };

  const harf = (kullanici?.email ?? '?').trim();
  const avatarHarf = harf.length === 0 ? '?' : harf[0].toUpperCase();

  const saglar = kullanici ? (
    <>
      <Pressable onPress={mesajlariAc} hitSlop={8} style={styles.zilKap}>
        <Text style={styles.zil}>🔔</Text>
        {okunmamis > 0 && (
          <View style={styles.rozet}>
            <Text style={styles.rozetYazi}>{okunmamis > 9 ? '9+' : okunmamis}</Text>
          </View>
        )}
      </Pressable>
      <Pressable onPress={() => setMenuAcik(true)} hitSlop={8} style={styles.avatar}>
        <Text style={styles.avatarYazi}>{avatarHarf}</Text>
      </Pressable>
      <View style={{ width: 4 }} />
    </>
  ) : (
    <Pressable onPress={girisEkraniniAc} hitSlop={8} style={{ paddingHorizontal: 8 }}>
      <Text style={{ color: renkOrman, fontWeight: '600' }}>Giriş Yap</Text>
    </Pressable>
  );

  return (
    <View style={styles.kap}>
      <Baslik
        geriYok
        sol={
          <View style={styles.logoSatir}>
            <Image source={NG_LOGO} style={styles.logo} />
            <NeedGoYazi boyut={22} />
          </View>
        }
        saglar={saglar}
      />

      <IlanListesi onIlanPress={(ilanId) => navigation.navigate('IlanDetay', { ilanId })} />

      <Pressable style={styles.fab} onPress={ilanVerTiklandi}>
        <Text style={styles.fabYazi}>＋ İlan Ver</Text>
      </Pressable>

      <Modal
        visible={menuAcik}
        transparent
        animationType="fade"
        onRequestClose={() => setMenuAcik(false)}
      >
        <Pressable style={styles.menuOrtu} onPress={() => setMenuAcik(false)}>
          <View style={styles.menu}>
            <MenuOge metin="Profil" onPress={() => menuGit('Profil')} />
            <MenuOge metin="İlanlarım" onPress={() => menuGit('Ilanlarim')} />
            <MenuOge metin="Mesajlar" onPress={() => menuGit('Mesajlar')} />
            <View style={styles.menuCizgi} />
            <MenuOge metin="Çıkış Yap" renk={renkHata} onPress={cikisYap} />
          </View>
        </Pressable>
      </Modal>
    </View>
  );
}

function MenuOge({
  metin,
  onPress,
  renk = renkInk,
}: {
  metin: string;
  onPress: () => void;
  renk?: string;
}) {
  return (
    <Pressable style={styles.menuOge} onPress={onPress}>
      <Text style={[styles.menuOgeYazi, { color: renk }]}>{metin}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  kap: { flex: 1, backgroundColor: renkZemin },
  logoSatir: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingLeft: 8 },
  logo: { width: 34, height: 34 },

  zilKap: { padding: 6 },
  zil: { fontSize: 18 },
  rozet: {
    position: 'absolute',
    top: 2,
    right: 0,
    minWidth: 16,
    height: 16,
    borderRadius: 999,
    backgroundColor: renkHata,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 3,
  },
  rozetYazi: { color: '#FFFFFF', fontSize: 10, fontWeight: '600' },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: renkOrman,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 4,
  },
  avatarYazi: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },

  fab: {
    position: 'absolute',
    right: 16,
    bottom: 24,
    backgroundColor: renkOcre,
    borderRadius: 999,
    paddingHorizontal: 20,
    paddingVertical: 14,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOpacity: 0.2,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 3 },
    elevation: 4,
  },
  fabYazi: { color: '#FFFFFF', fontWeight: '700', fontSize: 15 },

  menuOrtu: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.15)',
    alignItems: 'flex-end',
    paddingTop: 92,
    paddingRight: 12,
  },
  menu: {
    backgroundColor: renkKart,
    borderRadius: 10,
    paddingVertical: 6,
    minWidth: 180,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: renkCizgi,
    shadowColor: '#000',
    shadowOpacity: 0.15,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 8,
  },
  menuOge: { paddingHorizontal: 16, paddingVertical: 12 },
  menuOgeYazi: { fontSize: 14 },
  menuCizgi: { height: StyleSheet.hairlineWidth, backgroundColor: renkCizgi, marginVertical: 4 },
});
