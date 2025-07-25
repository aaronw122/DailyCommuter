import Page from "@/components/routePage";
import React, {useState, useEffect} from 'react';
import {StyleSheet} from "react-native";
import { useRouter } from 'expo-router';
import {SimpleDirection, SimpleStop} from "@/app/types/types";
import {busRoutesData} from '@/app/routesData';


export default function Bus (){
    const [routeId, setRouteId]    = useState<string | number | null>(null);

    const [routeName, setRouteName]    = useState<string | null>(null);

    const type = "bus";

    useEffect(() => {
        console.log('Route changed:', routeId);
    }, [routeId]);

    const [direction, setDirection] = useState<string | null>(null);
    useEffect(() => {
        console.log('Direction changed:', direction);
    }, [direction]);

    const [directionOptions, setDirectionOptions] = useState<SimpleDirection[]>([]);


    useEffect(() => {

        setDirectionOptions([]);

        if (routeId == null) {
            return;
        }

        fetch(`https://ctas.us/api/bus/directions?routeId=${routeId}`)
            .then(response => response.json())
            .then((directions: SimpleDirection[]) => setDirectionOptions(directions))
            .catch(err => console.error('CTA fetch error:', err));
    },[routeId])


    const [stopId, setStopId] = useState<number | string | null>(null);
    useEffect(() => {
        console.log('Stop changed:', stopId);
    }, [stopId]);

    const [stopOptions, setStopOptions] = useState<SimpleStop[]>([]);


    useEffect(() => {
        setStopOptions([]);

        if (routeId == null || direction == null) {
            return;
        }
        fetch(`https://ctas.us/api/bus/stops?routeId=${routeId}&direction=${direction}`)
            .then(response => response.json())
            .then((stops: SimpleStop[]) => setStopOptions(stops))
            .catch(err => {
                console.error('CTA fetch error:', err);
            });
    },[routeId, direction])



    const [stopName, setStopName] = useState<string | null>(null);

    const direction1 = directionOptions[0]?.id ?? null;
    const direction2 = directionOptions[1]?.id ?? null;


    // Derive numeric index for Page/ButtonPair highlighting
    const selectedDirectionIndex = direction === direction1
        ? 0
        : direction === direction2
            ? 1
            : null;

    const router = useRouter();



    return(
        <Page
            routeHeader = "Route"
            directionHeader = "Direction"
            stopHeader = "Stop"
            direction1={direction1}
            direction2={direction2}
            selectedDirection={selectedDirectionIndex}
            onDirectionSelect={(idx: 0 | 1) => {
                const newDir = idx === 0 ? direction1 : direction2;
                setDirection(newDir);
            }}
            routeDropdown={{
                data: busRoutesData,
                placeholder:'Select a route',
                searchPlaceholder:'Find a route',
                value: routeId,
                label: 'label',
                onChange: (item) =>{
                    setRouteId(item.value)
                    setRouteName(item.label)
                },
            }}
            stopDropdown={{
                data: stopOptions,
                placeholder:'Select a route',
                searchPlaceholder:'Find a route',
                value: stopId,
                label: 'label',
                onChange: (item)=>{
                    setStopId(item.value);
                    setStopName(item.label);
                },

        }}
            buttonText = "Save to favorites"

            onPress={() => {
                router.push({
                    pathname: '/modals/saveFavorite',
                    params: {
                        routeId,
                        routeName,
                        stopId,
                        direction,
                        stopName,
                        type
                    },
                });
                console.log('save clicked')
            }}

            theme = 'primary'

              />
    );

}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        paddingHorizontal: 25,
        paddingTop: 35, // instead of absolute left/top
        backgroundColor: 'white',
    },
    routeHeader: {
        marginBottom: 25,
    },
    dropdownWrapper: {
        //top: 40,
        //  left: 0,
        flexDirection: "row",
        alignItems: 'stretch',
    }
});


/*
<GestureHandlerRootView style={styles.container}>
    <View style={styles.routeHeader}>
        <Header2 text="Route"/>
    </View>
    <View style={styles.dropdownWrapper}>
        <DropdownComponent data={busDropdownMock} placeholder={'Select a route'} searchPlaceholder={'Find a route'}/>
    </View>
    <View style={styles.routeHeader}>
        <Header2 text="Direction"/>
    </View>
    <View style={styles.dropdownWrapper}>
        { two box selector }
    </View>
    <View style={styles.routeHeader}>
        <Header2 text="Stop"/>
    </View>
    <View style={styles.dropdownWrapper}>
        <DropdownComponent data={busDropdownMock} placeholder={'Select a route'} searchPlaceholder={'Find a route'}/>
    </View>
</GestureHandlerRootView>
*/