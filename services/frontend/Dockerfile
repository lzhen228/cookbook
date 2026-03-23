FROM node:20-alpine AS builder

RUN npm config set registry https://registry.npmmirror.com && \
    npm install -g pnpm@9 && \
    pnpm config set registry https://registry.npmmirror.com

WORKDIR /app

# 复制 workspace 根配置和完整 lockfile（build context 为仓库根目录）
COPY pnpm-workspace.yaml pnpm-lock.yaml ./
COPY services/frontend/package.json ./services/frontend/

RUN pnpm install --frozen-lockfile --filter ./services/frontend

COPY services/frontend/ ./services/frontend/

WORKDIR /app/services/frontend
RUN pnpm build

FROM nginx:1.25-alpine

COPY --from=builder /app/services/frontend/dist /usr/share/nginx/html
COPY services/frontend/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
