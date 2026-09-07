import React, { useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryControl from './InventoryControl';
import InventoryHotbar from './InventoryHotbar';
import { useAppDispatch } from '../../store';
import {
	refreshSlots,
	setAdditionalMetadata,
	setItemAmount,
	setupInventory,
} from '../../store/inventory';
import { useExitListener } from '../../hooks/useExitListener';
import type { Inventory as InventoryProps } from '../../typings';
import RightInventory from './RightInventory';
import LeftInventory from './LeftInventory';
import Tooltip from '../utils/Tooltip';
import { closeTooltip } from '../../store/tooltip';
import InventoryContext from './InventoryContext';
import { closeContextMenu } from '../../store/contextMenu';
import Fade from '../utils/transitions/Fade';
import { Locale } from '../../store/locale';
import { fetchNui } from '../../utils/fetchNui';

const Inventory: React.FC = () => {
	const [inventoryVisible, setInventoryVisible] = useState(false);
	const dispatch = useAppDispatch();

  useNuiEvent<boolean>('setInventoryVisible', setInventoryVisible);
  useNuiEvent<false>('closeInventory', () => {
    setInventoryVisible(false);
    dispatch(setItemAmount(0));
    dispatch(closeContextMenu());
    dispatch(closeTooltip());
  });
  useExitListener(setInventoryVisible);

	useNuiEvent<{
		leftInventory?: InventoryProps;
		rightInventory?: InventoryProps;
	}>('setupInventory', (data) => {
		dispatch(setupInventory(data));
		!inventoryVisible && setInventoryVisible(true);
	});

  useNuiEvent('refreshSlots', (data) => dispatch(refreshSlots(data)));

  useNuiEvent('displayMetadata', (data: Array<{ metadata: string; value: string }>) => {
    dispatch(setAdditionalMetadata(data));
  });

	return (
		<>
			<Fade in={inventoryVisible}>
				<div className="inventory-wrapper">
					<div className="inventory-stage layout-slots">
						<div className="inventory-side left">
							<LeftInventory />
						</div>

						<div className="inventory-centre">
							<InventoryControl />
						</div>

						<div className="inventory-side right">
							<RightInventory />
						</div>
					</div>

					<div className="inventory-chrome">
						<button className="inventory-close" type="button" onClick={() => fetchNui('exit')}>
              <span className="inventory-close-label">{Locale.ui_closeInv || 'Close Inventory'}</span>
              <span className="inventory-close-key">{Locale.ui_esc || 'ESC'}</span>
            </button>
          </div>

          <Tooltip />
					<InventoryContext />
				</div>
			</Fade>
			<InventoryHotbar />
    </>
  );
};

export default Inventory;
