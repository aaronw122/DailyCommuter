import AsyncStorage from '@react-native-async-storage/async-storage';
import React, { createContext, useContext, useEffect, useReducer, useRef } from 'react';
import { NativeModules, Platform } from 'react-native';
import { Favorite } from '@/app/types/types'

type Action =
    | { type: 'load'; favorites: Favorite[] }
    | { type: 'add'; favorite: Favorite }
    | { type: 'update'; favorite: Favorite }
    | { type: 'remove'; id: string };

function reducer(state: Favorite[], action: Action): Favorite[] {
    switch (action.type) {
        case 'load':    return action.favorites;
        // add action = adds a new Favorite (in the top-level list).
        case 'add':     return [...state, action.favorite];
        // update action = replaces an existing Favorite (including whatever changes you made to its stops).
        case 'update':  return state.map(f =>
            f.id === action.favorite.id
                ? action.favorite
                : f
        );
        case 'remove':  return state.filter(f =>
            f.id !== action.id
        );
        default: return state;
    }
}

export const FavoritesContext = createContext<{
    favorites: Favorite[];
    dispatch: React.Dispatch<Action>;
}>(null!);


export function FavoritesProvider({ children }: { children: React.ReactNode }) {
    // 8
    const [favorites, dispatch] = useReducer(reducer, []);
    const didLoadRef = useRef(false);

    useEffect(() => {
        AsyncStorage.getItem('favorites')
            .then(data => {
                if (data) {
                    dispatch({ type: 'load', favorites: JSON.parse(data) });
                }
            })
            .finally(() => {
                didLoadRef.current = true;
            });
    }, []);

    const saveFavoritesToWidget = async (favs: Favorite[]) => {
        if (Platform.OS !== 'ios') return;
        const bridge = (NativeModules as any).FavoritesBridge;
        if (!bridge || typeof bridge.saveFavorites !== 'function') return;
        try {
            await bridge.saveFavorites(JSON.stringify(favs));
        } catch (e) {
            if (__DEV__) {
                // eslint-disable-next-line no-console
                console.warn('saveFavoritesToWidget failed:', e);
            }
        }
    };

    useEffect(() => {
        if (!didLoadRef.current) return;
        // Persist to local storage immediately
        AsyncStorage.setItem('favorites', JSON.stringify(favorites));
        // Debounce the native bridge call to avoid spamming on rapid edits
        const t = setTimeout(() => {
            void saveFavoritesToWidget(favorites);
        }, 250);
        return () => clearTimeout(t);
    }, [favorites]);

    return (
        <FavoritesContext.Provider value={{ favorites, dispatch }}>
            {children}
        </FavoritesContext.Provider>
    );
}
export const useFavorites = () => useContext(FavoritesContext);
