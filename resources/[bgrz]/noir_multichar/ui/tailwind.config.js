/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
    colors:{
      primary: '#88cfcd',
      white: 'rgba(255,255,255,0.8)'
    },
    },
    fontFamily: {
      poppins: ["Anton", "sans-serif"],
      oswald: ["Pricedown", "sans-serif"],
    },
  },
  plugins: [
    require('tailwind-scrollbar'),
    function({addUtilities}) {
      const newUtilities = {
        '.scrollbar-thin': {
          scrollbarWidth: "thin",
          scrollbarColor: "rgba(0,0,0,1)"
        },
        ".scrollbar-webkit": {
          "&::-webkit-scrollbar": {
            width: "8px",
          },
          "&::-webkit-scrollbar-track": {
            backgroundColor: "rgba(0,0,0,1)",
          },
          "&::-webkit-scrollbar-thumb": {
            backgroundColor: "rgba(0,0,0,1)",
            borderRadius: "20px",
            border: "1px solid rgba(0,0,0,1)"
          }
        }
      };
      addUtilities(newUtilities, ["responsive", "hover"]);
    }
  ],
}
