import { FILTER_SVG_ID } from './filters';

const LUMA = '0.2126 0.7152 0.0722 0 0  0.2126 0.7152 0.0722 0 0  0.2126 0.7152 0.0722 0 0  0 0 0 1 0';

export function FilterDefs() {
    return (
        <svg id={FILTER_SVG_ID} aria-hidden className="pointer-events-none absolute h-0 w-0" focusable="false">
            <defs>
                <filter id="sdfThermal" colorInterpolationFilters="sRGB">
                    <feColorMatrix type="matrix" values={LUMA} />
                    <feComponentTransfer>
                        <feFuncR type="table" tableValues="0.10 0.25 0.75 1 1 1" />
                        <feFuncG type="table" tableValues="0 0 0.20 0.65 1 1" />
                        <feFuncB type="table" tableValues="0.45 0.75 0.55 0 0.10 0.85" />
                    </feComponentTransfer>
                    <feComponentTransfer>
                        <feFuncR type="linear" slope="1.15" intercept="-0.04" />
                        <feFuncG type="linear" slope="1.15" intercept="-0.04" />
                        <feFuncB type="linear" slope="1.15" intercept="-0.04" />
                    </feComponentTransfer>
                </filter>

                <filter id="sdfNightVision" colorInterpolationFilters="sRGB">
                    <feColorMatrix in="SourceGraphic" type="matrix" values={LUMA} result="gray" />
                    <feComponentTransfer in="gray" result="tinted">
                        <feFuncR type="linear" slope="0.18" intercept="0" />
                        <feFuncG type="linear" slope="1.5" intercept="0.02" />
                        <feFuncB type="linear" slope="0.28" intercept="0" />
                    </feComponentTransfer>
                    <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" result="grain" />
                    <feColorMatrix in="grain" type="matrix"
                        values="0 0 0 0 0.06   0 0 0 0 0.16   0 0 0 0 0.06   0 0 0 0 1" result="grainRGB" />
                    <feBlend in="tinted" in2="grainRGB" mode="screen" result="lit" />
                    <feComposite in="lit" in2="SourceGraphic" operator="in" />
                </filter>

                <filter id="sdfInfrared" colorInterpolationFilters="sRGB">
                    <feColorMatrix type="matrix"
                        values="0.30 1.40 0.10 0 0   0.15 0.25 0.35 0 0   0.55 0.20 0.80 0 0   0 0 0 1 0" />
                    <feComponentTransfer>
                        <feFuncR type="gamma" exponent="0.75" />
                        <feFuncB type="gamma" exponent="0.9" />
                    </feComponentTransfer>
                </filter>

                <filter id="sdfDuotone" colorInterpolationFilters="sRGB">
                    <feColorMatrix type="matrix" values={LUMA} />
                    <feComponentTransfer>
                        <feFuncR type="table" tableValues="0.09 0.99" />
                        <feFuncG type="table" tableValues="0.02 0.42" />
                        <feFuncB type="table" tableValues="0.36 0.18" />
                    </feComponentTransfer>
                </filter>

                <filter id="sdfPoster" colorInterpolationFilters="sRGB">
                    <feComponentTransfer>
                        <feFuncR type="discrete" tableValues="0 0.25 0.5 0.75 1" />
                        <feFuncG type="discrete" tableValues="0 0.25 0.5 0.75 1" />
                        <feFuncB type="discrete" tableValues="0 0.25 0.5 0.75 1" />
                    </feComponentTransfer>
                    <feColorMatrix type="saturate" values="1.6" />
                </filter>

                <filter id="sdfBlueprint" colorInterpolationFilters="sRGB">
                    <feColorMatrix type="matrix" values={LUMA} />
                    <feComponentTransfer>
                        <feFuncR type="table" tableValues="0.04 0.62" />
                        <feFuncG type="table" tableValues="0.12 0.80" />
                        <feFuncB type="table" tableValues="0.42 1" />
                    </feComponentTransfer>
                    <feComponentTransfer>
                        <feFuncR type="gamma" exponent="1.5" />
                        <feFuncG type="gamma" exponent="1.3" />
                    </feComponentTransfer>
                </filter>

                <filter id="sdfDream" colorInterpolationFilters="sRGB">
                    <feGaussianBlur stdDeviation="6" result="soft" />
                    <feBlend in="SourceGraphic" in2="soft" mode="screen" result="glow" />
                    <feColorMatrix in="glow" type="saturate" values="1.35" />
                    <feComponentTransfer>
                        <feFuncR type="linear" slope="0.95" intercept="0.05" />
                        <feFuncG type="linear" slope="0.95" intercept="0.04" />
                        <feFuncB type="linear" slope="0.98" intercept="0.06" />
                    </feComponentTransfer>
                </filter>

                <filter id="sdfVhs" colorInterpolationFilters="sRGB">
                    <feOffset in="SourceGraphic" dx="-3" dy="0" result="shiftL" />
                    <feColorMatrix in="shiftL" type="matrix"
                        values="1 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0" result="redCh" />
                    <feOffset in="SourceGraphic" dx="3" dy="0" result="shiftR" />
                    <feColorMatrix in="shiftR" type="matrix"
                        values="0 0 0 0 0  0 0 0 0 0  0 0 1 0 0  0 0 0 1 0" result="blueCh" />
                    <feColorMatrix in="SourceGraphic" type="matrix"
                        values="0 0 0 0 0  0 1 0 0 0  0 0 0 0 0  0 0 0 1 0" result="greenCh" />
                    <feBlend in="redCh" in2="greenCh" mode="screen" result="rg" />
                    <feBlend in="rg" in2="blueCh" mode="screen" result="rgb" />
                    <feComponentTransfer in="rgb">
                        <feFuncR type="linear" slope="1.1" intercept="-0.02" />
                        <feFuncG type="linear" slope="1.05" intercept="0" />
                        <feFuncB type="linear" slope="1.1" intercept="0.02" />
                    </feComponentTransfer>
                </filter>

                <filter id="sdfFrost" colorInterpolationFilters="sRGB">
                    <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="3" result="noise" />
                    <feDisplacementMap in="SourceGraphic" in2="noise" scale="5"
                        xChannelSelector="R" yChannelSelector="G" result="warpRaw" />
                    <feComposite in="warpRaw" in2="SourceGraphic" operator="in" result="warp" />
                    <feColorMatrix in="warp" type="matrix"
                        values="0.85 0.05 0.20 0 0.02   0.10 0.90 0.25 0 0.03   0.25 0.20 1.05 0 0.06   0 0 0 1 0" />
                    <feComponentTransfer>
                        <feFuncR type="gamma" exponent="1.1" />
                        <feFuncB type="gamma" exponent="0.85" />
                    </feComponentTransfer>
                </filter>

                <filter id="sdfEmber" colorInterpolationFilters="sRGB">
                    <feColorMatrix type="matrix" values={LUMA} />
                    <feComponentTransfer>
                        <feFuncR type="table" tableValues="0.06 0.55 1 1" />
                        <feFuncG type="table" tableValues="0.02 0.12 0.55 0.95" />
                        <feFuncB type="table" tableValues="0.08 0.05 0.02 0.55" />
                    </feComponentTransfer>
                    <feComponentTransfer>
                        <feFuncR type="gamma" exponent="0.85" />
                    </feComponentTransfer>
                </filter>
            </defs>
        </svg>
    );
}
