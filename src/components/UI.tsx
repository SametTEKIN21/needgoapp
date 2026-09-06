import { forwardRef } from 'react';
import {
  TextInput,
  TextInputProps,
  Pressable,
  Text,
  ActivityIndicator,
  StyleSheet,
  View,
  ViewStyle,
} from 'react-native';
import { renkCizgi, renkInk, renkOrman, saydam } from '../tema';

/** Flutter `TextField` + `OutlineInputBorder` karşılığı. */
export const Girdi = forwardRef<TextInput, TextInputProps & { radius?: number }>(
  ({ style, radius = 6, ...rest }, ref) => (
    <TextInput
      ref={ref}
      placeholderTextColor={saydam(renkInk, 0.4)}
      style={[styles.girdi, { borderRadius: radius }, style]}
      {...rest}
    />
  )
);
Girdi.displayName = 'Girdi';

type DugmeProps = {
  metin: string;
  onPress?: () => void;
  yukleniyor?: boolean;
  pasif?: boolean;
  arkaPlan?: string;
  yaziRengi?: string;
  radius?: number;
  dikeyBosluk?: number;
  style?: ViewStyle;
};

/** Flutter `ElevatedButton` karşılığı (dolu buton). */
export function DugmeDolu({
  metin,
  onPress,
  yukleniyor,
  pasif,
  arkaPlan = renkOrman,
  yaziRengi = '#FFFFFF',
  radius = 6,
  dikeyBosluk = 14,
  style,
}: DugmeProps) {
  const engelli = pasif || yukleniyor;
  return (
    <Pressable
      onPress={engelli ? undefined : onPress}
      style={[
        styles.dugme,
        { backgroundColor: arkaPlan, borderRadius: radius, paddingVertical: dikeyBosluk },
        engelli && styles.pasif,
        style,
      ]}
    >
      {yukleniyor && <ActivityIndicator size="small" color={yaziRengi} style={{ marginRight: 8 }} />}
      <Text style={[styles.dugmeYazi, { color: yaziRengi }]}>{metin}</Text>
    </Pressable>
  );
}

/** Flutter `OutlinedButton` karşılığı (çizgili buton). */
export function DugmeCizgili({
  metin,
  onPress,
  pasif,
  kenarRengi = renkInk,
  yaziRengi = renkInk,
  radius = 999,
  dikeyBosluk = 12,
  style,
}: Omit<DugmeProps, 'arkaPlan'> & { kenarRengi?: string }) {
  return (
    <Pressable
      onPress={pasif ? undefined : onPress}
      style={[
        styles.dugme,
        styles.cizgili,
        { borderColor: kenarRengi, borderRadius: radius, paddingVertical: dikeyBosluk },
        pasif && styles.pasif,
        style,
      ]}
    >
      <Text style={[styles.dugmeYazi, { color: yaziRengi }]}>{metin}</Text>
    </Pressable>
  );
}

/** Ortalanmış yükleniyor göstergesi. */
export function Yukleniyor() {
  return (
    <View style={styles.merkez}>
      <ActivityIndicator color={renkOrman} size="large" />
    </View>
  );
}

const styles = StyleSheet.create({
  girdi: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: renkCizgi,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 15,
    color: '#111111',
  },
  dugme: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 20,
  },
  cizgili: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
  },
  dugmeYazi: {
    fontSize: 15,
    fontWeight: '700',
  },
  pasif: {
    opacity: 0.5,
  },
  merkez: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
