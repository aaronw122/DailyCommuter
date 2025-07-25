import React, { useState } from 'react';
import { StyleSheet, View, Text } from 'react-native';
import { Dropdown } from 'react-native-element-dropdown';
import AntDesign from '@expo/vector-icons/AntDesign';

export type DataItem = {
    label: string;
    value: string | number;
}

export type dropdownProps = {
    data: DataItem[];
    placeholder: string;
    searchPlaceholder: string;
    value: string | number | null; //routeId or stopId
    onChange: (item: DataItem)=> void;
    label: string;
}

export default function DropdownComponent ({data, placeholder, searchPlaceholder, value, onChange, label}: dropdownProps){

    const renderItem = (item: DataItem) => {
        return (
            <View style={styles.item}>
                <Text style={styles.textItem}>{item.label}</Text>
                {item.value === value && (
                    <AntDesign
                        style={styles.icon}
                        color="black"
                        name="check"
                        size={20}
                    />
                )}
            </View>
        );
    };

    return (
        <Dropdown
            style={styles.dropdown}
            containerStyle={styles.menu}
            placeholderStyle={styles.placeholderStyle}
            selectedTextStyle={styles.selectedTextStyle}
            inputSearchStyle={styles.inputSearchStyle}
            iconStyle={styles.iconStyle}
            data={data}
            search
            maxHeight={300}
            labelField={label}
            valueField="value"
            value={value}
            placeholder = {placeholder}
            searchPlaceholder = {searchPlaceholder}
            onChange={onChange}
            renderItem={renderItem}
        />
    );
};

const styles = StyleSheet.create({
    dropdown: {
        height: 50,
       // width: 100,
        flex: 1,
        alignSelf: "flex-start",
        backgroundColor: 'white',
        borderRadius: 12,
        padding: 12,
        shadowColor: '#000',
        shadowOffset: {
            width: 0,
            height: 0,
        },
        shadowOpacity: 0.2,
        shadowRadius: 2,

        elevation: 3,
    },
    menu: {
        borderRadius: 12,
        overflow: 'hidden',    // clip children to rounded corners
        // optional: add a little margin so it doesn’t butt right up to the input
        marginTop: 5,
        // if you want a shadow on the list:
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 0 },
        shadowOpacity: 0.2,
        shadowRadius: 3,
        elevation: 3,
    },
    icon: {
        marginRight: 5,
    },
    item: {
        padding: 17,
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
    },
    textItem: {
        flex: 1,
        fontSize: 16,
    },
    placeholderStyle: {
        fontSize: 16,
    },
    selectedTextStyle: {
        fontSize: 16,
    },
    iconStyle: {
        width: 20,
        height: 20,
    },
    inputSearchStyle: {
        height: 40,
        fontSize: 16,
    },
});