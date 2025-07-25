export interface FavoriteStop {
    routeId: string;
    routeName: string;
    stopId: string;
    stopName: string;
    direction: string;
    type: string;
}
export interface Favorite {
    id: string;           // uuid or timestamp
    name: string;         // e.g. “home”, “work”
    stops: FavoriteStop[]; // max length 2
}

export interface SimpleDirection {
    id: string;
}

export interface SimpleStop {
    value: string;
    label: string;
}

export interface SimpleTime {
    times: string;
    dest: any;
}

export interface TrainStop {
    value: string;
    label: string;
}

export interface TrainTime {
    times: string;
}