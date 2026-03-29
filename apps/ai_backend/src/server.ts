import { app } from './app.js';
import { env } from './lib/env.js';

app.listen(env.PORT, '0.0.0.0', () => {
  console.log(`AI backend listening on port ${env.PORT} (accessible via all network interfaces)`);
});
