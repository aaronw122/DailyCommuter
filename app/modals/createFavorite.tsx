import React from 'react'
import {View, StyleSheet, TextInput} from 'react-native'
import {GestureHandlerRootView} from "react-native-gesture-handler";
import CtaButton from "@/components/cta";
import {useRouter} from "expo-router";
import {useFavorites} from '@/app/contexts/favoritesContext';
import 'react-native-get-random-values';
import { v4 as uuid } from 'uuid';
import {FavoriteStop} from "@/app/types/types";


export default function CreateFavorite() {
    const [name, setName] = React.useState('');
    const router = useRouter();
    const {dispatch} = useFavorites();

    const handleSave = () => {
        if (!name.trim()) return;
        dispatch({
            type: 'add',
            favorite: { id: uuid(), name: name.trim(), stops: [] as FavoriteStop[]}
        });
    };

    return (
        <GestureHandlerRootView style={styles.container}>
            <View style={styles.textbox}>
                <TextInput
                    placeholder={"Title your favorite"}
                    style={styles.input}
                    onChangeText={setName}
                    value={name}
                    />
            </View>

            <View style={styles.button}>
                <CtaButton
                    buttonText={"Done"}
                    onPress={()=>{
                        handleSave();
                        router.back();
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
    button: {
        bottom: -475,
        flexDirection: "row",
        alignItems: 'stretch',
    }

});
