import { IconProp } from '@fortawesome/fontawesome-svg-core';
import { Box, createStyles } from '@mantine/core';
import { useEffect, useState } from 'react';
import LibIcon from '../../../components/LibIcon';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { useLocales } from '../../../providers/LocaleProvider';
import ScaleFade from '../../../transitions/ScaleFade';
import type { RadialMenuItem } from '../../../typings';
import { fetchNui } from '../../../utils/fetchNui';
import { isIconUrl } from '../../../utils/isIconUrl';

// Fatias separadas (vão de largura constante entre elas) e afastadas do botão central.
const SECTOR_GAP = 6;
const OUTER_RADIUS = 175;
const INNER_RADIUS = 40;

const useStyles = createStyles(() => ({
  wrapper: {
    position: 'absolute',
    top: '50%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
  },
  // DESIGN_v4: disco escuro, fatia sob o mouse em branco com texto escuro, centro branco.
  // No hover o branco cresce do centro para a borda (círculo de recorte que aumenta); texto e ícone
  // escurecem quando o branco chega neles.
  sector: {
    fill: 'rgba(12, 14, 18, 0.88)',

    '> clipPath > circle': {
      r: INNER_RADIUS,
      transition: 'r 160ms cubic-bezier(0.4, 0, 1, 1)',
    },
    '> .radial-fill': {
      fill: 'var(--noir-selected)',
    },

    '&:hover': {
      cursor: 'pointer',
      '> clipPath > circle': {
        r: OUTER_RADIUS,
        transition: 'r 320ms cubic-bezier(0.33, 1, 0.68, 1)',
      },
      '> g > text, > g > svg > path': {
        fill: 'var(--noir-on-light)',
        transition: 'fill 90ms 110ms',
      },
    },
    '> g > text': {
      transition: 'fill 90ms',
      fill: 'var(--noir-text-strong)',
      strokeWidth: 0,
      fontFamily: 'var(--font-display)',
      fontWeight: 500,
      letterSpacing: '0.02em',
      textTransform: 'uppercase',
    },
    '> g > svg > path': {
      transition: 'fill 90ms',
      fill: 'rgba(255, 255, 255, 0.82)',
    },
  },
  centerCircle: {
    fill: 'var(--noir-selected)',
    transition: 'fill 120ms',
    '&:hover': {
      cursor: 'pointer',
      fill: 'rgba(242, 242, 242, 0.82)',
    },
  },
  centerIconContainer: {
    position: 'absolute',
    display: 'flex',
    top: '50%',
    left: '50%',
    // +1 px para baixo e para a direita: centrado na conta, o X parecia fora; ajuste ótico pedido no teste.
    transform: 'translate(calc(-50% + 1px), calc(-50% + 1px))',
    pointerEvents: 'none',
  },
  centerIcon: {
    color: 'var(--noir-on-light)',
  },
}));

const calculateFontSize = (text: string): number => {
  if (text.length > 20) return 12;
  if (text.length > 15) return 13;
  return 15;
};

const splitTextIntoLines = (text: string, maxCharPerLine: number = 15): string[] => {
  const words = text.split(' ');
  const lines: string[] = [];
  let currentLine = words[0];

  for (let i = 1; i < words.length; i++) {
    if (currentLine.length + words[i].length + 1 <= maxCharPerLine) {
      currentLine += ' ' + words[i];
    } else {
      lines.push(currentLine);
      currentLine = words[i];
    }
  }
  lines.push(currentLine);
  return lines;
};

const PAGE_ITEMS = 6;

const degToRad = (deg: number) => deg * (Math.PI / 180);

const sectorPath = (pieAngle: number) => {
  const half = SECTOR_GAP / 2;
  const end = -degToRad(pieAngle);
  const outerTrim = Math.asin(half / OUTER_RADIUS);
  const innerTrim = Math.asin(half / INNER_RADIUS);
  const point = (r: number, a: number) => `${175 + r * Math.cos(a)},${175 + r * Math.sin(a)}`;
  const largeArc = pieAngle > 180 ? 1 : 0;

  return [
    `M${point(OUTER_RADIUS, -outerTrim)}`,
    `A${OUTER_RADIUS},${OUTER_RADIUS} 0 ${largeArc},0 ${point(OUTER_RADIUS, end + outerTrim)}`,
    `L${point(INNER_RADIUS, end + innerTrim)}`,
    `A${INNER_RADIUS},${INNER_RADIUS} 0 ${largeArc},1 ${point(INNER_RADIUS, -innerTrim)}`,
    'Z',
  ].join(' ');
};

