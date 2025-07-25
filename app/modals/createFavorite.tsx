import React from 'react'
import {View, Text, StyleSheet, TextInput} from 'react-native'
import {GestureHandlerRootView} from "react-native-gesture-handler";
import AntDesign from '@expo/vector-icons/AntDesign';
import CtaButton from "@/components/cta";
import {useRouter} from "expo-router";
import {useFavorites} from '@/app/contexts/favoritesContext';
import 'react-native-get-random-values';
import { v4 as uuid } from 'uuid';
import {FavoriteStop} from "@/app/types/types";


export default function CreateFavorite() {
    const [text, onChangeText] = React.useState('');
    const router = useRouter();
    const {dispatch} = useFavorites();

    const handleSave = () => {
        if (!text.trim()) return;  // guard
        dispatch({
            type: 'add',
            favorite: { id: uuid(), name: text.trim(), stops: [] as FavoriteStop[]}
        });
        // navigate back or clear input here
    };


    return (
        <GestureHandlerRootView style={styles.container}>

            <View style={styles.textbox}>
                <TextInput
                    placeholder={"Title your favorite"}
                    style={styles.input}
                    onChangeText={onChangeText}
                    value={text}
                    />
            </View>

            <View style={styles.button}>
                <CtaButton
                    buttonText={"Done"}
                    onPress={()=>{
                        handleSave();
                        router.back();

                        console.log(text, 'saved')

                    }}
                    theme = 'primary'
                />
            </View>

        </GestureHandlerRootView>

    )
}


const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#ffffff',
        paddingTop: 0,
        paddingHorizontal: 25,
    },
    input: {
        height: 50,
        margin: 12,
        borderRadius: 12,
        borderWidth: 1,
        padding: 10,
        borderColor:'#E6E6E6',
    },
    textbox: {
        marginTop: 15,
    },
    title: {
        marginTop: 0,
        justifyContent: 'center',
    },
    button: {
        bottom: -475,
        flexDirection: "row",
        alignItems: 'stretch',
    }

});
