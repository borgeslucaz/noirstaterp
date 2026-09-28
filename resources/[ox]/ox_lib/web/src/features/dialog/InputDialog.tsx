import { Modal, Stack } from '@mantine/core';
import dayjs from 'dayjs';
import React from 'react';
import { useFieldArray, useForm } from 'react-hook-form';
import LibIcon from '../../components/LibIcon';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { useLocales } from '../../providers/LocaleProvider';
import type { InputProps } from '../../typings';
import { OptionValue } from '../../typings';
import { fetchNui } from '../../utils/fetchNui';
import CheckboxField from './components/fields/checkbox';
import ColorField from './components/fields/color';
import DateField from './components/fields/date';
import InputField from './components/fields/input';
import NumberField from './components/fields/number';
import SelectField from './components/fields/select';
import SliderField from './components/fields/slider';
import TextareaField from './components/fields/textarea';
import TimeField from './components/fields/time';
import { dialogModalProps } from './modalStyles';

export type FormValues = {
  test: {
    value: any;
  }[];
};

const InputDialog: React.FC = () => {
  const [fields, setFields] = React.useState<InputProps>({
    heading: '',
    rows: [{ type: 'input', label: '' }],
  });
  const [visible, setVisible] = React.useState(false);
  const { locale } = useLocales();

  const form = useForm<{ test: { value: any }[] }>({});
  const fieldForm = useFieldArray({
    control: form.control,
    name: 'test',
  });

  useNuiEvent<InputProps>('openDialog', (data) => {
    setFields(data);
    setVisible(true);
    data.rows.forEach((row, index) => {
      fieldForm.insert(
        index,
        {
          value:
            row.type !== 'checkbox'
              ? row.type === 'date' || row.type === 'date-range' || row.type === 'time'
                ? // Set date to current one if default is set to true
                  row.default === true
                  ? new Date().getTime()
                  : Array.isArray(row.default)
                  ? row.default.map((date) => new Date(date).getTime())
                  : row.default && new Date(row.default).getTime()
                : row.default
              : row.checked,
        } || { value: null }
      );
      // Backwards compat with new Select data type
      if (row.type === 'select' || row.type === 'multi-select') {
        row.options = row.options.map((option) =>
          !option.label ? { ...option, label: option.value } : option
        ) as Array<OptionValue>;
      }
    });
  });

  useNuiEvent('closeInputDialog', async () => await handleClose(true));

  const handleClose = async (dontPost?: boolean) => {
    setVisible(false);
    await new Promise((resolve) => setTimeout(resolve, 200));
    form.reset();
    fieldForm.remove();
    if (dontPost) return;
    fetchNui('inputData');
  };

  const onSubmit = form.handleSubmit(async (data) => {
    setVisible(false);
    const values: any[] = [];
    for (let i = 0; i < fields.rows.length; i++) {
      const row = fields.rows[i];

      if ((row.type === 'date' || row.type === 'date-range') && row.returnString) {
        if (!data.test[i]) continue;
        data.test[i].value = dayjs(data.test[i].value).format(row.format || 'DD/MM/YYYY');
      }
    }
    Object.values(data.test).forEach((obj: { value: any }) => values.push(obj.value));
    await new Promise((resolve) => setTimeout(resolve, 200));
    form.reset();
    fieldForm.remove();
    fetchNui('inputData', values);
  });

  const canCancel = fields.options?.allowCancel !== false;

  return (
    <Modal {...dialogModalProps} opened={visible} onClose={handleClose} closeOnEscape={canCancel} size={430}>
      <form onSubmit={onSubmit}>
        <header className="dialog__header">
          <h2 className="dialog__title">{fields.heading}</h2>
          {canCancel && (
            // Fora do Tab: o foco inicial vai para o primeiro campo (Esc e clique continuam fechando).
            <button
              type="button"
              className="dialog__close"
              aria-label="Fechar"
              tabIndex={-1}
              onClick={() => handleClose()}
            >
              <LibIcon icon="xmark" fixedWidth />
            </button>
          )}
        </header>
        <Stack spacing={14} p={20}>
          {fieldForm.fields.map((item, index) => {
            const row = fields.rows[index];
            return (
              <React.Fragment key={item.id}>
                {row.type === 'input' && (
                  <InputField
                    register={form.register(`test.${index}.value`, { required: row.required })}
                    row={row}
                    index={index}
                  />
                )}
                {row.type === 'checkbox' && (
                  <CheckboxField
                    register={form.register(`test.${index}.value`, { required: row.required })}
                    row={row}
                    index={index}
                  />
                )}
                {(row.type === 'select' || row.type === 'multi-select') && (
                  <SelectField row={row} index={index} control={form.control} />
                )}
                {row.type === 'number' && <NumberField control={form.control} row={row} index={index} />}
                {row.type === 'slider' && <SliderField control={form.control} row={row} index={index} />}
                {row.type === 'color' && <ColorField control={form.control} row={row} index={index} />}
                {row.type === 'time' && <TimeField control={form.control} row={row} index={index} />}
                {row.type === 'date' || row.type === 'date-range' ? (
                  <DateField control={form.control} row={row} index={index} />
                ) : null}
                {row.type === 'textarea' && (
                  <TextareaField
                    register={form.register(`test.${index}.value`, { required: row.required })}
                    row={row}
                    index={index}
                  />
                )}
              </React.Fragment>
            );
          })}
        </Stack>
        <div className="dialog__footer">
          <button type="button" className="dialog-button" onClick={() => handleClose()} disabled={!canCancel}>
            {locale.ui.cancel}
          </button>
          <button type="submit" className="dialog-button dialog-button--confirm">
            {locale.ui.confirm}
          </button>
        </div>
      </form>
    </Modal>
  );
};

export default InputDialog;
