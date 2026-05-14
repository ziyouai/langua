const react = require('@vitejs/plugin-react')

module.exports = {
  plugins: [react.default ? react.default() : react()],
  base: '/langua/',
}
