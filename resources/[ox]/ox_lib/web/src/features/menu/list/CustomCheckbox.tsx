import { Checkbox, createStyles } from '@mantine/core';

const useStyles = createStyles((theme) => ({
  root: {
    display: 'flex',
    alignItems: 'center',
  },
  input: {
    backgroundColor: 'var(--noir-panel)',
    borderColor: 'var(--noir-border)',
    borderRadius: 'var(--noir-radius)',
    '&:checked': { backgroundColor: 'var(--noir-info)', borderColor: 'var(--noir-info)' },
  },
  inner: {
    '> svg > path': {
      fill: 'var(--noir-white)',
    },
  },
}));

const CustomCheckbox: React.FC<{ checked: boolean }> = ({ checked }) => {
  const { classes } = useStyles();
  return (
    <Checkbox
      checked={checked}
      size="md"
      classNames={{ root: classes.root, input: classes.input, inner: classes.inner }}
    />
  );
};

export default CustomCheckbox;
