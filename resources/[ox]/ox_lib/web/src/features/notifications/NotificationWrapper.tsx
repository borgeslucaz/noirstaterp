import { Box, keyframes } from '@mantine/core';
import React, { useState } from 'react';
import { toast, Toaster } from 'react-hot-toast';
import ReactMarkdown from 'react-markdown';
import tinycolor from 'tinycolor2';
import LibIcon from '../../components/LibIcon';
import MarkdownComponents from '../../config/MarkdownComponents';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import type { NotificationProps } from '../../typings';

import './notifications.css';

const createAnimation = (from: string, to: string, visible: boolean) =>
  keyframes({
    from: {
      opacity: visible ? 0 : 1,
      transform: `translate${from}`,
    },
    to: {
      opacity: visible ? 1 : 0,
      transform: `translate${to}`,
    },
  });

const getAnimation = (visible: boolean, position: string) => {
  const animationOptions = visible ? '0.2s ease-out forwards' : '0.4s ease-in forwards';
  let animation: { from: string; to: string };

  if (visible) {
    animation = position.includes('bottom') ? { from: 'Y(30px)', to: 'Y(0px)' } : { from: 'Y(-30px)', to: 'Y(0px)' };
  } else {
    if (position.includes('right')) {
      animation = { from: 'X(0px)', to: 'X(100%)' };
    } else if (position.includes('left')) {
      animation = { from: 'X(0px)', to: 'X(-100%)' };
    } else if (position === 'top-center') {
      animation = { from: 'Y(0px)', to: 'Y(-100%)' };
    } else if (position === 'bottom') {
      animation = { from: 'Y(0px)', to: 'Y(100%)' };
    } else {
      animation = { from: 'X(0px)', to: 'X(100%)' };
    }
  }

  return `${createAnimation(animation.from, animation.to, visible)} ${animationOptions}`;
};

const durationBar = keyframes({
  from: { transform: 'scaleX(1)' },
  to: { transform: 'scaleX(0)' },
});

const Notifications: React.FC = () => {
  const [toastKey, setToastKey] = useState(0);

  useNuiEvent<NotificationProps>('notify', (data) => {
    if (!data.title && !data.description) return;

    const toastId = data.id?.toString();
    const duration = data.duration || 3000;

    let iconColor: string;
    const position =
      data.position === 'top'
        ? 'top-center'
        : data.position === 'bottom'
        ? 'bottom-center'
        : data.position || 'top-center';

    data.showDuration = data.showDuration !== undefined ? data.showDuration : true;

    if (toastId) setToastKey((prevKey) => prevKey + 1);

    if (!data.icon) {
      switch (data.type) {
        case 'error':
          data.icon = 'circle-xmark';
          break;
        case 'success':
          data.icon = 'circle-check';
          break;
        case 'warning':
          data.icon = 'circle-exclamation';
          break;
        default:
          data.icon = 'circle-info';
          break;
      }
    }

    if (!data.iconColor) {
      switch (data.type) {
        case 'error':
          iconColor = 'var(--noir-danger-hover)';
          break;
        case 'success':
          iconColor = 'var(--noir-success)';
          break;
        case 'warning':
          iconColor = 'var(--noir-warning)';
          break;
        default:
          iconColor = 'var(--noir-info)';
          break;
      }
    } else {
      iconColor = tinycolor(data.iconColor).toRgbString();
    }

    toast.custom(
      (t) => (
        <Box
          sx={{
            animation: getAnimation(t.visible, position),
            ...data.style,
          }}
          className="notify"
          style={{ '--notify-color': iconColor } as React.CSSProperties}
          data-align={data.alignIcon === 'top' ? 'top' : undefined}
        >
          {data.icon && (
            <span className="notify__icon">
              <LibIcon icon={data.icon} fixedWidth animation={data.iconAnimation} />
            </span>
          )}
          <div className="notify__text">
            {data.title && <div className="notify__title">{data.title}</div>}
            {data.description && (
              <ReactMarkdown components={MarkdownComponents} className="notify__description description">
                {data.description}
              </ReactMarkdown>
            )}
          </div>
          {data.showDuration && (
            <Box
              key={toastKey}
              className="notify__duration"
              sx={{ animation: `${durationBar} ${duration}ms linear forwards` }}
            />
          )}
        </Box>
      ),
      {
        id: toastId,
        duration: duration,
        position: position,
      }
    );
  });

  return <Toaster />;
};

export default Notifications;
