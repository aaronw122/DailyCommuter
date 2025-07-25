import { Text, View, StyleSheet } from 'react-native';
import Header from '@/components/header'
import Header2  from '@/components/header2'
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import MyTabs from '@/components/segment'

export default function Index() {
    return (
        <GestureHandlerRootView style={styles.container}>
            <MyTabs/>
        </GestureHandlerRootView>
    );
}


const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#ffffff',
        paddingTop: 0,
    },
});

