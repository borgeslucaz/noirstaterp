import { Box, createStyles } from '@mantine/core';
import React, { useEffect, useState } from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import ScaleFade from '../../transitions/ScaleFade';
import type { ProgressbarProps } from '../../typings';
import { fetchNui } from '../../utils/fetchNui';
import './progress.css';

const useStyles = createStyles(() => ({
  wrapper: {
    width: '100%',
    height: '20%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    bottom: 0,
    position: 'absolute',
  },
}));

const Progressbar: React.FC = () => {
  const { classes } = useStyles();
  const [visible, setVisible] = React.useState(false);
  const [label, setLabel] = React.useState('');
  const [duration, setDuration] = React.useState(0);
  const [startedAt, setStartedAt] = React.useState(0);
  const [percent, setPercent] = useState(0);

  useNuiEvent('progressCancel', () => setVisible(false));

  useNuiEvent<ProgressbarProps>('progress', (data) => {
    setVisible(true);
    setLabel(data.label);
    setDuration(data.duration);
    setStartedAt(performance.now());
    setPercent(0);
  });

  // Só o número: quem encerra a barra continua sendo o fim da animação CSS.
  useEffect(() => {
    if (!visible || !duration) return;
    let frame = requestAnimationFrame(function tick(now) {
      setPercent(Math.min(100, Math.floor(((now - startedAt) / duration) * 100)));
      frame = requestAnimationFrame(tick);
    });
    return () => cancelAnimationFrame(frame);
  }, [visible, duration, startedAt]);

  return (
    <Box className={classes.wrapper}>
      <ScaleFade visible={visible} onExitComplete={() => fetchNui('progressComplete')}>
        <div className="progress-panel">
          <div className="progress-panel__head">
            <span className="progress-panel__label">{label}</span>
            <span className="progress-panel__value">{percent}%</span>
          </div>
          <div className="progress-panel__track">
            <Box
              className="progress-panel__bar"
              onAnimationEnd={() => setVisible(false)}
              sx={{
                animation: 'progress-bar linear',
                animationDuration: `${duration}ms`,
              }}
            />
          </div>
        </div>
      </ScaleFade>
    </Box>
  );
};

export default Progressbar;
