const http = require('http');
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  if (req.url === '/health') {
    res.end(JSON.stringify({ status: 'ok', db: process.env.DATABASE_URL ? 'configured' : 'not configured' }));
  } else {
    res.end(JSON.stringify({ message: 'API funcionando!' }));
  }
});
server.listen(3000, () => console.log('API rodando na porta 3000'));
