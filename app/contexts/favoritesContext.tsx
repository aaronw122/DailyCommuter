import AsyncStorage from '@react-native-async-storage/async-storage';
import React, { createContext, useContext, useEffect, useReducer } from 'react';
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

    useEffect(() => {
        AsyncStorage.getItem('favorites')
            .then(data => {
                if (data) {
                    dispatch({ type: 'load', favorites: JSON.parse(data) });
                }
            });
    }, []);

    useEffect(() => {
        AsyncStorage.setItem('favorites', JSON.stringify(favorites));
    }, [favorites]);

    return (
        <FavoritesContext.Provider value={{ favorites, dispatch }}>
            {children}
        </FavoritesContext.Provider>
    );
}
export const useFavorites = () => useContext(FavoritesContext);
