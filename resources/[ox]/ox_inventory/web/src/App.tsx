import InventoryComponent from './components/inventory';
import useNuiEvent from './hooks/useNuiEvent';
import { Items } from './store/items';
import { Locale } from './store/locale';
import { setImagePath } from './store/imagepath';
import { EquipmentSlotDef, setEquipment } from './store/equipment';
import { setupInventory } from './store/inventory';
import { Inventory } from './typings';
import { useAppDispatch } from './store';
import { debugData } from './utils/debugData';
import DragPreview from './components/utils/DragPreview';
import { fetchNui } from './utils/fetchNui';
import { useDragDropManager } from 'react-dnd';
import KeyPress from './components/utils/KeyPress';

// Dados de teste para abrir a NUI no navegador (npm start).
const debugItem = (name: string, label: string, weight: number, rarity?: string, stack = false) => ({
  name,
  label,
  stack,
  usable: true,
  close: false,
  count: 0,
  rarity,
});

debugData([
  {
    action: 'init',
    data: {
      locale: {},
      imagepath: '/images',
      items: Object.fromEntries(
        [
          debugItem('phone_black', 'Celular', 190, 'uncommon'),
          debugItem('radio', 'Rádio', 1000, 'uncommon'),
          debugItem('vehiclekey', 'Chave de veículo', 50),
          debugItem('wallet', 'Carteira', 100),
          debugItem('backpack_large', 'Mochila grande', 2000, 'rare'),
          debugItem('duffel_bag', 'Duffel Bag', 3000, 'epic'),
          debugItem('water', 'Água', 500, 'common', true),
          debugItem('lockpick', 'Lockpick', 150, 'common', true),
          debugItem('bandage', 'Bandagem', 100, 'common', true),
          debugItem('id_card', 'Identidade', 0),
          debugItem('money', 'Dinheiro', 0, 'common', true),
          debugItem('clothing_hat', 'Chapéu', 100),
          debugItem('screwdriverset', 'Chaves de fenda', 300, 'uncommon', true),
          debugItem('weapon_pistol', 'Pistola', 1000, 'rare'),
        ].map((item) => [item.name, item])
      ),
      equipment: [
        ['mask', 'Máscara', 1001],
        ['hat', 'Chapéu', 1002],
        ['glasses', 'Óculos', 1003],
        ['necklace', 'Colar', 1010],
        ['jacket', 'Jaqueta', 1004],
        ['vest', 'Colete', 1008],
        ['bag', 'Bolsa', 1007],
        ['watch', 'Relógio', 1009],
        ['pants', 'Calça', 1005],
        ['shoes', 'Sapatos', 1006],
      ]
        .map(([name, label, slot]): EquipmentSlotDef => ({
          slot: slot as number,
          group: 'clothing',
          name: name as string,
          label: label as string,
          items: [`clothing_${name}`],
          stealable: ['glasses', 'vest', 'watch'].includes(name as string),
        }))
        .concat([
          { slot: 1011, group: 'body', name: 'phone', label: 'Celular', items: ['phone_black'] },
          { slot: 1012, group: 'body', name: 'radio', label: 'Rádio', items: ['radio'] },
          { slot: 1013, group: 'body', name: 'keys', label: 'Chaves', items: ['vehiclekey'] },
          { slot: 1014, group: 'body', name: 'keys', label: 'Chaves', items: ['vehiclekey'] },
          { slot: 1015, group: 'body', name: 'wallet', label: 'Carteira', items: ['wallet'] },
          { slot: 1016, group: 'body', name: 'backpack', label: 'Mochila', items: ['backpack_large', 'duffel_bag'] },
        ]),
      leftInventory: { id: 'player', slots: 20, maxWeight: 24000, items: [] },
    },
  },
]);

debugData([{ action: 'setWorn', data: [1001, 1004, 1005, 1006] }], 1300);

debugData(
  [
    {
      action: 'setupInventory',
      data: {
        leftInventory: {
          id: 'player',
          type: 'player',
          slots: 20,
          label: 'Samuel Black',
          maxWeight: 24000,
          items: [
            { slot: 1, name: 'weapon_pistol', weight: 1000, count: 1, metadata: { durability: 80, ammo: 12 } },
            { slot: 2, name: 'water', weight: 1500, count: 3 },
            { slot: 3, name: 'bandage', weight: 500, count: 5 },
            { slot: 7, name: 'lockpick', weight: 300, count: 2 },
            { slot: 8, name: 'duffel_bag', weight: 3000, count: 1, metadata: { container: 'duf1', size: [40, 70000] } },
            { slot: 12, name: 'money', weight: 0, count: 2350 },
            { slot: 1011, name: 'phone_black', weight: 190, count: 1 },
            { slot: 1012, name: 'radio', weight: 1000, count: 1 },
            { slot: 1013, name: 'vehiclekey', weight: 50, count: 1, metadata: { plate: 'ABC123' } },
            { slot: 1015, name: 'wallet', weight: 150, count: 1, metadata: { container: 'wal1', size: [6, 1000] } },
            { slot: 1016, name: 'backpack_large', weight: 2400, count: 1, metadata: { container: 'bp1', size: [30, 50000] } },
            { slot: 1002, name: 'clothing_hat', weight: 100, count: 1 },
          ],
        },
        rightInventory: {
          id: 'stash_test',
          type: 'stash',
          slots: 20,
          label: 'Baú',
          maxWeight: 100000,
          items: [
            { slot: 1, name: 'water', weight: 2500, count: 5 },
            { slot: 2, name: 'screwdriverset', weight: 300, count: 1 },
          ],
        },
        backpackInventory: {
          id: 'bp1',
          type: 'backpack',
          slots: 30,
          label: 'Mochila grande',
          maxWeight: 50000,
          items: [
            { slot: 1, name: 'lockpick', weight: 150, count: 1 },
            { slot: 2, name: 'screwdriverset', weight: 300, count: 1 },
          ],
        },
      },
    },
  ],
  1200
);

const App: React.FC = () => {
  const dispatch = useAppDispatch();
  const manager = useDragDropManager();

  useNuiEvent<{
    locale: { [key: string]: string };
    items: typeof Items;
    leftInventory: Inventory;
    imagepath: string;
    equipment?: EquipmentSlotDef[];
  }>('init', ({ locale, items, leftInventory, imagepath, equipment }) => {
    for (const name in locale) Locale[name] = locale[name];
    for (const name in items) Items[name] = items[name];

    setImagePath(imagepath);
    setEquipment(equipment);
    dispatch(setupInventory({ leftInventory }));
  });

  fetchNui('uiLoaded', {});

  useNuiEvent('closeInventory', () => {
    manager.dispatch({ type: 'dnd-core/END_DRAG' });
  });

  return (
    <div className="app-wrapper">
      <InventoryComponent />
      <DragPreview />
      <KeyPress />
    </div>
  );
};

addEventListener('dragstart', function (event) {
  event.preventDefault();
});

export default App;
