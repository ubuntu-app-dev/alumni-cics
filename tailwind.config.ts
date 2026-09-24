import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        regal: { DEFAULT: '#0f3375', 50: '#f4f8ff', 100: '#e8f3fe', 200: '#cce4fd', 300: '#a4cefc', 400: '#77b6fb', 500: '#0f3375', 600: '#13459c', 700: '#1557c0', 800: '#196bde', 900: '#2382f7' },
        ink: '#14233f',
        canvas: '#f5f8fd',
      },
      boxShadow: { soft: '0 10px 35px rgba(22, 53, 105, .06)' },
      borderRadius: { '2xl': '1.25rem' },
    },
  },
  plugins: [],
};
export default config;
