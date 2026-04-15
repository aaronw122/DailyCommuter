import React, {useState} from 'react'
import {View, StyleSheet} from 'react-native'
import CtaButton from "@/components/cta";
import {GestureHandlerRootView} from "react-native-gesture-handler";
import { useRouter, useLocalSearchParams } from 'expo-router';
import {useFavorites} from "@/app/contexts/favoritesContext";
import Checkbox from '@/components/checkbox'

const MAX_FAVORITE_STOPS = 4;

export default function SaveFavorite() {
    const router = useRouter();
    const params = useLocalSearchParams();
    const routeId = String(params.routeId) || null;
    const routeName = String(params.routeName) || null;
    const stopId = String(params.stopId) || null;
    const stopName = String(params.stopName) || null;
    const direction = String(params.direction) || null;
    const type = String(params.type) || null;
    const {favorites, dispatch} = useFavorites();
    const [selectedFavorite, setSelectedFavorite] = useState<string | null>(null);

    const handleToggle = (name: string, isFull: boolean) => {
        if (isFull) return;
        setSelectedFavorite(prev => (prev === name ? null : name));
    };



    const handleUpdate = () => {
        const favorite = favorites.find(fav => fav.name === selectedFavorite);

        if (!favorite) return;
        if (favorite.stops.length >= MAX_FAVORITE_STOPS) return;

        dispatch({
            type: 'update',
            favorite: {
                id: favorite.id,
                name: selectedFavorite!,
                stops: [
                    ...favorite.stops,
                    {
                    routeId: routeId!,
                    routeName: routeName!,
                    stopId:  stopId!,
                    stopName: stopName!,
                    direction: direction!,
                    type: type!
                }]
            }
        });
    };


    return (
        <GestureHandlerRootView style={styles.container}>
            <View style ={{flex: 1, width: '100%'}}>
                <View style={{ width: '100%', paddingHorizontal: 25, alignItems: 'center'}}>
                    <CtaButton buttonText={"+ New Favorite"} onPress={() => {
                        router.push('/modals/createFavorite');
                    }}
                               theme = 'secondary'
                    />
                </View>
                <View style={{ width: '100%', alignItems: 'center' }}>
                    {favorites.map(fav => {
                        const isFull = fav.stops.length >= MAX_FAVORITE_STOPS;
                        return (
                            <Checkbox key={fav.id}
                                      name={fav.name}
                                      stops={fav.stops.length}
                                      isSelected={!isFull && selectedFavorite === fav.name}
                                      isDisabled={isFull}
                                      onPress={() => handleToggle(fav.name, isFull)}
                            />
                        );
                    })}
                </View>
            </View>
            <View style={{ width: '100%', paddingHorizontal: 25, alignItems: 'center', marginBottom: 45}}>
                <CtaButton buttonText={"Done"} onPress={() => {
                handleUpdate();
                router.push('/(tabs)/favorites');
            }}
                theme = 'primary'
                />
            </View>
        </GestureHandlerRootView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#ffffff',
    },
});
