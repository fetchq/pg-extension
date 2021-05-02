const Fetchq = require('./fetchq');

const mnt = async (log) => {
  const fetchq = new Fetchq();
  await fetchq.init();
  await fetchq.reset();

  const loop = async (sleep = 50, errSleep = 100) => {
    try {
      await fetchq.mnt();
    } catch (err) {
      log(err.message);
      await fetchq.sleep(errSleep);
    }
    loop(sleep, errSleep);
  };

  loop();
};

const producer1 = async (log) => {
  const fetchq = new Fetchq();
  await fetchq.init();

  // Populate "q1"
  await fetchq.queueCreate('q1');

  // Keeps pushing documents
  const loop = async (sleep = 10, errSleep = 100) => {
    try {
      await fetchq.docAppend('q1');
      await fetchq.sleep(sleep);
    } catch (err) {
      log(err.message);
      await fetchq.sleep(errSleep);
    }
    loop(sleep, errSleep);
  };

  loop();
};

const consumer1 = async (log) => {
  const fetchq = new Fetchq();
  await fetchq.init();

  // Keeps consuming documents
  const loop = async (sleep = 10, errSleep = 100) => {
    try {
      const doc = await fetchq.docPick('q1');
      if (doc) {
        // log(doc.subject);
        await fetchq.docLog(doc, 'foobar');
        await fetchq.docComplete(doc);
      }
      await fetchq.sleep(sleep);
    } catch (err) {
      log(err.message);
      await fetchq.sleep(errSleep);
    }
    loop(sleep, errSleep);
  };

  loop();
};

const truncate1 = async (log) => {
  const fetchq = new Fetchq();
  await fetchq.init();

  // Keeps truncating a queue
  const loop = async (sleep = 5000, errSleep = 5000) => {
    try {
      log('go');
      await fetchq.queueTruncate('q1');
      await fetchq.sleep(sleep);
    } catch (err) {
      log(err.message);
      await fetchq.sleep(errSleep);
    }
    loop(sleep, errSleep);
  };

  loop();
};

const createLogger = (name) => (message, ...args) =>
  console.log(`[${name}] ${message}`, ...args);

const start = (app, name = 'app') => {
  return app(createLogger(name))
    .then(() => console.log(`[${name}] boot ok`))
    .catch((err) => {
      console.error(`[${name}] boot failed`);
      console.error(err.message);
    });
};

start(mnt, 'mnt')
  .then(() => start(producer1, 'producer1'))
  .then(() => start(consumer1, 'consumer1'))
  .then(() => start(truncate1, 'truncate1'));
