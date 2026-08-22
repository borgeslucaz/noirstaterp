import { useCallback, useRef } from 'react';
import { FiChevronLeft, FiChevronRight } from 'react-icons/fi';
import './Input.css';

interface InputProps {
  title?: string;
  min?: number;
  max?: number;
  blacklisted?: number[];
  defaultValue: number;
  clientValue: number;
  onChange: (value: number) => void;
}

const Input: React.FC<InputProps> = ({ title, min = 0, max = 255, blacklisted = [], defaultValue, clientValue, onChange }) => {
  const inputRef = useRef<HTMLInputElement>(null);

  const handleContainerClick = useCallback(() => {
    if (inputRef.current) {
      inputRef.current.focus();
    }
  }, [inputRef]);

  const isBlacklisted = function (_value: number, blacklisted: number[]) {
    for (var i = 0; i < blacklisted.length; i++) {
      if (blacklisted[i] == _value) {
        return true
      }
    }
    return false
  }

  const normalize = function (_value: number) {
    if (_value < min) {
      _value = max;
    } else if (_value > max) {
      _value = min;
    }

    return _value;
  }

  const checkBlacklisted = function (_value: number, blacklisted: number[], factor: number, currentValue: number) {
    if(factor === 0) {
      if(!isBlacklisted(_value, blacklisted)) {
        return normalize(_value);
      }
      factor = _value > currentValue ? 1 : -1;
    }

    do {
      _value = normalize(_value + factor);
    } while (isBlacklisted(_value, blacklisted))
    return _value;
  };

  const getSafeValue = useCallback(
    (_value: number, factor: number, currentValue: number) => {
      let safeValue = _value;

      return checkBlacklisted(safeValue, blacklisted, factor, currentValue);
    },
    [blacklisted, min, max],
  );

  const handleChange = useCallback(
    (_value: any, factor: number) => {
      let parsedValue;

      if (!_value && _value !== 0) return;

      if (Number.isNaN(_value)) return;

      if (typeof _value === 'string') {
        parsedValue = parseInt(_value);
      } else {
        parsedValue = _value;
      }

      const safeValue = getSafeValue(parsedValue, factor, defaultValue);

      onChange(safeValue);
    },
    [getSafeValue, onChange, defaultValue],
  );

  return (
    <div className="input-container" onClick={handleContainerClick} style={{ marginTop: title ? '5px' : '0' }}>
      <span>
        <small>{title}</small>
        <small>{clientValue} / {max}</small>
      </span>
      <div>
        <button type="button" onClick={() => handleChange(defaultValue, -1)}>
          <FiChevronLeft strokeWidth={5} />
        </button>
        <input type="number" ref={inputRef} value={defaultValue} onChange={e => handleChange(e.target.value, 0)} />
        <button type="button" onClick={() => handleChange(defaultValue, 1)}>
          <FiChevronRight strokeWidth={5} />
        </button>
      </div>
    </div>
  );
};

export default Input;
