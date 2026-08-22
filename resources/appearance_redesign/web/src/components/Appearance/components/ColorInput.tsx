import { useCallback } from 'react';
import './ColorInput.css';

interface ColorInputProps {
  title?: string;
  colors?: number[][];
  defaultValue?: number;
  clientValue?: number;
  onChange: (value: number) => void;
}

const ColorInput: React.FC<ColorInputProps> = ({ title, colors = [], defaultValue, clientValue, onChange }) => {
  const selectColor = useCallback(
    (color: number) => {
      onChange(color);
    },
    [onChange],
  );

  return (
    <div className="color-input-container">
      <span>
        <small>{`${title}: ${defaultValue}`}</small>
        <small>{clientValue}</small>
      </span>
      <div>
        {colors.map((color, index) => (
          <button
            key={index}
            className={`color-input-button ${defaultValue === index ? 'selected' : ''}`}
            onClick={() => selectColor(index)}
          >
            <span 
              className="color-input-button-inner"
              style={{ backgroundColor: `rgb(${color[0]}, ${color[1]}, ${color[2]})` }}
            />
          </button>
        ))}
      </div>
    </div>
  );
};

export default ColorInput;
