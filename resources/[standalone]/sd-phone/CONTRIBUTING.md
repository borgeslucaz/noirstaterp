# Contributing to sd-phone

Issues and pull requests are welcome. Please read the section below before adding code, copy or demo
data, because it constrains where certain names are allowed to appear.

## lb-phone interoperability

sd-phone reproduces lb-phone's public interface names deliberately, and only in these places:

- `client/compat/lbphone.lua`
- `server/compat/lbphone/*`
- `server/migrate/**`
- `buildSettings()` in `web/src/shell/CustomAppFrame.tsx`
- the `provide 'lb-phone'` line in `fxmanifest.lua`

What is reproduced there is export names, event names, payload keys, and table and column names.
That is what a compatible interface consists of. A shim that renamed those exports would not run the
scripts written against them, and a migration importer that guessed different column names would not
find the operator's data.

What those files do not take is implementation, prose, layout or assets. They map names across a
boundary and stop there. Several lb-phone features are deliberately absent rather than reimplemented.

### The rule for contributors

Interop code may name lb-phone's interface. Everywhere else, sd-phone's text is its own: player-facing
copy, i18n key names and demo fixtures are written for this project.
