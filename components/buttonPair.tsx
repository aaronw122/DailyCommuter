import React from 'react';
import {View, StyleSheet} from 'react-native';
import Button from './button'



type ButtonPairProps = {
    topText: string;
    bottomText: string;
    /** 0 = top, 1 = bottom, null = none selected */
    selectedIndex: 0 | 1 | null;
    /** Callback when a button is tapped */
    onSelect: (idx: 0 | 1) => void;
}


export default function ButtonPair({ topText, bottomText, selectedIndex, onSelect }: ButtonPairProps) {
    return (
        <View style={styles.container}>
            <Button
                text={topText}
                selected={selectedIndex === 0}
                onPress={() => onSelect(0)}
                style={styles.button}
            />
            <Button
                text={bottomText}
                selected={selectedIndex === 1}
                onPress={() => onSelect(1)}
                style={styles.button}
            />
        </View>
    );

}


const styles = StyleSheet.create({
    container: {
        flexDirection: 'column',
        width:"100%",
    },
    button: {
        marginVertical: 4,
    },
});