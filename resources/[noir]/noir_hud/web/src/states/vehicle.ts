import { atom, useAtom, useAtomValue, useSetAtom } from "jotai";
import { isDevPreview } from "@/utils/misc";

export interface VehicleStateInterface {
    speed: number;
    rpm: number;
    engineState: boolean;
    engineHealth: number;
    gears: number;
    currentGear: string;
    fuel: number;
    nos: number;
    speedUnit: "MPH" | "KPH" | "mph" | "kph";
    headlights: number;
}

const mockVehicleState: VehicleStateInterface = {
    speed: 86,
    rpm: 50,
    engineState: true,
    engineHealth: 50,
    gears: 6,
    currentGear: "3",
    fuel: 50,
    nos: 40,
    speedUnit: "kph",
    headlights: 50
};

const vehicleState = atom<VehicleStateInterface>(isDevPreview() ? mockVehicleState : {
    speed: 0, rpm: 0, engineState: false, engineHealth: 0, gears: 0,
    currentGear: "", fuel: 0, nos: 0, speedUnit: "kph", headlights: 0,
});

export const useVehicleState = () => useAtomValue(vehicleState);
export const useSetVehicleState = () => useSetAtom(vehicleState);
export const useVehicleStateStore = () => useAtom(vehicleState);
