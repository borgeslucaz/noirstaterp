import { IconProp } from '@fortawesome/fontawesome-svg-core';
import { HoverCard } from '@mantine/core';
import ReactMarkdown from 'react-markdown';
import LibIcon from '../../../../components/LibIcon';
import MarkdownComponents from '../../../../config/MarkdownComponents';
import { ContextMenuProps, Option } from '../../../../typings';
import { fetchNui } from '../../../../utils/fetchNui';
import { isIconUrl } from '../../../../utils/isIconUrl';
import { meterTone } from '../../meter';

const openMenu = (id: string | undefined) => {
  fetchNui<ContextMenuProps>('openContext', { id: id, back: false });
};

const clickContext = (id: string) => {
  fetchNui('clickContext', id);
};

type MetadataEntry = string | { label: string; value?: any; progress?: number; colorScheme?: string };

const Meter: React.FC<{ value: number; colorScheme?: string }> = ({ value, colorScheme }) => (
  <span className="side-menu-item__progress" data-meter={meterTone(colorScheme)}>
    <span style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
  </span>
);

const MetadataCard: React.FC<{ button: Option }> = ({ button }) => (
  <div className="side-menu-card">
    {button.image && <img src={button.image} alt="" />}
    {Array.isArray(button.metadata)
      ? (button.metadata as MetadataEntry[]).map((metadata, index) =>
          typeof metadata === 'string' ? (
            <div key={`context-metadata-${index}`}>{metadata}</div>
          ) : (
            <div key={`context-metadata-${index}`}>
              <div className="side-menu-card__row">
                <span>{metadata.label}</span>
                {metadata.value !== undefined && <span className="side-menu-card__value">{metadata.value}</span>}
              </div>
              {metadata.progress !== undefined && (
                <Meter value={metadata.progress} colorScheme={metadata.colorScheme} />
              )}
            </div>
          )
        )
      : typeof button.metadata === 'object' &&
        Object.entries(button.metadata).map(([label, value], index) => (
          <div className="side-menu-card__row" key={`context-metadata-${index}`}>
            <span>{label}</span>
            <span className="side-menu-card__value">{String(value)}</span>
          </div>
        ))}
  </div>
);

const ContextButton: React.FC<{
  option: [string, Option];
  iconColumn: boolean;
}> = ({ option, iconColumn }) => {
  const button = option[1];
  const buttonKey = option[0];
  const clickable = !button.disabled && !button.readOnly;
  const hasTitle = button.title || Number.isNaN(+buttonKey);

  const handleClick = () => {
    if (!clickable) return;
    if (button.menu) openMenu(button.menu);
    else clickContext(buttonKey);
  };

  return (
    <HoverCard
      position="left-start"
      offset={12}
      withinPortal
      disabled={button.disabled || !(button.metadata || button.image)}
      openDelay={200}
      styles={{ dropdown: { padding: 0, background: 'transparent', border: 0 } }}
    >
      <HoverCard.Target>
        <div
          role="button"
          className="side-menu-item"
          data-icon={iconColumn ? '' : undefined}
          data-clickable={clickable ? '' : undefined}
          aria-disabled={button.disabled || undefined}
          onClick={handleClick}
        >
          {iconColumn && (
            <span className="side-menu-item__icon">
              {!button.icon ? null : typeof button.icon === 'string' && isIconUrl(button.icon) ? (
                <img src={button.icon} alt="" />
              ) : (
                <LibIcon
                  icon={button.icon as IconProp}
                  fixedWidth
                  style={{ color: button.iconColor }}
                  animation={button.iconAnimation}
                />
              )}
            </span>
          )}
          <span className="side-menu-item__body">
            {hasTitle && (
              <span className="side-menu-item__label" data-wrap="">
                <ReactMarkdown components={MarkdownComponents}>{button.title || buttonKey}</ReactMarkdown>
              </span>
            )}
            {button.description && (
              <span className="side-menu-item__description">
                <ReactMarkdown components={MarkdownComponents}>{button.description}</ReactMarkdown>
              </span>
            )}
            {button.progress !== undefined && <Meter value={button.progress} colorScheme={button.colorScheme} />}
          </span>
          {button.disabled && (
            <span className="side-menu-item__value side-menu-item__lock">
              <LibIcon icon="lock" fixedWidth />
            </span>
          )}
        </div>
      </HoverCard.Target>
      <HoverCard.Dropdown>
        <MetadataCard button={button} />
      </HoverCard.Dropdown>
    </HoverCard>
  );
};

export default ContextButton;
