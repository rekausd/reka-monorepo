FROM node:20-alpine
WORKDIR /app
COPY package.json package-lock.json* yarn.lock* ./
RUN npm i --no-audit --no-fund
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm","run","start"]
