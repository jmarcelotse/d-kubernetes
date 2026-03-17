const http = require('http');
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ message: 'API funcionando!' }));
});
server.listen(3000, () => console.log('API rodando na porta 3000'));
