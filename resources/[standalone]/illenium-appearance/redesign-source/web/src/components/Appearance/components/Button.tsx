import { ReactNode } from 'react';
import './Button.css';

interface ButtonProps {
  children: string | ReactNode;
  margin?: string;
  width?: string;
  onClick: () => void;
}

const Button = ({ children, onClick, margin, width }: ButtonProps) => {
  return (
    <span 
      className="custom-button" 
      onClick={onClick} 
      style={{ margin: margin || "0px", width: width || "auto" }}
    >
      {children}
    </span>
  );
};

export default Button;
