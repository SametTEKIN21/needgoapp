import type { NativeStackScreenProps } from '@react-navigation/native-stack';

export type RootStackParamList = {
  AnaSayfa: undefined;
  Giris: undefined;
  IlanDetay: { ilanId: string };
  IlanVer: undefined;
  Ilanlarim: undefined;
  Mesajlar: undefined;
  MesajDetay: { konusmaId: string; ilanId: string; ilanBasligi: string };
  Profil: undefined;
};

export type EkranProps<T extends keyof RootStackParamList> = NativeStackScreenProps<
  RootStackParamList,
  T
>;
