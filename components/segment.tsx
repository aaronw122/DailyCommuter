import { createMaterialTopTabNavigator } from '@react-navigation/material-top-tabs';
import Bus from '@/app/screens/bus'
import Train from '@/app/screens/train'
import {StyleSheet, ViewStyle, View} from "react-native";


const Tab = createMaterialTopTabNavigator();


export default function MyTabs() {
    return (
        <View style = {styles.tabs}>
            <Tab.Navigator
                screenOptions={{
                    tabBarStyle: { backgroundColor: 'white' },
                    tabBarLabelStyle: { fontSize: 14, fontWeight: 'bold' },
                    tabBarIndicatorStyle: { backgroundColor: 'black' },
                    swipeEnabled: true,
                    //
                    sceneStyle: { backgroundColor: 'white' },
                }}
                initialRouteName="Bus"
            >
                <Tab.Screen name="Train" component={Train} />
                <Tab.Screen name="Bus" component={Bus} />
            </Tab.Navigator>
        </View>

    );
}


const styles = StyleSheet.create({
    tabs: {
        alignSelf: 'stretch',
        flex: 17,
        // left: 30,
    },

});