import { useEffect, useRef } from 'react';
import { noop } from '../utils/misc';
import { fetchNui } from '../utils/fetchNui';
import { closeTooltip } from '../store/tooltip';
import { useAppDispatch } from '../store';
import { closeContextMenu } from '../store/contextMenu';

type FrameVisibleSetter = (bool: boolean) => void;

// Basic hook to listen for key presses in NUI in order to exit
export const useExitListener = (visibleSetter: FrameVisibleSetter) => {
  const setterRef = useRef<FrameVisibleSetter>(noop);
  const dispatch = useAppDispatch();

  useEffect(() => {
    setterRef.current = visibleSetter;
  }, [visibleSetter]);

  useEffect(() => {
    const closeInventory = () => {
      setterRef.current(false);
      dispatch(closeTooltip());
      dispatch(closeContextMenu());
      fetchNui('exit');
    };

    const keyUpHandler = (e: KeyboardEvent) => {
      if (e.code === 'Escape') closeInventory();
    };

    const keyDownHandler = (e: KeyboardEvent) => {
      if (e.code === 'Tab' && !e.repeat) closeInventory();
    };

    window.addEventListener('keyup', keyUpHandler);
    window.addEventListener('keydown', keyDownHandler);

    return () => {
      window.removeEventListener('keyup', keyUpHandler);
      window.removeEventListener('keydown', keyDownHandler);
    };
  }, []);
};
