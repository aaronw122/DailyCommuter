import fs from 'fs/promises';
import {createWriteStream} from 'fs';
import {parse} from 'csv-parse/sync';

interface Trip {
    route_id: string;
    trip_id: string;
}

interface StopTime {
    trip_id: string;
    stop_id: string;
    stop_sequence: string;
    stop_headsign: string;
}

interface Stop {
    stop_id: string;
    stop_name: string;
}

interface TrainRoute {
    route_id: string;
    trip_id: string;
    stop_id: string;
    stop_sequence: string;
    stop_headsign: string;
}

interface RouteStopData {
    route_id: string;
    trip_id: string;
    stop_id: string;
    stop_name: string;
    stop_sequence: string;
    stop_headsign: string;
}

interface FinalTrainData {
    route_id: string;
    stop_id: string;
    stop_name: string;
    stop_sequence: string;
    stop_headsign: string;
}

// Define train route colors to remove from stop names
const TRAIN_ROUTE_COLORS = [
    'Red', 'Blue', 'Brown', 'Green', 'Orange', 'Pink', 'Purple', 'Yellow'
];

function cleanStopName(stopName: string): string {
    // Split by hyphen and check if the last part is a train route color
    const parts = stopName.split('-');

    if (parts.length > 1) {
        const lastPart = parts[parts.length - 1].trim();

        // If the last part is a train route color, remove it
        if (TRAIN_ROUTE_COLORS.includes(lastPart)) {
            return parts.slice(0, -1).join('-').trim();
        }
    }

    return stopName;
}

