import { Platform } from 'react-native';

// "16.4" -> 16, 0 off ios so every gate reads false
export const iosMajor = Platform.OS === 'ios' ? parseInt(String(Platform.Version), 10) || 0 : 0;