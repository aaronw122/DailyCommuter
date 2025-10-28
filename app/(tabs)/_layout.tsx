import { Tabs, useRouter } from 'expo-router';
import Ionicons from '@expo/vector-icons/Ionicons';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import AntDesign from '@expo/vector-icons/AntDesign';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
    Animated,
    Dimensions,
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

    const [isBackdropVisible, setIsBackdropVisible] = useState(false);
    const router = useRouter();
    const sheetTranslateY = useRef(new Animated.Value(1)).current;
    const windowHeight = useRef(Dimensions.get('window').height).current;
    const sheetHiddenOffset = windowHeight * 0.55;

    useEffect(() => {
        let isMounted = true;

        const loadOnboardingState = async () => {
            try {
                const hasSeen = await AsyncStorage.getItem('hasSeenOnboarding');
                if (isMounted && !hasSeen) {
                    setIsBackdropVisible(true);
                }
            } catch {
                if (isMounted) {
                    setIsBackdropVisible(true);
                }
            }
        };

        loadOnboardingState();

        return () => {
            isMounted = false;
        };
    }, []);

    const animateSheetIn = useCallback(() => {
        sheetTranslateY.setValue(1);
        requestAnimationFrame(() => {
            Animated.timing(sheetTranslateY, {
                toValue: 0,
                duration: 260,
                useNativeDriver: true,
            }).start();
        });
    }, [sheetTranslateY]);

    useEffect(() => {
        if (isBackdropVisible) {
            animateSheetIn();
        }
    }, [animateSheetIn, isBackdropVisible]);

    const closeOnboarding = useCallback(() => {
        Animated.timing(sheetTranslateY, {
            toValue: 1,
            duration: 220,
            useNativeDriver: true,
        }).start(() => {
            setIsBackdropVisible(false);
        });

        AsyncStorage.setItem('hasSeenOnboarding', 'true').catch(() => {
            // Ignore storage errors; the sheet can reappear if saving fails.
        });
    }, [sheetTranslateY]);

    const openOnboarding = useCallback(() => {
        setIsBackdropVisible(true);
    }, []);

    const steps = [
        'Find your regular bus or train route.',
        'Save it to a favorite location.',
        'Add the "DailyCommuter" widget to your Home Screen to see live times.',
    ];

    return (
        <>
            <Modal animationType="none" visible={isBackdropVisible} transparent onRequestClose={closeOnboarding}>
                <Pressable style={styles.backdrop} onPress={closeOnboarding}>
                    <Animated.View
                        style={[
                            styles.sheet,
                            {
                                transform: [
                                    {
                                        translateY: sheetTranslateY.interpolate({
                                            inputRange: [0, 1],
                                            outputRange: [0, sheetHiddenOffset],
                                            extrapolate: 'clamp',
                                        }),
                                    },
                                ],
                            },
                        ]}
                    >
                        <View style={styles.sheetHeader}>
                            <Pressable hitSlop={8} onPress={closeOnboarding} style={styles.closeButton}>
                                <AntDesign color="#000000" name="close" size={24} />
                            </Pressable>
                            <Text style={styles.sheetTitle}>Welcome to DailyCommuter!</Text>
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
                    </Animated.View>
                </Pressable>
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
        paddingTop: 20,
        paddingBottom: 36,
        width: '100%',
    },
    sheetHeader: {
        alignItems: 'center',
        justifyContent: 'center',
        flexDirection: 'row',
        paddingTop: 4,
        paddingBottom: 16,
        position: 'relative',
        width: '100%',
    },
    sheetTitle: {
        color: '#0078C1',
        fontSize: 18,
        fontWeight: '700',
        flex: 1,
        textAlign: 'center',
    },
    closeButton: {
        padding: 4,
        position: 'absolute',
        left: 0,
        top: '50%',
        transform: [{ translateY: -12 }],
    },
    stepList: {
        flexGrow: 1,
        gap: 20,
        marginBottom: -10,
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