async function main() {
    console.log('Step 1: Reading CSV files...');
    const [tripsCsv, stopTimesCsv, stopsCsv] = await Promise.all([
        fs.readFile('data/raw/trips.txt', 'utf-8'),
        fs.readFile('data/raw/stop_times.txt', 'utf-8'),
        fs.readFile('data/raw/stops.txt', 'utf-8'),
    ]);

    console.log('Step 2: Parsing trips.txt for route_id and trip_id...');
    const trips: Trip[] = parse(tripsCsv, {
        columns: true,
        skip_empty_lines: true,
    }).map((row: any) => ({
        route_id: row.route_id,
        trip_id: row.trip_id,
    }));

    console.log('Step 3: Parsing stop_times.txt...');
    const stopTimes: StopTime[] = parse(stopTimesCsv, {
        columns: true,
        skip_empty_lines: true,
        cast: (value, ctx) =>
            ctx.column === 'stop_sequence' ? Number(value) : value,
    }).map((row: any) => ({
        trip_id: row.trip_id,
        stop_id: row.stop_id,
        stop_sequence: row.stop_sequence,
        stop_headsign: row.stop_headsign || '',
    }));

    console.log('Step 4: Parsing stops.txt for stop_id and stop_name...');
    const stops: Stop[] = parse(stopsCsv, {
        columns: true,
        skip_empty_lines: true,
    }).map((row: any) => ({
        stop_id: row.stop_id,
        stop_name: row.stop_name,
    }));

    console.log('Step 5: Creating trainRoutes.json - joining trips and stop_times on trip_id...');
    const tripsById = new Map(trips.map(t => [t.trip_id, t]));

    // Stream write trainRoutes.json
    const trainRoutesStream = createWriteStream('data/trainRoutes.json');
    trainRoutesStream.write('[\n');

    let trainRoutesCount = 0;
    let isFirstRoute = true;

    for (const st of stopTimes) {
        const trip = tripsById.get(st.trip_id);
        if (trip) {
            const route: TrainRoute = {
                route_id: trip.route_id,
                trip_id: st.trip_id,
                stop_id: st.stop_id,
                stop_sequence: st.stop_sequence,
                stop_headsign: st.stop_headsign,
            };

            if (!isFirstRoute) {
                trainRoutesStream.write(',\n');
            }
            trainRoutesStream.write(JSON.stringify(route, null, 2));
            isFirstRoute = false;
            trainRoutesCount++;
        }
    }

    trainRoutesStream.write('\n]');

    // Wait for stream to finish
    await new Promise<void>((resolve, reject) => {
        // @ts-ignore
        trainRoutesStream.end((err) => {
            if (err) reject(err);
            else resolve();
        });
    });

    console.log(`Created trainRoutes.json with ${trainRoutesCount} records`);

    console.log('Step 6: Removing repetitive stop_ids (keeping unique route-stop combinations)...');

    // Process deduplication without loading the entire file into memory
    const uniqueRouteStops = new Map<string, TrainRoute>();

    // Re-read the data we just wrote
    for (const st of stopTimes) {
        const trip = tripsById.get(st.trip_id);
        if (trip) {
            const route: TrainRoute = {
                route_id: trip.route_id,
                trip_id: st.trip_id,
                stop_id: st.stop_id,
                stop_sequence: st.stop_sequence,
                stop_headsign: st.stop_headsign,
            };

            const uniqueKey = `${route.route_id}-${route.stop_id}`;
            if (!uniqueRouteStops.has(uniqueKey)) {
                uniqueRouteStops.set(uniqueKey, route);
            }
        }
    }

    const cleanedTrainRoutes = Array.from(uniqueRouteStops.values());
    console.log(`Removed ${trainRoutesCount - cleanedTrainRoutes.length} duplicate route-stop combinations`);

    console.log('Step 7: Creating routeStopData.json - joining with stops.txt...');
    const stopsById = new Map(stops.map(s => [s.stop_id, s]));

    // Stream write routeStopData.json
    const routeStopStream = createWriteStream('data/routeStopData.json');
    routeStopStream.write('[\n');

    let routeStopCount = 0;
    let isFirstRouteStop = true;

    for (const route of cleanedTrainRoutes) {
        const stop = stopsById.get(route.stop_id);
        if (stop) {
            const data: RouteStopData = {
                route_id: route.route_id,
                trip_id: route.trip_id,
                stop_id: route.stop_id,
                stop_name: stop.stop_name,
                stop_sequence: route.stop_sequence,
                stop_headsign: route.stop_headsign,
            };

            if (!isFirstRouteStop) {
                routeStopStream.write(',\n');
            }
            routeStopStream.write(JSON.stringify(data, null, 2));
            isFirstRouteStop = false;
            routeStopCount++;
        }
    }

    routeStopStream.write('\n]');

    // Wait for stream to finish
    await new Promise<void>((resolve, reject) => {
        // @ts-ignore
        routeStopStream.end((err) => {
            if (err) reject(err);
            else resolve();
        });
    });

    console.log(`Created routeStopData.json with ${routeStopCount} records`);

    console.log('Step 8: Creating final trainData.json - removing trip_id...');

    // Stream write final trainData.json
    const finalStream = createWriteStream('data/trainData.json');
    finalStream.write('[\n');

    let finalCount = 0;
    let isFirstFinal = true;

    for (const route of cleanedTrainRoutes) {
        const stop = stopsById.get(route.stop_id);
        if (stop) {
            const finalData: FinalTrainData = {
                route_id: route.route_id,
                stop_id: route.stop_id,
                stop_name: stop.stop_name,
                stop_sequence: route.stop_sequence,
                stop_headsign: route.stop_headsign,
            };

            if (!isFirstFinal) {
                finalStream.write(',\n');
            }
            finalStream.write(JSON.stringify(finalData, null, 2));
            isFirstFinal = false;
            finalCount++;
        }
    }

    finalStream.write('\n]');

    // Wait for stream to finish
    await new Promise<void>((resolve, reject) => {
        // @ts-ignore
        finalStream.end((err) => {
            if (err) reject(err);
            else resolve();
        });
    });

    console.log(`Created final trainData.json with ${finalCount} records`);

    console.log('Step 9: Creating cleanTrainData.json - cleaning stop names...');

    // Stream write clean trainData.json
    const cleanStream = createWriteStream('data/cleanTrainData.json');
    cleanStream.write('[\n');

    let cleanCount = 0;
    let isFirstClean = true;
    let cleanedStopCount = 0;

    for (const route of cleanedTrainRoutes) {
        const stop = stopsById.get(route.stop_id);
        if (stop) {
            const originalStopName = stop.stop_name;
            const cleanedStopName = cleanStopName(originalStopName);

            if (originalStopName !== cleanedStopName) {
                cleanedStopCount++;
            }

            const cleanData: FinalTrainData = {
                route_id: route.route_id,
                stop_id: route.stop_id,
                stop_name: cleanedStopName,
                stop_sequence: route.stop_sequence,
                stop_headsign: route.stop_headsign,
            };

            if (!isFirstClean) {
                cleanStream.write(',\n');
            }
            cleanStream.write(JSON.stringify(cleanData, null, 2));
            isFirstClean = false;
            cleanCount++;
        }
    }

    cleanStream.write('\n]');

    // Wait for stream to finish
    await new Promise<void>((resolve, reject) => {
        // @ts-ignore
        cleanStream.end((err) => {
            if (err) reject(err);
            else resolve();
        });
    });

    console.log(`Created cleanTrainData.json with ${cleanCount} records`);
    console.log(`Cleaned ${cleanedStopCount} stop names by removing train route references`);

    console.log('\n=== Summary ===');
    console.log(`Original trips: ${trips.length}`);
    console.log(`Original stop times: ${stopTimes.length}`);
    console.log(`Original stops: ${stops.length}`);
    console.log(`Train routes (after join): ${trainRoutesCount}`);
    console.log(`Unique route-stop combinations: ${cleanedTrainRoutes.length}`);
    console.log(`Final train data: ${finalCount}`);
    console.log(`Clean train data: ${cleanCount}`);
    console.log(`Stop names cleaned: ${cleanedStopCount}`);
    console.log('\nFiles created:');
    console.log('- data/trainRoutes.json');
    console.log('- data/routeStopData.json');
    console.log('- data/trainData.json');
    console.log('- data/cleanTrainData.json');
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});