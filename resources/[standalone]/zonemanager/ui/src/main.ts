import { mount } from 'svelte';
import { installScaler } from '@/lib/ui/nui';
import App from './App.svelte';
import './app.css';

installScaler();

const target = document.getElementById('app');
if (!target) throw new Error('#app not found in index.html');

mount(App, { target });
