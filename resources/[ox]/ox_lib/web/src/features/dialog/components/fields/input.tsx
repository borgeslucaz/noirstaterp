import { createStyles, PasswordInput, TextInput } from '@mantine/core';
import React from 'react';
import { UseFormRegisterReturn } from 'react-hook-form';
import LibIcon from '../../../../components/LibIcon';
import { IInput } from '../../../../typings/dialog';

interface Props {
  register: UseFormRegisterReturn;
  row: IInput;
  index: number;
}

const useStyles = createStyles((theme) => ({
  eyeIcon: {
    color: 'var(--noir-text)',
  },
  InputField: {
    color: 'var(--noir-text)',
    backgroundColor: 'var(--noir-panel)',
  },
}));

const InputField: React.FC<Props> = (props) => {
  const { classes } = useStyles();

  return (
    <>
      {!props.row.password ? (
        <TextInput
          {...props.register}
          defaultValue={props.row.default}
          label={props.row.label}
          description={props.row.description}
          icon={props.row.icon && <LibIcon icon={props.row.icon} fixedWidth />}
          placeholder={props.row.placeholder}
          minLength={props.row.min}
          maxLength={props.row.max}
          disabled={props.row.disabled}
          withAsterisk={props.row.required}
          styles={{
            input: {
              color: 'var(--noir-text)',
              backgroundColor: 'var(--noir-panel)',
              borderRadius: 'var(--noir-radius)',
              borderColor: 'var(--noir-border)',
              ':focus': {
                borderColor: 'var(--noir-border-hover)',
              },
            },
          }}
        />
      ) : (
        <PasswordInput
          {...props.register}
          defaultValue={props.row.default}
          label={props.row.label}
          description={props.row.description}
          icon={props.row.icon && <LibIcon icon={props.row.icon} fixedWidth />}
          placeholder={props.row.placeholder}
          minLength={props.row.min}
          maxLength={props.row.max}
          disabled={props.row.disabled}
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
          visibilityToggleIcon={({ reveal, size }) => (
            <LibIcon
              icon={reveal ? 'eye-slash' : 'eye'}
              fontSize={size}
              cursor="pointer"
              className={classes.eyeIcon}
              fixedWidth
            />
          )}
        />
      )}
    </>
  );
};

export default InputField;
