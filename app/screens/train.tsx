import Page from "@/components/routePage";
import React, {useState, useEffect} from 'react';
import { useRouter } from 'expo-router';
import {trainRoutesData, trainDirectionData} from '@/app/routesData';
import {TrainStop} from "@/app/types/types";



export default function Train (){
    const type = 'train'

    const [routeId, setRouteId]    = useState<string | number | null>(null);

    const [routeName, setRouteName]    = useState<string | null>(null);

    /*
    useEffect(() => {
        console.log('Route changed:', routeId);
    }, [routeId]);
    */

    const [direction, setDirection] = useState<string | null>(null);
    /*
    useEffect(() => {
        console.log('Direction changed:', direction);
    }, [direction]);
     */

const [directionOptions, setDirectionOptions] = useState<string[]>([]);

const showDirections = directionOptions.length > 0;

useEffect(() => {

    setDirectionOptions([]);

    if (routeId == null) {
        return;
    }
    const entry = trainDirectionData.find(r => r.value === routeId);
    // if it exists, its .label is just a string[] of the two directions
    setDirectionOptions(entry?.label ?? []);
}, [routeId]);


const [stopId, setStopId] = useState<number | string | null>(null);

/*
useEffect(() => {
    console.log('Stop changed:', stopId);
}, [stopId]);
 */

const [stopOptions, setStopOptions] = useState<TrainStop[]>([]);

const showStops = stopOptions.length > 0;

useEffect(() => {
    setStopOptions([]);

    if (routeId == null || direction == null) {
        return;
    }
    console.log("direction:", direction)
    fetch(`https://ctas.us/api/train/stops?routeId=${routeId}&direction=${direction}`)
        .then(response => response.json())
        .then((stops: TrainStop[]) => setStopOptions(stops))
        .catch(err => {
            console.error('CTA fetch error:', err);
        });
},[routeId, direction])

const [stopName, setStopName] = useState<string | null>(null);

const direction1 = directionOptions[0] ?? null;
const direction2 = directionOptions[1] ?? null;


const selectedDirectionIndex = direction === direction1
    ? 0
    : direction === direction2
        ? 1
        : null;

const router = useRouter();



return(
    <Page
        routeHeader = "Route"
        routeDropdown={{
            data: trainRoutesData,
            placeholder:'Select a route',
            searchPlaceholder:'Find a route',
            value: routeId,
            label: 'label',
            onChange: (item) =>{
                setRouteId(item.value);
                setRouteName(item.label);
            },
        }}
        {...(showDirections? {
            directionHeader: "Direction",
            direction1,
            direction2,
            selectedDirection: selectedDirectionIndex,
            onDirectionSelect: (idx: 0 | 1) => {
            const newDir = idx === 0 ? direction1 : direction2;
            setDirection(newDir);
        },

        } : {} )}
        {...(showStops? {
            stopHeader: "Stop",
            stopDropdown: {
            data: stopOptions,
            placeholder:'Select a route',
            searchPlaceholder:'Find a route',
            value: stopId,
            label: 'label',
            onChange: (item)=>{
                setStopId(item.value);
                setStopName(item.label);
            },
        }}: {})}


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