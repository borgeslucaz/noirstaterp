// Ponto de entrada dos formulários: importa cada arquivo de campos (que se registra sozinho)
// e reexporta o que as telas usam.
import './fields-basic.js';
import './fields-position.js';
import './fields-ref.js';
import './fields-condition.js';
import './fields-list.js';
import './fields-actions.js';

export { renderForm, registerField } from './registry.js';
