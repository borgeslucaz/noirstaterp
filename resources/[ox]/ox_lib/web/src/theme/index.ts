import { MantineThemeOverride } from '@mantine/core';

export const theme: MantineThemeOverride = {
  colorScheme: 'dark',
  fontFamily: 'Albert Sans',
  defaultRadius: 2,
  shadows: { sm: '0 1px 2px rgb(0 0 0), 0 2px 6px rgba(0, 0, 0, 0.85)' },
  components: {
    Button: {
      styles: {
        root: {
          border: '1px solid var(--noir-border)',
          backgroundColor: 'transparent',
          borderRadius: 'var(--noir-radius)',
          color: 'var(--noir-text)',
          '&:hover': { backgroundColor: 'transparent', borderColor: 'var(--noir-border-hover)', color: 'var(--noir-white)' },
        },
      },
    },
  },
};
