import { Tabs, useRouter } from 'expo-router';
import Ionicons from '@expo/vector-icons/Ionicons';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { Text } from 'react-native'
import Header from "@/components/header";
import {Pressable} from "react-native";
import AntDesign from '@expo/vector-icons/AntDesign';


export default function TabLayout() {
    type TabBarItemProps = {
        color: string;
        focused: boolean;
    };

    const router = useRouter();
    return (
        <Tabs
            screenOptions={{
                tabBarActiveTintColor: '#000000',
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
                    headerTitle: (props) => <Header text={'Daily Commuter'} icon ="person-walking" />,
                    headerTitleStyle: {fontSize: 24, fontWeight: '400', color: '#0078C1',},
                    headerTitleAlign: 'center',
                    headerStyle: {
                        backgroundColor: '#ffffff',
                        height: 125,
                        // Increase this value to add more space
                    },

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
                    headerTitleStyle: {fontSize: 24, fontWeight: '400'},
                    headerTitleAlign: 'center',
                    headerRight: () => (
                        <Pressable onPress={() => router.push('/modals/createFavorite')} style={{marginRight: 25}}>
                            <AntDesign name = "plus" size={24} color="black"/>
                        </Pressable>
                    ),
                    headerStyle: {
                        backgroundColor: '#ffffff',
                        height: 125,
                        // Increase this value to add more space
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
    );
}