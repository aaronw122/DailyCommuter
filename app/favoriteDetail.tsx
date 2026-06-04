import React, {useLayoutEffect} from 'react'
import { ScrollView, StyleSheet } from 'react-native'
import StopCard from "@/components/stopCard";
import {useLocalSearchParams, useNavigation} from 'expo-router';
import {useFavorites} from "@/app/contexts/favoritesContext";
import type {Favorite, FavoriteStop, SimpleTime} from '@/app/types/types';
import {useQueries } from "@tanstack/react-query";

const CTA_URL = process.env.EXPO_PUBLIC_API_URL ?? '';

async function fetchBusTimes(routeId: string, direction: string, stopId: string): Promise<SimpleTime[]> {
    const response = await fetch(`${CTA_URL}/api/bus/times?routeId=${routeId}&direction=${direction}&stopId=${stopId}`);
    return response.json();
}

async function fetchTrainTimes(stopId: string, routeId: string): Promise<SimpleTime[]> {
    const response = await fetch(`${CTA_URL}/api/train/times?stopId=${stopId}&routeId=${routeId}`);
    if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
}

export default function FavoriteDetail() {
    const {favoriteId} = useLocalSearchParams<{favoriteId: string}>();
    const {favorites} = useFavorites();
    const navigation = useNavigation()

    const favorite = favorites.find((f: Favorite)=> f.id === favoriteId);
    const stops: FavoriteStop[] = favorite?.stops ?? [];

    const timeQueries = useQueries({
            queries: stops.map((stop)=> ({
                queryKey: ["times", stop.routeId, stop.direction, stop.stopId, stop.type] as const,
                queryFn: () => stop.type === 'bus'
                    ? fetchBusTimes(stop.routeId, stop.direction, stop.stopId)
                    : fetchTrainTimes(stop.stopId, stop.routeId),
                staleTime: 60_000,
                refetchInterval: 60_000,
                refetchIntervalInBackground: true,
                refetchOnMount: false,
                refetchOnWindowFocus: false,
            }))
    });

    useLayoutEffect(() => {
        if (favorite) {
            navigation.setOptions({ title: favorite.name })
        }
    }, [favorite, navigation])

    return (
        <ScrollView
            style={styles.container}
            contentContainerStyle={styles.contentContainer}
            showsVerticalScrollIndicator={false}
        >
            {stops.map((stop, idx)=> {
                const {data: times = [], isLoading} = timeQueries[idx] ?? {};
                return (
                    <StopCard key={stop.stopId}
                              times={times}
                              header={stop.routeName.split(/\s+/)[0]}
                              subheader={stop.direction}
                              stop={stop.stopName}
                              isLoading={isLoading}/>
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
});
