import { Stack } from 'expo-router';
import {Pressable} from "react-native";
import AntDesign from "@expo/vector-icons/AntDesign";
import { FavoritesProvider } from '@/app/contexts/favoritesContext';
import Entypo from "@expo/vector-icons/Entypo";
import React from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";


const queryClient = new QueryClient();


export default function RootLayout() {

  return (
      <QueryClientProvider client={queryClient}>
      <FavoritesProvider>

          <Stack>
              <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
              <Stack.Screen name="+not-found" />
              <Stack.Screen
                  name="modals/createFavorite"
                  options={({ navigation}) => ({
                      title: 'New favorite',
                      presentation: 'modal',
                      headerShown: true,
                      headerLeft: () => (
                          <Pressable onPress={() => navigation.goBack()} style={{ marginLeft: 16 }}>
                              <AntDesign name="close" size={24} color="black" />
                          </Pressable>
                      ),
                  })}
              />
              <Stack.Screen
                  name="modals/saveFavorite"
                  options={({ navigation}) => ({
                      title: 'Save to favorites',
                      presentation: 'card',
                      headerShown: true,
                      headerLeft: () => (
                          <Pressable onPress={() => navigation.goBack()} style={{ marginLeft: 16 }}>
                              <AntDesign name="close" size={24} color="black" />
                          </Pressable>
                      ),
                  })}
              />
              <Stack.Screen
                  name="favoriteDetail"
                  options={({ navigation}) => ({
                      headerShown: true,
                      headerStyle: {
                          height: 125,
                          backgroundColor: "#ffffff"
                      },
                      headerLeft: () => (
                          <Pressable onPress={() => navigation.goBack()} style={{marginLeft: 16}}>
                              <Entypo name="chevron-thin-left" size={24} color='#000000'/>
                          </Pressable>
                      ),
                      headerTitleStyle: {
                          fontSize: 22,
                          fontWeight: '400',
                      }
                  })}
              />
          </Stack>
        </FavoritesProvider>
      </QueryClientProvider>
  );
}