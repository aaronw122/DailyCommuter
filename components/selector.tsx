import React from "react";
import {Pressable, StyleSheet, Text, View} from 'react-native'
import Entypo from '@expo/vector-icons/Entypo';



type selectorProps = {
    key: string;
    name: string;
    stops: number;
    onPress: () => void;
    onLongPress: () => void;
}

export default function Selector({name, stops, onPress, onLongPress}:selectorProps) {
    return (
        <Pressable
            onPress={onPress}
            onLongPress={onLongPress}
            style={styles.container}
            >

            <View style={styles.selectorContent}>
                <View style={styles.strings}>
                    <Text style={styles.title}> {name} </Text>
                    {stops === 1 ?
                        <Text style={styles.subtext}> {stops} {"stop"} </Text>
                        :
                        <Text style={styles.subtext}> {stops} {"stops"} </Text>}
                </View>
                <Entypo name="chevron-thin-right" size={27} color='#000000'/>
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