import { ReactNode } from 'react';
import './Item.css';

interface ItemProps {
  title?: string;
  children?: ReactNode;
  className?: string;
}

const Item: React.FC<ItemProps> = ({ children, title, className }) => {
  return (
    <div className={`item-container ${className || ''}`}>
      {title && <span>{title}</span>}
      <div className="item-inputs">{children}</div>
    </div>
  );
};

export default Item;
