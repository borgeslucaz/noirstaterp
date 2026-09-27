import React from "react";
import { Badge } from "@mantine/core";
import { VehicleProps, formatMoney } from "../utils/interface";

const stateBadge = (vehicle: VehicleProps, isDepot?: boolean) => {
    if (vehicle.state === 2) return { label: 'Apreendido', color: 'red' };
    if (vehicle.state === 1) return { label: 'Na garagem', color: 'green' };
    if (isDepot && vehicle.canTakeOut) return { label: `Pátio $${formatMoney(vehicle.depotPrice)}`, color: 'yellow' };
    return { label: 'Na rua', color: 'orange' };
};

const VehicleBadges: React.FC<{
    vehicle: VehicleProps;
    isDepot?: boolean;
    size?: string;
}> = ({ vehicle, isDepot, size = 'sm' }) => {
    const status = stateBadge(vehicle, isDepot);

    return (
        <>
            <Badge variant="light" color="blue" size={size}>{vehicle.plate}</Badge>
            <Badge variant="light" color={status.color} size={size}>{status.label}</Badge>
        </>
    );
};

export default VehicleBadges;
