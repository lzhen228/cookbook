FROM node:20-alpine AS builder

RUN npm config set registry https://registry.npmmirror.com && \
    npm install -g pnpm@8 && \
    pnpm config set registry https://registry.npmmirror.com

WORKDIR /app
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build

FROM nginx:1.25-alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
