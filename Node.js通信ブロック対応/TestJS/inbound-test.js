// inbound-test.js
const http = require('http');
http.createServer((req, res) => {
  res.end('ok');
}).listen(3000, '0.0.0.0', () => {
  console.log('Listening on port 3000');
});
