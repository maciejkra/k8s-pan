const express = require('express');
const app = express();
app.get('/', (_, res) => res.json({ status: 'vulnerable demo' }));
app.listen(3000, () => console.log('vulnerable app on :3000'));
