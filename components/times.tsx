import React from 'react'
import { View, Text, StyleSheet } from 'react-native'


type TimeProps = {
    time: string;
    dest: string;
}

export default function Time ({time, dest}:TimeProps) {

    return (
        <View style = {styles.container}>
            <View style = {styles.row}>
                <Text style = {styles.text}>
                    {/^\d+$/.test(time) ? `${time} mins` : time}
                </Text>
                <Text style = {styles.dest}>
                    {dest}
                </Text>
            </View>
        </View>
    )

};


const styles = StyleSheet.create({
    container: {
        flexDirection: 'column',
    },
    row: {
        flexDirection: 'row',
        borderTopWidth: 1,
        borderTopColor: "#DFE0E4",
    },
    text: {
        fontSize: 17,
        color: 'black',
        paddingBottom: 10,
        paddingTop: 10,
    },
    dest : {
        fontSize: 17,
        color: 'grey',
        paddingTop: 10,
        marginLeft: 'auto',
    }
});