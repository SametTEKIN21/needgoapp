import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { NavigationContainer, DefaultTheme } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

import { RootStackParamList } from './src/navigation';
import { renkZemin } from './src/tema';

import AnaSayfa from './src/screens/AnaSayfa';
import GirisEkrani from './src/screens/GirisEkrani';
import IlanDetay from './src/screens/IlanDetay';
import IlanVer from './src/screens/IlanVer';
import Ilanlarim from './src/screens/Ilanlarim';
import Mesajlar from './src/screens/Mesajlar';
import MesajDetay from './src/screens/MesajDetay';
import Profil from './src/screens/Profil';

const Stack = createNativeStackNavigator<RootStackParamList>();

const tema = {
  ...DefaultTheme,
  colors: { ...DefaultTheme.colors, background: renkZemin },
};

export default function App() {
  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      <NavigationContainer theme={tema}>
        <Stack.Navigator screenOptions={{ headerShown: false, contentStyle: { backgroundColor: renkZemin } }}>
          <Stack.Screen name="AnaSayfa" component={AnaSayfa} />
          <Stack.Screen name="Giris" component={GirisEkrani} />
          <Stack.Screen name="IlanDetay" component={IlanDetay} />
          <Stack.Screen name="IlanVer" component={IlanVer} />
          <Stack.Screen name="Ilanlarim" component={Ilanlarim} />
          <Stack.Screen name="Mesajlar" component={Mesajlar} />
          <Stack.Screen name="MesajDetay" component={MesajDetay} />
          <Stack.Screen name="Profil" component={Profil} />
        </Stack.Navigator>
      </NavigationContainer>
    </SafeAreaProvider>
  );
}
