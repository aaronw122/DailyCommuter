import { StyleSheet } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import TransitTabs from '@/components/segment'

export default function Index() {
    return (
        <GestureHandlerRootView style={styles.container}>
            <TransitTabs/>
        </GestureHandlerRootView>
    );
}


const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#ffffff',
    },
});
