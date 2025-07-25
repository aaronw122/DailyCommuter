import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import FontAwesome6 from '@expo/vector-icons/FontAwesome6';


type Props = {
    icon?: keyof typeof FontAwesome6;
    text: string;

}

export default function Header({icon, text}: Props)  {
    return (
            <View style={styles.header}>
                <FontAwesome6 name={icon} size={24} color ='#0078C1' />
                <Text style={styles.headerText}>{text}</Text>
            </View>
    );
};


const styles = StyleSheet.create({
    header: {
        // flex: 1,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        paddingVertical: 0,
        width: '100%',
        backgroundColor: '#ffffff',
    },
    headerText: {
        color: '#0078C1',
        fontSize: 24,
        marginLeft: 8,
    },
});