# syntax=docker/dockerfile:1
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi


# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
ENV NEXT_TELEMETRY_DISABLED 1

RUN yarn build

# If using npm comment out above and use below instead
# RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV development
# Uncomment the following line in case you want to disable telemetry during runtime.
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000
ENV NODE_ENV=development \
    APP_ENV=development \
    NEXT_PUBLIC_SANITY_WRITE_KEY=skVhm3VhF0mO6TUkcO4kwRJv3q50N4er8uZt79MdUiDLgu8WNjIA3rhEWZp9IikKtn65Jw3xL8lPY0GlMfgphFVL2ORg2uxKhSCFUo6qv5vFezfM7wpzSAk3FzJErFy4CocRWJzjGCXytBAIs8H8fVsQ9NVDg177zsw3fgSpRbDXdmfRds5V \
    NEXT_PUBLIC_SANITY_DATASET=cmx-data \
    NEXT_PUBLIC_SANITY_ID=4llqmfig \
    NEXT_SHARP_PATH="/tmp/node_modules/sharp" \
    OPENAI_API_KEY=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 \
    PORT=3000

CMD ["node", "server.js"]