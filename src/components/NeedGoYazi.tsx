import { Text, StyleSheet } from 'react-native';
import { renkNeed, renkGo } from '../tema';

type Props = {
  boyut?: number;
  kalinlik?: '600' | '700' | 'bold';
};

/** İki tonlu "NeedGO" kelime markası — web başlığındaki logonun aynısı. */
export default function NeedGoYazi({ boyut = 20, kalinlik = '700' }: Props) {
  return (
    <Text style={[styles.taban, { fontSize: boyut, fontWeight: kalinlik }]}>
      <Text style={{ color: renkNeed }}>Need</Text>
      <Text style={{ color: renkGo }}>GO</Text>
    </Text>
  );
}

const styles = StyleSheet.create({
  taban: {
    letterSpacing: -0.5,
  },
});
