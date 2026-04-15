import React from 'react';
import {View, Text, StyleSheet} from 'react-native';


type Props = {
    text: string;
}

export default function FavHeader({text}: Props)  {
    return (
        <View style={styles.header}>
            <Text style={styles.headerText}>{text}</Text>
        </View>
    );
};


const styles = StyleSheet.create({
    header: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        width: '100%',
        backgroundColor: '#ffffff',
    },
    headerText: {
        color: '#0078C1',
        fontSize: 24,
    },
});