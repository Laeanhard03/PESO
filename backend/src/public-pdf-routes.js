/**
 * Admin-only observability and manual refresh routes for public government PDFs.
 * Wiring remains separate so the current API owner can safely integrate it.
 */
export function installPublicPdfRoutes(app, {
  ingestion,
  publishJobs = null,
  requireAuth,
  requireAdmin,
  requireMongo,
  logger = { warn: () => {} },
} = {}) {
  if (!app || typeof app.get !== 'function' || typeof app.post !== 'function') {
    throw new TypeError('An Express-compatible app is required.');
  }
  if (!ingestion || typeof ingestion.getStatus !== 'function' ||
      typeof ingestion.syncAll !== 'function') {
    throw new TypeError('The public PDF ingestion service is required.');
  }
  if (typeof requireAuth !== 'function' || typeof requireAdmin !== 'function' ||
      typeof requireMongo !== 'function') {
    throw new TypeError('The existing authentication, admin and Mongo middleware are required.');
  }

  app.get(
    '/api/admin/public-information/sources',
    requireAuth,
    requireAdmin,
    requireMongo,
    async (_req, res, next) => {
      try {
        const sources = await ingestion.getStatus();
        return res.json({ ok: true, sources });
      } catch (error) {
        return next(error);
      }
    },
  );

  app.post(
    '/api/admin/public-information/sync',
    requireAuth,
    requireAdmin,
    requireMongo,
    async (_req, res, next) => {
      try {
        // Do not hold the request open while potentially downloading ~90 MB
        // across three sources. The status endpoint reports each source result.
        void ingestion.syncAll().catch((error) => {
          logger.warn('[Public PDF ingestion] Manual sync failed (' +
            (typeof error?.name === 'string' ? error.name.slice(0, 80) : 'Error') + ').');
        });
        return res.status(202).json({ ok: true, status: 'sync_started' });
      } catch (error) {
        return next(error);
      }
    },
  );

  if (typeof publishJobs === 'function') {
    // Re-publish the job cards Gemini already read (no PDF downloading, no AI
    // call). Useful after a manual database fix, and it renews card expiry.
    app.post(
      '/api/admin/public-information/jobs/refresh',
      requireAuth,
      requireAdmin,
      requireMongo,
      async (_req, res, next) => {
        try {
          const report = await publishJobs();
          return res.json({ ok: true, report });
        } catch (error) {
          return next(error);
        }
      },
    );
  }
}
