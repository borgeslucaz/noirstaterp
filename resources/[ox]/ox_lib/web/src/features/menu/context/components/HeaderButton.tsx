import { IconProp } from '@fortawesome/fontawesome-svg-core';
import LibIcon from '../../../../components/LibIcon';

interface Props {
  icon: IconProp;
  label: string;
  canClose?: boolean;
  handleClick: () => void;
}

const HeaderButton: React.FC<Props> = ({ icon, label, canClose, handleClick }) => (
  <button
    type="button"
    className="side-menu__icon-button"
    aria-label={label}
    disabled={canClose === false}
    onClick={handleClick}
  >
    <LibIcon icon={icon} fixedWidth />
  </button>
);

export default HeaderButton;
