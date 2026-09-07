import { Textarea } from '@mantine/core';
import React from 'react';
import { UseFormRegisterReturn } from 'react-hook-form';
import LibIcon from '../../../../components/LibIcon';
import { ITextarea } from '../../../../typings/dialog';

interface Props {
  register: UseFormRegisterReturn;
  row: ITextarea;
  index: number;
}

const TextareaField: React.FC<Props> = (props) => {
  return (
    <Textarea
      {...props.register}
      defaultValue={props.row.default}
      label={props.row.label}
      description={props.row.description}
      icon={props.row.icon && <LibIcon icon={props.row.icon} fixedWidth />}
      placeholder={props.row.placeholder}
      disabled={props.row.disabled}
      withAsterisk={props.row.required}
      autosize={props.row.autosize}
      minRows={props.row.min}
      maxRows={props.row.max}
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

export default TextareaField;
