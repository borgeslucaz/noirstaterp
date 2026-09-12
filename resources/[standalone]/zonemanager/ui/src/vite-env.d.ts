/// <reference types="svelte" />
/// <reference types="vite/client" />

interface ImportMeta {
	readonly env: ImportMetaEnv;
	readonly hot?: {
		dispose: (cb: () => void) => void;
	};
}

interface ImportMetaEnv {
	readonly DEV: boolean;
	readonly PROD: boolean;
	readonly MODE: string;
	readonly VITE_RESOURCE_NAME?: string;
}