const RadialMenu: React.FC = () => {
  const { classes } = useStyles();
  const { locale } = useLocales();
  const newDimension = 350 * 1.1025;
  const [visible, setVisible] = useState(false);
  const [menuItems, setMenuItems] = useState<RadialMenuItem[]>([]);
  const [menu, setMenu] = useState<{ items: RadialMenuItem[]; sub?: boolean; page: number }>({
    items: [],
    sub: false,
    page: 1,
  });

  const changePage = async (increment?: boolean) => {
    setVisible(false);

    const didTransition: boolean = await fetchNui('radialTransition');

    if (!didTransition) return;

    setVisible(true);
    setMenu({ ...menu, page: increment ? menu.page + 1 : menu.page - 1 });
  };

  useEffect(() => {
    if (menu.items.length <= PAGE_ITEMS) return setMenuItems(menu.items);
    const items = menu.items.slice(
      PAGE_ITEMS * (menu.page - 1) - (menu.page - 1),
      PAGE_ITEMS * menu.page - menu.page + 1
    );
    if (PAGE_ITEMS * menu.page - menu.page + 1 < menu.items.length) {
      items[items.length - 1] = { icon: 'ellipsis-h', label: locale.ui.more, isMore: true };
    }
    setMenuItems(items);
  }, [menu.items, menu.page]);

  useNuiEvent('openRadialMenu', async (data: { items: RadialMenuItem[]; sub?: boolean; option?: string } | false) => {
    if (!data) return setVisible(false);
    let initialPage = 1;
    if (data.option) {
      data.items.findIndex(
        (item, index) => item.menu == data.option && (initialPage = Math.floor(index / PAGE_ITEMS) + 1)
      );
    }
    setMenu({ ...data, page: initialPage });
    setVisible(true);
  });

  useNuiEvent('refreshItems', (data: RadialMenuItem[]) => {
    setMenu({ ...menu, items: data });
  });

  return (
    <>
      <Box
        className={classes.wrapper}
        onContextMenu={async () => {
          if (menu.page > 1) await changePage();
          else if (menu.sub) fetchNui('radialBack');
        }}
      >
        <ScaleFade visible={visible}>
          <svg
            style={{ overflow: 'visible', display: 'block' }}
            width={`${newDimension}px`}
            height={`${newDimension}px`}
            viewBox="0 0 350 350"
            transform="rotate(90)"
          >
            {menuItems.map((item, index) => {
              // Sem disco de fundo: cada fatia tem o próprio fundo, então elas dividem o círculo todo.
              const pieAngle = 360 / Math.max(menuItems.length, 2);
              const angle = degToRad(pieAngle / 2 + 90);
              const radius = 175 * 0.65;
              const sinAngle = Math.sin(angle);
              const cosAngle = Math.cos(angle);
              const iconYOffset = splitTextIntoLines(item.label, 15).length > 3 ? 3 : 0;
              const iconX = 175 + sinAngle * radius;
              const iconY = 175 + cosAngle * radius + iconYOffset; // Apply the Y offset to iconY
              const iconWidth = Math.min(Math.max(item.iconWidth || 50, 0), 100);
              const iconHeight = Math.min(Math.max(item.iconHeight || 50, 0), 100);

              return (
                <g
                  transform={`rotate(-${index * pieAngle} 175 175)`}
                  className={classes.sector}
                  onClick={async () => {
                    const clickIndex = menu.page === 1 ? index : PAGE_ITEMS * (menu.page - 1) - (menu.page - 1) + index;
                    if (!item.isMore) fetchNui('radialClick', clickIndex);
                    else {
                      await changePage(true);
                    }
                  }}
                >
                  <path d={sectorPath(pieAngle)} />
                  <clipPath id={`radial-fill-${index}`}>
                    <circle cx={175} cy={175} r={INNER_RADIUS} />
                  </clipPath>
                  <path
                    d={sectorPath(pieAngle)}
                    className="radial-fill"
                    clipPath={`url(#radial-fill-${index})`}
                    pointerEvents="none"
                  />
                  <g transform={`rotate(${index * pieAngle - 90} ${iconX} ${iconY})`} pointerEvents="none">
                    {typeof item.icon === 'string' && isIconUrl(item.icon) ? (
                      <image
                        href={item.icon}
                        width={iconWidth}
                        height={iconHeight}
                        x={iconX - iconWidth / 2}
                        y={iconY - iconHeight / 2 - iconHeight / 4}
                      />
                    ) : (
                      <LibIcon
                        x={iconX - 14.5}
                        y={iconY - 17.5}
                        icon={item.icon as IconProp}
                        width={30}
                        height={30}
                        fixedWidth
                      />
                    )}
                    <text
                      x={iconX}
                      y={iconY + (splitTextIntoLines(item.label, 15).length > 2 ? 15 : 28)}
                      fill="var(--noir-text-strong)"
                      textAnchor="middle"
                      fontSize={calculateFontSize(item.label)}
                      pointerEvents="none"
                      lengthAdjust="spacingAndGlyphs"
                    >
                      {splitTextIntoLines(item.label, 15).map((line, index) => (
                        <tspan x={iconX} dy={index === 0 ? 0 : '1.2em'} key={index}>
                          {line}
                        </tspan>
                      ))}
                    </text>
                  </g>
                </g>
              );
            })}
            <g
              transform={`translate(175, 175)`}
              onClick={async () => {
                if (menu.page > 1) await changePage();
                else {
                  if (menu.sub) fetchNui('radialBack');
                  else {
                    setVisible(false);
                    fetchNui('radialClose');
                  }
                }
              }}
            >
              <circle r={28} className={classes.centerCircle} />
            </g>
          </svg>
          <div className={classes.centerIconContainer}>
            <LibIcon
              icon={!menu.sub && menu.page < 2 ? 'xmark' : 'arrow-rotate-left'}
              fixedWidth
              className={classes.centerIcon}
              size="xl"
            />
          </div>
        </ScaleFade>
      </Box>
    </>
  );
};

export default RadialMenu;
