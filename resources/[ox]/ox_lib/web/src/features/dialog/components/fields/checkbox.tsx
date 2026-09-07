import { Checkbox } from '@mantine/core';
import { UseFormRegisterReturn } from 'react-hook-form';
import { ICheckbox } from '../../../../typings/dialog';

interface Props {
  row: ICheckbox;
  index: number;
  register: UseFormRegisterReturn;
}

const CheckboxField: React.FC<Props> = (props) => {
  return (
    <Checkbox
      {...props.register}
      sx={{ display: 'flex' }}
      required={props.row.required}
      label={props.row.label}
      defaultChecked={props.row.checked}
      disabled={props.row.disabled}
      styles={{
        label: { color: 'var(--noir-text)' },
        input: {
          borderColor: 'var(--noir-border)',
          backgroundColor: 'var(--noir-panel)',
          borderRadius: 'var(--noir-radius)',
          ':focus': {
            borderColor: 'var(--noir-border-hover)',
            backgroundColor: 'var(--noir-panel)',
            outlineOffset: '2px',
            outline: '2px solid var(--noir-border-hover)',
          },
          ':checked': {
            backgroundColor: 'var(--noir-info)',
            borderBlockColor: 'var(--noir-info)',
            borderColor: 'var(--noir-info)',
            color: 'var(--noir-info)',
          },
        },
      }}
    />
  );
};

export default CheckboxField;
