import React from 'react';
import {View, Text, StyleSheet, ViewStyle} from 'react-native';
import FontAwesome6 from "@expo/vector-icons/FontAwesome6";

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

