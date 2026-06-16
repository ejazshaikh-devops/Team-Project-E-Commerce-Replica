FROM node:20-alpine AS builder
WORKDIR /app

COPY services/cart-service/package*.json ./
RUN npm install --omit=dev && npm cache clean --force

FROM node:20-alpine
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

WORKDIR /app

COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs services/cart-service/ .
COPY --chown=nodejs:nodejs services/shared ./shared

USER nodejs
EXPOSE 3000
CMD ["node", "index.js"]
