/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      borderRadius: {
        'lg': '0.625rem', // 10px
      },
      transitionDuration: {
        '200': '200ms',
      },
      fontFamily: {
        sans: ['Open Sans', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms')({
      strategy: 'class',
    }),
  ],
}