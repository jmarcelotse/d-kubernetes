const http = require('http');
const server = http.createServer((req, res) => {
  res.end('Hello from myapp!\n');
});
server.listen(3000, () => console.log('Listening on port 3000'));
