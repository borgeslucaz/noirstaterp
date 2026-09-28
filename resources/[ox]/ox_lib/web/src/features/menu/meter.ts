// colorScheme do Lua (nomes do Mantine) vira tom semântico da v4; sem colorScheme a barra é neutra.
const schemes: Record<string, string> = {
  green: 'success',
  teal: 'success',
  lime: 'success',
  yellow: 'warning',
  orange: 'warning',
  red: 'danger',
  pink: 'danger',
  blue: 'info',
  cyan: 'info',
  indigo: 'info',
};

export const meterTone = (colorScheme?: string) => (colorScheme ? schemes[colorScheme] : undefined);
