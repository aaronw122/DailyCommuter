import { Tabs, useRouter } from 'expo-router';
import Ionicons from '@expo/vector-icons/Ionicons';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import AntDesign from '@expo/vector-icons/AntDesign';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useCallback, useEffect, useState } from 'react';
import {
    Modal,
    Pressable,
    StyleSheet,
    Text,
    View,
} from 'react-native';
import Header from '@/components/header';


export default function TabLayout() {
    type TabBarItemProps = {
        color: string;
        focused: boolean;
    };

    const [showOnboarding, setShowOnboarding] = useState(false);
    const router = useRouter();

    useEffect(() => {
        let isMounted = true;

        const loadOnboardingState = async () => {
            try {
                const hasSeen = await AsyncStorage.getItem('hasSeenOnboarding');
                if (isMounted && !hasSeen) {
                    setShowOnboarding(true);
                }
            } catch {
                if (isMounted) {
                    setShowOnboarding(true);
                }
            }
        };

        loadOnboardingState();

        return () => {
            isMounted = false;
        };
    }, []);

    const closeOnboarding = useCallback(async () => {
        setShowOnboarding(false);
        try {
            await AsyncStorage.setItem('hasSeenOnboarding', 'true');
        } catch {
            // Ignore storage errors; the sheet can reappear if saving fails.
        }
    }, []);

    const openOnboarding = useCallback(() => {
        setShowOnboarding(true);
    }, []);

    const steps = [
        'Find your regular bus or train route.',
        'Add it to a favorite location.',
        'Add the "Daily Commuter" widget to your Home Screen — pick your favorite to see live times.',
    ];

    return (
        <>
            <Modal animationType="slide" visible={showOnboarding} transparent>
                <View style={styles.backdrop}>
                    <View style={styles.sheet}>
                        <View style={styles.sheetHeader}>
                            <Text style={styles.sheetTitle}>Welcome to DailyCommuter</Text>
                            <Pressable hitSlop={8} onPress={closeOnboarding} style={styles.closeButton}>
                                <Ionicons color="#0B1E2A" name="close" size={20} />
                            </Pressable>
                        </View>
                        <View style={styles.stepList}>
                            {steps.map((step, index) => (
                                <View key={step} style={styles.stepRow}>
                                    <View style={styles.stepBadge}>
                                        <Text style={styles.stepNumber}>{index + 1}</Text>
                                    </View>
                                    <Text style={styles.stepText}>{step}</Text>
                                </View>
                            ))}
                        </View>
                        <Text style={styles.helperText}>
                            You can also stack multiple widgets for different favorites.
                        </Text>
                        <Pressable onPress={closeOnboarding} style={styles.primaryButton}>
                            <Text style={styles.primaryButtonText}>Get Started</Text>
                        </Pressable>
                    </View>
                </View>
            </Modal>
            <Tabs
                screenOptions={{
                    tabBarActiveTintColor: '#0078C1',
                    tabBarInactiveTintColor:'#00000080',
                    headerStyle: {
                        backgroundColor: '#ffffff',
                    },
                    headerShadowVisible: false,
                    tabBarStyle: {
                        backgroundColor: '#ffffff',
                    },
                }}
            >
                <Tabs.Screen
                    name="index"
                    options={{
                        headerShown: true,
                        headerTitle: () => <Header text={'Daily Commuter'} icon="person-walking" />,
                        headerTitleStyle: {fontSize: 24, fontWeight: '400', color: '#0078C1'},
                        headerTitleAlign: 'center',
                        headerStyle: {
                            backgroundColor: '#ffffff',
                            height: 125,
                        },
                        headerRight: () => (
                            <Pressable onPress={openOnboarding} style={styles.helpButton}>
                                <Ionicons color="#000000" name="help-circle-outline" size={24} />
                            </Pressable>
                        ),
                        tabBarLabel: ({ color, focused}: TabBarItemProps) => (
                            <Text style ={{ fontSize: focused ? 12.5 : 12, color}}>
                                Home
                            </Text>
                        ),
                        tabBarIcon: ({ color, focused }: TabBarItemProps) => (
                            <Ionicons name='home-outline' size ={focused ? 25 : 24} color={color} />
                        ),
                    }}
                />
                <Tabs.Screen
                    name="favorites"
                    options={{
                        headerShown: true,
                        headerTitle: 'Favorites',
                        headerTitleStyle: {fontSize: 24, fontWeight: '400', color: '#000000'},
                        headerTitleAlign: 'center',
                        headerRight: () => (
                            <Pressable onPress={() => router.push('/modals/createFavorite')} style={{marginRight: 25}}>
                                <AntDesign name = "plus" size={24} color="black"/>
                            </Pressable>
                        ),
                        headerStyle: {
                            backgroundColor: '#ffffff',
                            height: 125,
                        },

                        headerShadowVisible: true,
                        headerTintColor: '#000000',

                        tabBarLabel: ({ color, focused}: TabBarItemProps) => (
                            <Text style ={{ fontSize: focused ? 12.5 : 12, color}}>
                                Favorites
                            </Text>
                        ),
                        tabBarIcon: ({ color, focused }: TabBarItemProps) => (
                            <MaterialIcons name='favorite-outline' size ={focused ? 25 : 24} color={color}/>
                        ),
                    }}
                />
            </Tabs>
        </>
    );
}

const styles = StyleSheet.create({
    backdrop: {
        alignItems: 'stretch',
        backgroundColor: 'rgba(11, 30, 42, 0.35)',
        flex: 1,
        justifyContent: 'flex-end',
    },
    sheet: {
        backgroundColor: '#ffffff',
        borderTopLeftRadius: 24,
        borderTopRightRadius: 24,
        gap: 20,
        height: '50%',
        paddingHorizontal: 28,
        paddingTop: 32,
        paddingBottom: 36,
        width: '100%',
    },
    sheetHeader: {
        alignItems: 'center',
        paddingBottom: 8,
        position: 'relative',
    },
    sheetTitle: {
        color: '#0078C1',
        fontSize: 20,
        fontWeight: '700',
        textAlign: 'center',
        width: '100%',
    },
    closeButton: {
        padding: 4,
        position: 'absolute',
        right: 0,
        top: 0,
    },
    stepList: {
        flexGrow: 1,
        gap: 20,
    },
    stepRow: {
        flexDirection: 'row',
        gap: 16,
        alignItems: 'flex-start',
    },
    stepBadge: {
        alignItems: 'center',
        backgroundColor: '#E6EFF5',
        borderColor: '#D0D7DD',
        borderWidth: StyleSheet.hairlineWidth,
        borderRadius: 999,
        height: 36,
        justifyContent: 'center',
        width: 36,
    },
    stepNumber: {
        color: '#0078C1',
        fontSize: 18,
        fontWeight: '700',
    },
    stepText: {
        color: '#0B1E2A',
        flex: 1,
        fontSize: 16,
        lineHeight: 22,
        marginTop: 7,
    },
    helperText: {
        color: '#5B6B78',
        fontSize: 14,
        lineHeight: 20,
    },
    primaryButton: {
        alignItems: 'center',
        backgroundColor: '#0078C1',
        borderRadius: 12,
        paddingVertical: 14,
    },
    primaryButtonText: {
        color: '#ffffff',
        fontSize: 16,
        fontWeight: '600',
    },
    helpButton: {
        marginRight: 20,
    },
});
