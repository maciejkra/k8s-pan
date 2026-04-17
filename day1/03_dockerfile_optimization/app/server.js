const http = require('http');
const PORT = 3000;

http.createServer((_, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ status: 'ok', ts: Date.now() }));
}).listen(PORT, () => console.log(`listening on ${PORT}`));
