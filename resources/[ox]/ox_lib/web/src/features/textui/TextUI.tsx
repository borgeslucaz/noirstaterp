import { Box, createStyles } from '@mantine/core';
import React from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import MarkdownComponents from '../../config/MarkdownComponents';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import ScaleFade from '../../transitions/ScaleFade';
import type { TextUiPosition, TextUiProps } from '../../typings';

const useStyles = createStyles((theme, params: { position?: TextUiPosition; hasKey: boolean }) => ({
  wrapper: {
    height: '100%',
    width: '100%',
    position: 'absolute',
    display: 'flex',
    alignItems:
      params.position === 'top-center' ? 'flex-start' : params.position === 'bottom-center' ? 'flex-end' : 'center',
    justifyContent:
      params.position === 'right-center'
        ? 'flex-end'
        : params.position === 'top-center' || params.position === 'bottom-center'
        ? 'center'
        : 'flex-start',
  },
  // Pílula de tecla do DESIGN_v4 (§7): tecla branca, texto em display caixa alta.
  container: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    maxWidth: 420,
    padding: params.hasKey ? '6px 12px 6px 6px' : '6px 12px',
    margin: 0,
    borderRadius: 'var(--noir-radius)',
    backgroundColor: 'rgba(0, 0, 0, 0.72)',
    color: '#fff',
    fontFamily: 'var(--font-display)',
    fontSize: 16,
    fontWeight: 700,
    lineHeight: 1.2,
    letterSpacing: '0.03em',
    textTransform: 'uppercase',
    marginLeft: params.position === 'left-center' ? 16 : 0,
    marginRight: params.position === 'right-center' ? 16 : 0,
    marginTop: params.position === 'top-center' ? 16 : 0,
    marginBottom: params.position === 'bottom-center' ? 16 : 0,
    '& p': { margin: 0 },
  },
  buttonIndicator: {
    minWidth: 26,
    flex: '0 0 auto',
    padding: '2px 7px',
    borderRadius: 'var(--noir-radius)',
    backgroundColor: 'var(--noir-selected)',
    color: 'var(--noir-on-light)',
    fontFamily: 'var(--font-ui)',
    fontSize: 13,
    fontWeight: 700,
    lineHeight: 1.4,
    textAlign: 'center',
  },
}));

const TextUI: React.FC = () => {
  const [data, setData] = React.useState<TextUiProps>({
    text: '',
    key: '',
    position: 'left-center',
  });
  const [visible, setVisible] = React.useState(false);
  const { classes } = useStyles({ position: data.position, hasKey: !!data.key });

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
            {data.key && <div className={classes.buttonIndicator}>{data.key}</div>}
            <ReactMarkdown components={MarkdownComponents} remarkPlugins={[remarkGfm]}>
              {data.text}
            </ReactMarkdown>
          </Box>
        </ScaleFade>
      </Box>
    </>
  );
};

export default TextUI;
