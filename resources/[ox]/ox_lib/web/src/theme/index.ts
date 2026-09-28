import { MantineThemeOverride } from '@mantine/core';

// DESIGN_v4: campos escuros de 40 px com borda fina e raio 2 px, rótulo em Rajdhani, seleção branca
// com texto escuro. Os campos do input dialog herdam daqui, sem estilo inline.
const field = {
  minHeight: 40,
  height: 40,
  border: '1px solid var(--noir-border)',
  borderRadius: 'var(--noir-radius)',
  backgroundColor: 'var(--noir-field)',
  color: 'var(--noir-text-strong)',
  fontFamily: 'var(--font-ui)',
  fontSize: 14,
  fontWeight: 500,
  transition: 'border-color 150ms, background-color 150ms',
  '&:hover': { backgroundColor: 'var(--noir-field-hover)' },
  '&:focus, &:focus-within': {
    borderColor: 'var(--noir-border-strong)',
    boxShadow: '0 0 0 2px rgba(255, 255, 255, 0.07)',
  },
  '&::placeholder': { color: 'var(--noir-text-faint)' },
  '&:disabled, &[data-disabled]': { opacity: 0.5, backgroundColor: 'var(--noir-field)' },
  '&[data-invalid]': { borderColor: 'var(--noir-danger-hover)', color: 'var(--noir-text-strong)' },
};

const dropdown = {
  padding: 4,
  border: '1px solid var(--noir-border)',
  borderRadius: 'var(--noir-radius)',
  backgroundColor: 'var(--noir-panel-raised)',
  boxShadow: 'var(--shadow-window)',
};

const option = {
  borderRadius: 0,
  fontFamily: 'var(--font-ui)',
  fontSize: 14,
  fontWeight: 500,
  color: 'var(--noir-text)',
  '&[data-hovered]': { backgroundColor: 'rgba(255, 255, 255, 0.06)', color: 'var(--noir-text-strong)' },
  '&[data-selected]': { backgroundColor: 'var(--noir-selected)', color: 'var(--noir-on-light)' },
};

export const theme: MantineThemeOverride = {
  colorScheme: 'dark',
  fontFamily: 'Rajdhani, Arial, sans-serif',
  headings: { fontFamily: "'Saira Condensed', Rajdhani, Arial, sans-serif", fontWeight: 700 },
  defaultRadius: 2,
  shadows: { sm: '0 1px 2px rgb(0 0 0), 0 2px 6px rgba(0, 0, 0, 0.85)' },
  components: {
    Button: {
      styles: {
        root: {
          height: 40,
          border: '1px solid var(--noir-border)',
          backgroundColor: 'var(--noir-panel-raised)',
          borderRadius: 'var(--noir-radius)',
          color: 'var(--noir-text-strong)',
          fontFamily: 'var(--font-display)',
          fontSize: 15,
          fontWeight: 700,
          letterSpacing: '0.03em',
          textTransform: 'uppercase',
          '&:hover': { backgroundColor: 'var(--noir-card-hover)', borderColor: 'var(--noir-border-strong)' },
          '&:disabled, &[data-disabled]': { opacity: 0.38, backgroundColor: 'var(--noir-panel-raised)' },
        },
      },
    },
    Input: {
      styles: {
        input: field,
        icon: { color: 'var(--noir-text-muted)' },
        rightSection: { color: 'var(--noir-text-muted)' },
      },
    },
    InputWrapper: {
      styles: {
        label: {
          marginBottom: 6,
          fontFamily: 'var(--font-ui)',
          fontSize: 14,
          fontWeight: 600,
          color: 'var(--noir-text-strong)',
        },
        description: {
          marginTop: -2,
          marginBottom: 6,
          fontFamily: 'var(--font-ui)',
          fontSize: 12.5,
          fontWeight: 500,
          lineHeight: 1.35,
          color: 'var(--noir-text-muted)',
        },
        error: { fontFamily: 'var(--font-ui)', fontSize: 12.5, fontWeight: 600, color: 'var(--noir-danger-hover)' },
        required: { color: 'var(--noir-danger-hover)' },
      },
    },
    Textarea: {
      styles: { input: { height: 'auto', paddingTop: 10, paddingBottom: 10 } },
    },
    MultiSelect: {
      styles: {
        input: { height: 'auto' },
        value: {
          borderRadius: 'var(--noir-radius)',
          backgroundColor: 'var(--noir-selected)',
          color: 'var(--noir-on-light)',
          fontWeight: 600,
        },
        dropdown,
        item: option,
      },
    },
    Select: { styles: { dropdown, item: option } },
    Checkbox: {
      styles: {
        input: {
          borderRadius: 'var(--noir-radius)',
          border: '1.5px solid rgba(255, 255, 255, 0.5)',
          backgroundColor: 'transparent',
          cursor: 'pointer',
          '&:checked': { backgroundColor: 'var(--noir-selected)', borderColor: 'var(--noir-selected)' },
        },
        icon: { color: 'var(--noir-on-light) !important' },
        label: { fontFamily: 'var(--font-ui)', fontSize: 14, fontWeight: 600, color: 'var(--noir-text-strong)' },
      },
    },
    Slider: {
      styles: {
        track: { '&::before': { backgroundColor: 'var(--noir-track)' } },
        bar: { backgroundColor: 'var(--noir-selected)' },
        thumb: {
          width: 14,
          height: 14,
          borderRadius: 'var(--noir-radius)',
          border: '0',
          backgroundColor: 'var(--noir-selected)',
        },
        mark: { display: 'none' },
        markLabel: {
          marginTop: 8,
          fontFamily: 'var(--font-ui)',
          fontSize: 12.5,
          fontWeight: 500,
          color: 'var(--noir-text-muted)',
          fontVariantNumeric: 'tabular-nums',
        },
      },
    },
    Popover: { styles: { dropdown } },
    Tooltip: {
      styles: {
        tooltip: {
          borderRadius: 'var(--noir-radius)',
          backgroundColor: 'var(--noir-panel-raised)',
          border: '1px solid var(--noir-border)',
          color: 'var(--noir-text-strong)',
          fontFamily: 'var(--font-ui)',
          fontSize: 14,
          fontWeight: 500,
        },
      },
    },
  },
};
