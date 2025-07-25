import { StyleSheet, View, ViewStyle, Pressable, Text, StyleProp } from 'react-native';

type buttonProps = {
    text: string;
    selected?: boolean;
    onPress: () => void;
    style?: StyleProp<ViewStyle>;
};

export default function Button({ text, selected = false, onPress, style, }: buttonProps) {
        return (
            <Pressable
                onPress={onPress}
                style={[
                    styles.base,
                    selected && styles.selected,
                    style,
                ]}
            >
                <Text style={[styles.label, selected && styles.labelSelected]}>
                    {text}
                </Text>
            </Pressable>
        );
}

const styles = StyleSheet.create({
    base: {
        //width: 320,
        width: "100%",
        height: 50,
        //flex: 1,
        //alignSelf: "flex-start",
        padding: 3,
        borderWidth: 2,
        borderColor: '#E6E6E6',// default border
        borderRadius: 12,
        backgroundColor: '#fff',
        alignItems: 'center',
        justifyContent: 'center',
    },
    selected: {
        borderColor: '#0078C1',
        borderWidth: 2,
    },
    button: {
        borderRadius: 10,
        width: '100%',
        height: '100%',
        alignItems: 'center',
        justifyContent: 'center',
        flexDirection: 'row',
        backgroundColor: '#fff'
    },
    label: {
        color: '#000000',
        fontSize: 16,
    },
    labelSelected: {
        color: '#0078C1',
    },
});
