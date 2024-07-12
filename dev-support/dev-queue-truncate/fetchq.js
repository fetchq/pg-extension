const { Pool } = require('pg');

class FetchqError extends Error {
  constructor(...args) {
    super(...args);
  }
}

class Fetchq {
  constructor(
    config = {
      user: 'postgres',
      host: 'localhost',
      database: 'postgres',
      password: 'postgres',
      port: 5432,
    },
  ) {
    this.config = config;
    this.pool = null;
  }

  sleep = (delay = 0) => new Promise((resolve) => setTimeout(resolve, delay));

  async init() {
    if (this.pool === null) {
      this.pool = new Pool(this.config);
      await this.pool.connect();
    }
    return this;
  }

  async reset() {
    const res = await this.pool.query(`
      DROP SCHEMA IF EXISTS fetchq CASCADE;
      DROP SCHEMA IF EXISTS fetchq_data CASCADE;
      DROP EXTENSION IF EXISTS fetchq CASCADE;
      DROP EXTENSION IF EXISTS "uuid-ossp";
  
      CREATE SCHEMA IF NOT EXISTS fetchq;
      CREATE SCHEMA IF NOT EXISTS fetchq_data;
      CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
      CREATE EXTENSION fetchq;
  
      SELECT * FROM "fetchq"."init"();
    `);
    const data = res[res.length - 1].rows[0];
    if (!data.was_initialized) {
      throw new FetchqError(`Fetchq failed to initialize`);
    }
    return data;
  }

  async mnt() {
    const res = await this.pool.query(`SELECT * FROM "fetchq"."mnt_job_run"()`);
    return res.rows;
  }

  async queueCreate(queue) {
    const res = await this.pool.query(
      `SELECT * FROM "fetchq"."queue_create"('${queue}')`,
    );
    if (!res.rows[0].was_created) {
      throw new FetchqError(
        `It was not possible to create the queue "${queue}"`,
      );
    }
    return res.rows[0];
  }

  async queueTruncate(queue) {
    if (false) {
      try {
        await this.pool.query(
          `SELECT * FROM "fetchq"."queue_truncate"('${queue}', true)`,
        );
      } catch (err) {
        throw new FetchqError(`${err.message} on "queue_truncate"`);
      }
    } else {
      try {
        await this.pool.query(
          `TRUNCATE fetchq_data.${queue}__docs RESTART IDENTITY`,
        );
      } catch (err) {
        throw new FetchqError(`${err.message} on docs`);
      }

      try {
        await this.pool.query(
          `TRUNCATE fetchq_data.${queue}__logs RESTART IDENTITY`,
        );
      } catch (err) {
        throw new FetchqError(`${err.message} on logs`);
      }

      try {
        await this.pool.query(
          `TRUNCATE fetchq_data.${queue}__metrics RESTART IDENTITY`,
        );
      } catch (err) {
        throw new FetchqError(`${err.message} on truncate metrics`);
      }

      try {
        await this.pool.query(
          `UPDATE "fetchq"."jobs" SET "attempts" = 0, "iterations" = 0, "next_iteration" = NOW(), "last_iteration" = NULL WHERE "queue" = '${queue}';`,
        );
      } catch (err) {
        throw new FetchqError(`${err.message} on update fetchq jobs`);
      }

      try {
        await this.pool.query(
          `SELECT * FROM "fetchq"."metric_reset"('${queue}')`,
        );
      } catch (err) {
        throw new FetchqError(`${err.message} on metric reset`);
      }
    }
  }

  async docAppend(queue, payload = {}) {
    const res = await this.pool.query(
      `SELECT * FROM "fetchq"."doc_append"('${queue}', '${JSON.stringify(
        payload,
      )}')`,
    );
    if (!res.rowCount) {
      throw new FetchqError(
        `It was not possible to append documents into the queue "${queue}"`,
      );
    }
    return res.rows[0];
  }

  async docPick(queue) {
    const res = await this.pool.query(
      `SELECT * FROM "fetchq"."doc_pick"('${queue}')`,
    );
    return res.rowCount
      ? {
          queue,
          ...res.rows[0],
        }
      : null;
  }

  async docComplete({ queue, subject }) {
    const res = await this.pool.query(
      `SELECT * FROM "fetchq"."doc_complete"('${queue}', '${subject}')`,
    );
    if (!res.rowCount) {
      throw new FetchqError(
        `It was not possible to set the document as completed "${
          queue / subject
        }"`,
      );
    }
    return res.rows[0];
  }

  async docLog({ queue, subject }, message, details = {}) {
    const res = await this.pool.query(
      `SELECT * FROM "fetchq"."log_error"('${queue}', '${subject}', '${message}', '${JSON.stringify(
        details,
      )}')`,
    );
    if (!res.rowCount) {
      throw new FetchqError(
        `It was not possible to log the document "${queue / subject}"`,
      );
    }
    return res.rows[0];
  }
}

module.exports = Fetchq;
