const express = require('express');
const app = express();
const port = process.env.PORT || 3000;
const swaggerSetup = require('./config/swagger');
const postRoutes = require('./routes/post.routes');
const db = require('./models');

app.use(express.json());

app.get('/', (req, res) => {
  res.send('Hello World!');
});

app.use('/posts', postRoutes);

swaggerSetup(app);

db.sequelize.sync().then(() => {
  app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
    console.log('Database synchronized');
  });
});

module.exports = app;