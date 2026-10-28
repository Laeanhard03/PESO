FROM node:22-bookworm-slim
ENV NODE_ENV=production HOST=0.0.0.0 PORT=3000
WORKDIR /app
COPY --chown=node:node backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --chown=node:node backend/server.js ./server.js
COPY --chown=node:node backend/src ./src
COPY --chown=node:node backend/mini_ai_runtime ./mini_ai_runtime
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 CMD ["node", "-e", "fetch('http://127.0.0.1:3000/api/health').then(r=>r.json()).then(d=>process.exit(d.mongoDbConnected?0:1)).catch(()=>process.exit(1))"]
CMD ["node", "server.js"]