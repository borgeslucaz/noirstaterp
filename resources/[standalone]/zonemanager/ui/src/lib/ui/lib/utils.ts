// Class-name join helper. Composable variant maps live in ./tv.

type ClassValue = string | false | null | undefined | ClassValue[];

// Plain join, no conflict-merge - tv() resolves Tailwind conflicts within its own
// variant output. Reach for tailwind-merge only if a conflict surfaces outside tv().
export function cn(...inputs: ClassValue[]): string {
	const out: string[] = [];
	for (const input of inputs) {
		if (!input) continue;
		if (Array.isArray(input)) {
			const nested = cn(...input);
			if (nested) out.push(nested);
		} else {
			out.push(input);
		}
	}
	return out.join(' ');
}
