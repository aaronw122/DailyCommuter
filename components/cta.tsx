import React from 'react'
import { Pressable, Text, StyleSheet } from 'react-native'

export type ctaProps = {
    buttonText: string;
    onPress: () => void;
    theme: string;
}

export default function CtaButton({ buttonText, onPress, theme}: ctaProps){
    return(
        theme === 'primary' ?
        <Pressable
            onPress={onPress}
            style={styles.primary}>
            <Text style={styles.primaryText}>{buttonText}</Text>
        </Pressable>
        :
        <Pressable
            onPress={onPress}
            style={styles.secondary}>
            <Text style={styles.secondaryText}>{buttonText}</Text>
        </Pressable>
    )
}



const styles = StyleSheet.create({
    primary: {
        marginTop: 45,
        width: '100%',
        height: 50,
        borderRadius: 10,
        backgroundColor: '#0078C1',
        alignItems: 'center',
        justifyContent: 'center',
    },
    secondary: {
        marginTop: 45,
        width: '100%',
        height: 50,
        borderRadius: 10,
        backgroundColor: '#ECF2FF',
        alignItems: 'center',
        justifyContent: 'center',
    },
    default: {
        marginTop: 45,
        width: '100%',
        height: 50,
        borderRadius: 10,
        backgroundColor: '#0078C1',
        alignItems: 'center',
        justifyContent: 'center',
    },
    primaryText: {
        color: '#ffffff',
        fontSize: 16,
    },
    secondaryText: {
        color: '#0078C1',
        fontSize: 16,
    },
})
