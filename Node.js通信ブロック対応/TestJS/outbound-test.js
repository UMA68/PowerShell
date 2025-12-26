// outbound-test.js
require('https').get('https://example.com', res => {
  console.log('STATUS:', res.statusCode);
}).on('error', err => {
  console.error('ERROR:', err.code || err.message);
});
