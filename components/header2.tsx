import React from 'react';
import {View, Text, StyleSheet} from 'react-native';

export type header2Props = {
    text: string;
}

export default function Header2({text}: header2Props){
    return (
        <View>
            <Text style={styles.headerText}>{text}</Text>
        </View>
    );
}

const styles = StyleSheet.create({
    headerText: {
        color: '#000000',
        fontSize: 20,
    },
});

