import { ReactNode } from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { renkKart, renkInk, renkCizgi } from '../tema';

type Props = {
  baslik?: string;
  /** Sol tarafta başlık yerine özel içerik (ör. logo satırı). */
  sol?: ReactNode;
  /** Sağ tarafta aksiyonlar. */
  saglar?: ReactNode;
  /** Geri okunu gizle. */
  geriYok?: boolean;
};

/** Flutter'daki beyaz, alt çizgili `AppBar`ın karşılığı. */
export default function Baslik({ baslik, sol, saglar, geriYok }: Props) {
  const insets = useSafeAreaInsets();
  const navigation = useNavigation();
  const geriGoster = !geriYok && navigation.canGoBack();

  return (
    <View style={[styles.kap, { paddingTop: insets.top }]}>
      <View style={styles.satir}>
        <View style={styles.solKisim}>
          {geriGoster && (
            <Pressable
              onPress={() => navigation.goBack()}
              hitSlop={10}
              style={styles.geri}
            >
              <Text style={styles.geriIkon}>‹</Text>
            </Pressable>
          )}
          {sol ?? (
            <Text style={styles.baslik} numberOfLines={1}>
              {baslik}
            </Text>
          )}
        </View>
        {saglar ? <View style={styles.saglar}>{saglar}</View> : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  kap: {
    backgroundColor: renkKart,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: renkCizgi,
  },
  satir: {
    height: 52,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 8,
  },
  solKisim: {
    flexDirection: 'row',
    alignItems: 'center',
    flexShrink: 1,
    gap: 4,
  },
  geri: {
    width: 32,
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  geriIkon: {
    fontSize: 34,
    lineHeight: 36,
    color: renkInk,
  },
  baslik: {
    fontSize: 18,
    fontWeight: '600',
    color: renkInk,
    paddingLeft: 8,
    flexShrink: 1,
  },
  saglar: {
    flexDirection: 'row',
    alignItems: 'center',
  },
});
