import React from "react";
import {Pressable, StyleSheet, Text, View} from 'react-native'
import MaterialIcons from '@expo/vector-icons/MaterialIcons';


type checkProps = {
    key: string;
    name: string;
    stops: number;
    onPress: () => void;
    isSelected: boolean;
    isDisabled?: boolean;
}

export default function Checkbox({name, stops, isSelected, onPress, isDisabled = false}:checkProps) {
    const stopsLabel = stops === 1 ? '1 stop' : `${stops} stops`;
    const accessoryColor = isDisabled ? '#C7C7C8' : '#000000';
    return (
        <Pressable
            onPress={onPress}
            disabled={isDisabled}
            style={({pressed}) => [
                styles.container,
                pressed && !isDisabled && styles.pressed
            ]}
            accessibilityState={{ disabled: isDisabled, selected: isSelected }}
        >

            <View style={styles.selectorContent}>
                <View style={styles.strings}>
                    <Text style={styles.title}> {name} </Text>
                    <Text style={styles.subtext}> {stopsLabel}{isDisabled ? ' (full)' : ''} </Text>
                </View>
                <MaterialIcons
                    name={isSelected ? "check-box": "check-box-outline-blank"}
                    size={26}
                    color={accessoryColor}
                />
            </View>

        </Pressable>

    )
}

const styles = StyleSheet.create({
    container: {
        width:"100%",
        marginTop: 25,
        /* extend the border past the parent padding */
        /* inset content by 25pt so text/chevron stay within the margin */
        paddingHorizontal: 25,
        /* draw the separator line full width */
        paddingBottom: 10,
        borderBottomWidth: 1,
        borderBottomColor: "#DFE0E4",
    },
    pressed: {
        opacity: 0.65,
    },
    title:{
        marginBottom: 5,
        fontSize: 22,
    },
    subtext:{
        fontSize: 15,
        color: '#6E6E6E',
    },
    selectorContent: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
    },
    strings: {
        flexDirection: 'column',
    }
});
