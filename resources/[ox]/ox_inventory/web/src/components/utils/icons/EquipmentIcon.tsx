import React from 'react';

// equipment: icones dos slots de equipamento vazios, pelo nome do slot (modules/equipment/shared.lua)
const paths: Record<string, React.ReactNode> = {
  phone: (
    <>
      <rect x="7" y="2" width="10" height="20" rx="2" />
      <path d="M11 18h2" />
    </>
  ),
  radio: (
    <>
      <rect x="6" y="8" width="12" height="14" rx="2" />
      <path d="M9 8V2M9 12h6M9 15h6" />
      <circle cx="12" cy="18.5" r="1" />
    </>
  ),
  keys: (
    <>
      <circle cx="8" cy="8" r="4.5" />
      <path d="M11.2 11.2 21 21M17 17l2-2M19.5 19.5l1.5-1.5" />
    </>
  ),
  wallet: (
    <>
      <path d="M4 7h14a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h11v3" />
      <path d="M20 11h-4a2 2 0 0 0 0 4h4z" />
    </>
  ),
  backpack: (
    <>
      <path d="M6 10a6 6 0 0 1 12 0v9a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2z" />
      <path d="M9 5.5V4a3 3 0 0 1 6 0v1.5M9 14h6v4H9z" />
    </>
  ),
  mask: (
    <>
      <path d="M4 6c3-2 13-2 16 0v5c0 5-4 9-8 9s-8-4-8-9z" />
      <path d="M7.5 10.5h3M13.5 10.5h3M10 16h4" />
    </>
  ),
  hat: (
    <>
      <path d="M2 17c4 2 16 2 20 0" />
      <path d="M5 16.5 7 7a2 2 0 0 1 2-1.5h6A2 2 0 0 1 17 7l2 9.5" />
      <path d="M6 13c4 1 8 1 12 0" />
    </>
  ),
  glasses: (
    <>
      <circle cx="6.5" cy="14" r="3.5" />
      <circle cx="17.5" cy="14" r="3.5" />
      <path d="M10 14h4M3 14 4.5 8M21 14l-1.5-6" />
    </>
  ),
  jacket: (
    <>
      <path d="M8 3 3 6v14h5l1-9M16 3l5 3v14h-5l-1-9" />
      <path d="M8 3l4 5 4-5M12 8v13M9 21h6" />
    </>
  ),
  pants: <path d="M7 3h10l1 18h-4l-2-11-2 11H6zM7 6h10" />,
  shoes: (
    <>
      <path d="M3 17v-7l5 1 3 3 8 2a2 2 0 0 1 2 2v2H3z" />
      <path d="M3 19h18M9 13l-1 2M12 14.5 11 16.5" />
    </>
  ),
  bag: (
    <>
      <path d="M5 9h14l-1 11H6z" />
      <path d="M9 9V7a3 3 0 0 1 6 0v2" />
    </>
  ),
  vest: <path d="M8 3 4 6v14h6v-6h4v6h6V6l-4-3-2 4h-4zM12 7v7" />,
  watch: (
    <>
      <circle cx="12" cy="12" r="5" />
      <path d="M9 7.5 9.5 3h5l.5 4.5M9 16.5l.5 4.5h5l.5-4.5M12 10v2l1.5 1" />
    </>
  ),
  necklace: (
    <>
      <path d="M6 3c0 7 3 11 6 11s6-4 6-11" />
      <path d="M12 14v1" />
      <circle cx="12" cy="17.5" r="2.5" />
    </>
  ),
};

const EquipmentIcon: React.FC<{ name: string }> = ({ name }) => (
  <svg
    className="equipment-icon"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={1.5}
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    {paths[name] ?? <rect x="4" y="4" width="16" height="16" rx="3" />}
  </svg>
);

export default EquipmentIcon;
