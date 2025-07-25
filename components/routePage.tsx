import DropdownComponent, {DataItem, dropdownProps} from './dropdown';
import Header2 from "./header2";
import {GestureHandlerRootView} from "react-native-gesture-handler";
import {StyleSheet, View} from "react-native";
import ButtonPair from "./buttonPair"
import CtaButton, {ctaProps} from "./cta"
import React, {useState, useEffect} from 'react';



type pageProps = ctaProps & {
    routeDropdown: dropdownProps;
    stopDropdown: dropdownProps;
    routeHeader: string;
    directionHeader: string;
    stopHeader: string;
    direction1: string;
    direction2: string;
    selectedDirection: 0 | 1 | null;
    onDirectionSelect: (idx: 0 | 1) => void;
    theme: string;
}


export default function Page ({routeHeader, directionHeader, stopHeader,
                                  routeDropdown, stopDropdown,
                                  direction1, direction2,
                                  selectedDirection, onDirectionSelect, buttonText, onPress, theme
                              }: pageProps) {

    return(
        <GestureHandlerRootView style={styles.container}>
            <View style={styles.routeHeader}>
                <Header2 text={routeHeader}/>
            </View>
            <View style={styles.dropdownWrapper}>
                <DropdownComponent {...routeDropdown}/>
            </View>
            {routeDropdown.value != null && (
                <>
                    <View style={styles.routeHeader}>
                        <Header2 text={directionHeader}/>
                    </View>
                    <View style={styles.dropdownWrapper}>
                        <ButtonPair
                            topText={direction1}
                            bottomText={direction2}
                            selectedIndex={selectedDirection}
                            onSelect={onDirectionSelect}
                        />
                    </View>
                </>
            )}
            {(selectedDirection != null) && (routeDropdown.value != null)  && (
                <>
                    <View style={styles.routeHeader}>
                        <Header2 text={stopHeader}/>
                    </View>
                    <View style={styles.dropdownWrapper}>
                        <DropdownComponent {...stopDropdown}/>
                    </View>
                </>
            )}
            {stopDropdown.value != null && (
                <>
                    <View style={styles.dropdownWrapper}>
                        <CtaButton
                            buttonText={buttonText}
                            onPress={onPress}
                            theme={theme}
                        />
                    </View>
                </>
            )

            }

        </GestureHandlerRootView>
    );

}


const styles = StyleSheet.create({
    container: {
        flex: 1,
        paddingHorizontal: 25,
        paddingTop: 0, // instead of absolute left/top
        backgroundColor: 'white',
    },
    routeHeader: {
        marginTop: 25,
        marginBottom: 25,
    },
    dropdownWrapper: {
        //top: 40,
        //  left: 0,
        flexDirection: "row",
        alignItems: 'stretch',
    }
});