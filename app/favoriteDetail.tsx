import React, {useLayoutEffect} from 'react'
import { ScrollView, StyleSheet } from 'react-native'
import StopCard from "@/components/stopCard";
import {useLocalSearchParams, useNavigation} from 'expo-router';
import {useFavorites} from "@/app/contexts/favoritesContext";
import type {Favorite, FavoriteStop, SimpleTime} from '@/app/types/types';
import {useQueries } from "@tanstack/react-query";

const CTA_URL = process.env.EXPO_PUBLIC_API_URL ?? '';

export default function FavoriteDetail() {
    const {favoriteId} = useLocalSearchParams<{favoriteId: string}>();
    const {favorites} = useFavorites();
    const navigation = useNavigation()

    const favorite = favorites.find((f: Favorite)=> f.id === favoriteId);

    // console.log("printing fav", favorite)

    const favStops: FavoriteStop[] = favorite?.stops ?? [];

    /* useEffect(() => {
        console.log('favStops changed:', favStops);
    }, [favStops]);
     */

    async function busTime(routeId: string, direction: string, stopId: string) {
        const response = await fetch(`${CTA_URL}/api/bus/times?routeId=${routeId}&direction=${direction}&stopId=${stopId}`);

        const json : SimpleTime[] = await response.json();

        return json
    }

    async function trainTime(stopId: string, routeId: string) {

        try {
            const response = await fetch(`${CTA_URL}/api/train/times?&stopId=${stopId}&routeId=${routeId}`);

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const json: SimpleTime[] = await response.json();

            return json;
        } catch (error) {
            console.error("trainTime error:", error);
            throw error; // Re-throw so React Query can handle it
        }
    }

    const timeQueries = useQueries({
            queries: favStops.map((routeObj)=> ({
                queryKey: ["times", routeObj.routeId, routeObj.direction, routeObj.stopId, routeObj.type] as const,

                queryFn: () => {
                    return routeObj.type === 'bus' ?
                        busTime(routeObj.routeId, routeObj.direction, routeObj.stopId)
                        : trainTime(routeObj.stopId, routeObj.routeId);
                },
                staleTime: 60_000,
                refetchInterval: 60_000,
                refetchIntervalInBackground: true,
                refetchOnMount: false,
                refetchOnWindowFocus: false,
            }))
    });



    useLayoutEffect(() => {
        if (favorite) {
            navigation.setOptions({
                title: favorite.name, // e.g. “home”, “work”, etc.
            })
        }
    }, [favorite, navigation])


    return (
        <ScrollView
            style={styles.container}
            contentContainerStyle={styles.contentContainer}
            showsVerticalScrollIndicator={false}
        >
            {favStops.map((routeObj, idx)=> {
                const {data: times = [], isLoading, isError} = timeQueries[idx] ?? {};
                return (
                    <StopCard key={routeObj.stopId}
                              times={times}
                              header={routeObj.routeName.split(/\s+/)[0]}
                              subheader={routeObj.direction}
                              stop={routeObj.stopName}/>
                );
            })}
        </ScrollView>
    )
}




const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#ffffff',
    },
    contentContainer: {
        paddingTop: 25,
        paddingBottom: 32,
        alignItems: 'center',
    },
    center: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
    },
    title: {
        fontSize: 22,
        fontWeight: '600',
        marginBottom: 12,
    },
    errorText: {
        color: 'red',
    },
});
