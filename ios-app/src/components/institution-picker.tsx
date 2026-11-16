import { SymbolView } from 'expo-symbols';
import { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, FlatList, Modal, Pressable, Text, TextInput, View } from 'react-native';

import { Radius, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { fetchInstitutes } from '@/neptun/institutions';
import type { Institute } from '@/neptun/types';

type Props = {
  visible: boolean;
  onClose: () => void;
  onSelect: (institute: Institute) => void;
};

// Native page sheet with a live-filtered list. The list is fetched each time it opens, so
// a failed first load retries simply by reopening.
export function InstitutionPicker({ visible, onClose, onSelect }: Props) {
  const c = useTheme();
  const { t } = useI18n();
  const [query, setQuery] = useState('');
  const [institutes, setInstitutes] = useState<Institute[] | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    if (!visible) return;
    let active = true;
    setQuery('');
    setFailed(false);
    setInstitutes(null);
    fetchInstitutes()
      .then((list) => {
        if (!active) return;
        if (list.length === 0) setFailed(true);
        setInstitutes(list);
      })
      .catch(() => {
        if (active) setFailed(true);
      });
    return () => {
      active = false;
    };
  }, [visible]);

  const filtered = useMemo(() => {
    const list = institutes ?? [];
    const q = query.trim().toLowerCase();
    return q ? list.filter((i) => i.name.toLowerCase().includes(q)) : list;
  }, [institutes, query]);

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet" onRequestClose={onClose}>
      <View style={{ flex: 1, backgroundColor: c.background }}>
        <View
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: Spacing.three,
          }}>
          <Text style={{ color: c.text, fontSize: 20, fontWeight: '700' }}>{t.login.chooseInstitution}</Text>
          <Pressable onPress={onClose} hitSlop={10}>
            <Text style={{ color: c.brand, fontSize: 17 }}>{t.common.cancel}</Text>
          </Pressable>
        </View>

        <View style={{ paddingHorizontal: Spacing.three, paddingBottom: Spacing.two }}>
          <View
            style={{
              flexDirection: 'row',
              alignItems: 'center',
              gap: Spacing.two,
              backgroundColor: c.card,
              borderRadius: Radius.md,
              paddingHorizontal: Spacing.three,
              borderCurve: 'continuous',
            }}>
            <SymbolView name="magnifyingglass" tintColor={c.textTertiary} size={16} />
            <TextInput
              style={{ flex: 1, paddingVertical: Spacing.three - 2, color: c.text, fontSize: 16 }}
              placeholder={t.login.searchPlaceholder}
              placeholderTextColor={c.textTertiary}
              autoCorrect={false}
              autoCapitalize="none"
              value={query}
              onChangeText={setQuery}
            />
          </View>
        </View>

        {institutes === null && !failed ? (
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
            <ActivityIndicator color={c.brand} />
          </View>
        ) : failed ? (
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: Spacing.four }}>
            <Text style={{ color: c.textSecondary, textAlign: 'center', lineHeight: 22 }}>
              {t.login.institutionsFailed}
            </Text>
          </View>
        ) : (
          <FlatList
            data={filtered}
            keyExtractor={(item, index) => `${item.url}-${index}`}
            contentContainerStyle={{ paddingHorizontal: Spacing.three, paddingBottom: Spacing.six }}
            keyboardShouldPersistTaps="handled"
            keyboardDismissMode="on-drag"
            ListEmptyComponent={
              <Text style={{ color: c.textTertiary, textAlign: 'center', paddingTop: Spacing.four }}>
                {t.login.noResults}
              </Text>
            }
            renderItem={({ item }) => (
              <Pressable
                onPress={() => {
                  onSelect(item);
                  onClose();
                }}
                style={({ pressed }) => ({
                  paddingVertical: Spacing.three,
                  borderBottomWidth: 1,
                  borderBottomColor: c.separator,
                  opacity: pressed ? 0.5 : 1,
                })}>
                <Text style={{ color: c.text, fontSize: 16 }}>{item.name}</Text>
              </Pressable>
            )}
          />
        )}
      </View>
    </Modal>
  );
}
