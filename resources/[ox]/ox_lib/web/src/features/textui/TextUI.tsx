import { Box, createStyles, Group } from '@mantine/core';
import React from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import MarkdownComponents from '../../config/MarkdownComponents';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import ScaleFade from '../../transitions/ScaleFade';
import type { TextUiPosition, TextUiProps } from '../../typings';

const useStyles = createStyles((theme, params: { position?: TextUiPosition }) => ({
  wrapper: {
    height: '100%',
    width: '100%',
    position: 'absolute',
    display: 'flex',
    alignItems:
      params.position === 'top-center'
        ? 'flex-start'
        : params.position === 'bottom-center'
        ? 'flex-end'
        : 'center',
    justifyContent:
      params.position === 'right-center'
        ? 'flex-end'
        : params.position === 'top-center' || params.position === 'bottom-center'
        ? 'center'
        : 'flex-start',
  },
  container: {
    fontSize: 16,
    padding: 8,
    margin: 0,
    backgroundColor: 'var(--noir-panel)',
    color: 'var(--noir-text-strong)',
    fontFamily: 'Albert Sans',
    borderRadius: 'var(--noir-radius)',
    border: '1px solid var(--noir-panel-border)',
    fontWeight: 500,
    marginLeft: params.position === 'left-center' ? 16 : 0,
    marginRight: params.position === 'right-center' ? 16 : 0,
    marginTop: params.position === 'top-center' ? 16 : 0,
    marginBottom: params.position === 'bottom-center' ? 16 : 0,
  },
  buttonIndicator: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 'var(--noir-radius)',
    padding: '2px 8px',
    border: `1px solid var(--noir-border)`,
    backgroundColor: 'var(--noir-panel)',
    color: 'var(--noir-text-strong)',
    boxShadow: '0 1px 4px rgba(0, 0, 0, 0.50)',
    fontWeight: 800,
    fontSize: 16,
  },
}));

const TextUI: React.FC = () => {
  const [data, setData] = React.useState<TextUiProps>({
    text: '',
    key: '',
    position: 'left-center',
  });
  const [visible, setVisible] = React.useState(false);
  const { classes } = useStyles({ position: data.position });

  useNuiEvent<TextUiProps>('textUi', (data) => {
    setData({ ...data, position: data.position || 'left-center' });
    setVisible(true);
  });

  useNuiEvent('textUiHide', () => setVisible(false));

  return (
    <>
      <Box className={classes.wrapper}>
        <ScaleFade visible={visible}>
          <Box style={data.style} className={classes.container}>
            <Group spacing={12}>
              {/* {data.icon && (
                <LibIcon
                  icon={data.icon}
                  fixedWidth
                  size="lg"
                  animation={data.iconAnimation}
                  style={{
                    color: data.iconColor,
                    alignSelf: !data.alignIcon || data.alignIcon === 'center' ? 'center' : 'start',
                  }}
                />
              )} */}
              <div className={classes.buttonIndicator}>{data.key}</div>
              <ReactMarkdown components={MarkdownComponents} remarkPlugins={[remarkGfm]}>
                {data.text}
              </ReactMarkdown>
            </Group>
          </Box>
        </ScaleFade>
      </Box>
    </>
  );
};

export default TextUI;
