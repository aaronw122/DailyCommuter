import {StyleSheet, ActionSheetIOS, View} from 'react-native';
import {GestureHandlerRootView} from "react-native-gesture-handler";
import Selector from "@/components/selector";
import {useFavorites} from "@/app/contexts/favoritesContext";
import {useRouter} from "expo-router";


export default function Favorites() {
    const {favorites, dispatch} = useFavorites();
    const router = useRouter();

    const handleLongPress = (id: string) => {
        ActionSheetIOS.showActionSheetWithOptions(
            {
                options: ['Delete', 'Cancel'],
                cancelButtonIndex: 1,
                destructiveButtonIndex:0,
            },
            buttonIndex => {
                if (buttonIndex ===0) {
                    dispatch({
                        type: 'remove',
                        id,
                    })
                }
            }
        )
    }

    return (
        //cta for creating favorite
        //list

    <GestureHandlerRootView>
        <View style={styles.container}>
            {favorites.map(fav => (
              <Selector key={fav.id}
                        name={fav.name}
                        stops={fav.stops.length}
                        onPress={()=> {
                            console.log('clicked',fav.id);
                            router.push({
                                pathname:'/favoriteDetail',
                                params: {favoriteId: fav.id},

                            })
                        }}
                        onLongPress={() => {
                            console.log("long press worked")
                            handleLongPress(fav.id)}}
              />
            ))}
        </View>
    </GestureHandlerRootView>

    );
}


const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#ffffff',
        alignItems: 'center',
    },
    text: {
        color: '#000000',
    },
});
