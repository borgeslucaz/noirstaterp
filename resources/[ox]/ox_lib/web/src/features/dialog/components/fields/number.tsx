import { NumberInput } from '@mantine/core';
import { Control, useController } from 'react-hook-form';
import LibIcon from '../../../../components/LibIcon';
import { INumber } from '../../../../typings/dialog';
import { FormValues } from '../../InputDialog';

interface Props {
  row: INumber;
  index: number;
  control: Control<FormValues>;
}

const NumberField: React.FC<Props> = (props) => {
  const controller = useController({
    name: `test.${props.index}.value`,
    control: props.control,
    defaultValue: props.row.default,
    rules: { required: props.row.required, min: props.row.min, max: props.row.max },
  });

  return (
    <NumberInput
      value={controller.field.value}
      name={controller.field.name}
      ref={controller.field.ref}
      onBlur={controller.field.onBlur}
      onChange={controller.field.onChange}
      label={props.row.label}
      description={props.row.description}
      defaultValue={props.row.default}
      min={props.row.min}
      max={props.row.max}
      step={props.row.step}
      precision={props.row.precision}
      disabled={props.row.disabled}
      icon={props.row.icon && <LibIcon icon={props.row.icon} fixedWidth />}
      withAsterisk={props.row.required}
      styles={{
        input: {
          color: 'var(--noir-text)',
          backgroundColor: 'var(--noir-panel)',
          borderRadius: 'var(--noir-radius)',
          borderColor: 'var(--noir-border)',
          ':focus-within': {
            borderColor: 'var(--noir-border-hover)',
          },
        },
        icon: {
          color: 'var(--noir-text)',
        },
      }}
    />
  );
};

export default NumberField;
