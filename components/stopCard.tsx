import React from 'react'
import { View, Text, StyleSheet, Dimensions } from 'react-native'
import Ionicons from '@expo/vector-icons/Ionicons';
import AntDesign from '@expo/vector-icons/AntDesign';
import Time from './times'
import type { SimpleTime } from '@/server/src/ctaService';


type Props ={
    times: SimpleTime[],
    header: number | string;
    subheader: string;
    stop: string;
}


export default function StopCard ({times=[], header, subheader, stop}:Props) {

    return (

        <View style={styles.card}>

            {/* Header */}
            <View style={styles.header}>
                <Ionicons name="bus" size={35} color="#79C747"/>
                <Text style={styles.title}>
                    {/* route number */}
                    {header}
                </Text>
            </View>
            <View style={styles.subheader}>
                <AntDesign name="arrowright" size={25} color="black" />
                <Text style={styles.subtitle}>
                    {/* direction */}
                    {subheader}
                </Text>
            </View>
            <Text style={styles.text}>
                {stop}
            </Text>
            <View style={styles.times}>
                {times?.map(({times: time, dest}, i) => (
                    <Time key={i} time={time} dest={dest}/>
                ))}
            </View>
        </View>
    );
};

const styles = StyleSheet.create({
    card: {
        backgroundColor: 'white',
        borderRadius: 15,
        paddingHorizontal: 16,
        shadowColor: 'black',
        shadowOffset: {
            width: 0,
            height: 0,
        },
        shadowOpacity: 0.3,
        shadowRadius: 2,
        elevation: 14,
        width: 340,
        height: 275,
        marginBottom: 16,
    },

    header: {
        paddingTop: 15,
        marginBottom: 0,
        flexDirection: 'row',
    },
    title: {
        paddingLeft: 6,
        fontSize: 30,
        fontWeight: 'normal',
        color: 'black',
    },
    subheader: {
        paddingTop: 2,
        flexDirection:'row',
    },
    subtitle: {
        fontSize: 20,
        color: '#333',
        marginTop: 0,
    },
    times: {
        paddingTop: 0,
    },
    text: {
        color: '#444444',
        justifyContent: "flex-start",
        paddingBottom: 10,

    },
});
