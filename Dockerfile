# ----- build -----
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
# (Optional) build steps if you compile TS or assets

# ----- runtime -----
FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
# Create non-root user
RUN addgroup -S app && adduser -S app -G app
COPY --from=build /app /app
USER app
EXPOSE 8080

# Healthcheck uses JSON /metrics; fast and no DB writes
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/metrics >/dev/null || exit 1

CMD ["node", "server.js"]
