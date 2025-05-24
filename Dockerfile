#############
# Build Stage: Frontend
#############
FROM node:22-alpine AS web-build
WORKDIR /web
# Install compatibility layer
RUN apk add --no-cache gcompat
# Copy frontend code
COPY apps/web/package*.json ./
# Copy production environment variables for build
COPY apps/web/.env.container .env
# Copy TypeScript configs
COPY apps/web/tsconfig.json apps/web/tsconfig.app.json apps/web/tsconfig.node.json ./
# Copy Vite config, HTML entrypoint, and source
COPY apps/web/vite.config.ts apps/web/index.html ./
COPY apps/web/src ./src
# Install dependencies and build
RUN npm install --legacy-peer-deps
RUN npm run build

#############
# Build Stage: Backend
#############
FROM node:22-alpine AS api-build
WORKDIR /api
# Install compatibility layer
RUN apk add --no-cache gcompat
# Copy backend code
COPY apps/api/package*.json apps/api/tsconfig.json ./
COPY apps/api/ ./
# Bring local .env into build output for runtime (dotenv)
COPY apps/api/.env ./
# Install deps, compile TS, and prune dev
RUN npm install --legacy-peer-deps
RUN npm run build
RUN npm prune --production

#############
# Final Stage: NGINX + Node
#############
FROM nginx:stable-alpine AS final
## Install Node.js runtime so we can run the API
RUN apk add --no-cache nodejs

# Copy SPA assets to NGINX html dir
COPY --from=web-build /web/dist /usr/share/nginx/html
# Replace default NGINX config
COPY docker/nginx.conf /etc/nginx/nginx.conf

  # Copy API server, Node modules, and local .env for dotenv
RUN mkdir /app
COPY --from=api-build /api/dist /app/api
COPY --from=api-build /api/node_modules /app/node_modules
COPY --from=api-build /api/package.json /app/package.json
COPY --from=api-build /api/.env /app/api/.env

# Entrypoint to run Node API & NGINX
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose HTTP port
EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]