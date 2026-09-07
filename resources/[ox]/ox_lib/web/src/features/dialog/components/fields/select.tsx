import { MultiSelect, Select } from '@mantine/core';
import { Control, useController } from 'react-hook-form';
import LibIcon from '../../../../components/LibIcon';
import { ISelect } from '../../../../typings';
import { FormValues } from '../../InputDialog';

interface Props {
  row: ISelect;
  index: number;
  control: Control<FormValues>;
}

const SelectField: React.FC<Props> = (props) => {
  const controller = useController({
    name: `test.${props.index}.value`,
    control: props.control,
    rules: { required: props.row.required },
  });

  return (
    <>
      {props.row.type === 'select' ? (
        <Select
          data={props.row.options}
          value={controller.field.value}
          name={controller.field.name}
          ref={controller.field.ref}
          onBlur={controller.field.onBlur}
          onChange={controller.field.onChange}
          disabled={props.row.disabled}
          label={props.row.label}
          description={props.row.description}
          withAsterisk={props.row.required}
          clearable={props.row.clearable}
          searchable={props.row.searchable}
          icon={props.row.icon && <LibIcon icon={props.row.icon} fixedWidth />}
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
      ) : (
        <>
          {props.row.type === 'multi-select' && (
            <MultiSelect
              data={props.row.options}
              value={controller.field.value}
              name={controller.field.name}
              ref={controller.field.ref}
              onBlur={controller.field.onBlur}
              onChange={controller.field.onChange}
              disabled={props.row.disabled}
              label={props.row.label}
              description={props.row.description}
              withAsterisk={props.row.required}
              clearable={props.row.clearable}
              searchable={props.row.searchable}
              maxSelectedValues={props.row.maxSelectedValues}
              icon={props.row.icon && <LibIcon icon={props.row.icon} fixedWidth />}
              styles={{
                root: {
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
          )}
        </>
      )}
    </>
  );
};

export default SelectField;
