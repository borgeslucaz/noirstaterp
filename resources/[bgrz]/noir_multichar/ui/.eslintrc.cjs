module.exports = {
  root: true,
  env: { browser: true, es2022: true },
  extends: ["eslint:recommended", "plugin:react-hooks/recommended"],
  parserOptions: { ecmaVersion: "latest", sourceType: "module", ecmaFeatures: { jsx: true } },
  plugins: ["react", "react-refresh"],
  rules: {
    "no-unused-vars": "off",
    "react/jsx-uses-vars": "error",
    "react-hooks/exhaustive-deps": "off",
    "react-refresh/only-export-components": "off",
  },
  overrides: [{ files: ["*.config.js"], env: { node: true } }],
};
