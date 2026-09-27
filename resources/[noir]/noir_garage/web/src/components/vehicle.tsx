import { Bike, Car, Plane, Ship } from "lucide-react";
import { VehicleProps, formatMoney } from "../utils/interface";

export type Tone = 'success' | 'warning' | 'danger' | 'info' | 'neutral';

/** Estado do carro em texto + tom semantico (o texto sempre acompanha a cor). */
export const vehicleStatus = (vehicle: VehicleProps, isDepot: boolean): { label: string; tone: Tone } => {
  if (vehicle.state === 2) return { label: 'Apreendido', tone: 'danger' };
  if (vehicle.state === 1) return { label: 'Na garagem', tone: 'success' };
  if (isDepot && vehicle.canTakeOut) {
    return { label: vehicle.depotPrice > 0 ? `No pátio · $${formatMoney(vehicle.depotPrice)}` : 'No pátio', tone: 'info' };
  }
  return { label: 'Na rua', tone: 'warning' };
};

export const VehicleIcon: React.FC<{ icon: VehicleProps['icon']; size?: number }> = ({ icon, size = 20 }) => {
  const props = { size, strokeWidth: 1.75, 'aria-hidden': true } as const;
  switch (icon) {
    case 'motorcycle':
    case 'bicycle':
      return <Bike {...props} />;
    case 'boat':
      return <Ship {...props} />;
    case 'plane':
    case 'helicopter':
      return <Plane {...props} />;
    default:
      return <Car {...props} />;
  }
};
