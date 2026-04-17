# Celowo stara baza z mnóstwem CVE — do nauki Trivy
FROM node:14.0.0-buster

WORKDIR /app
COPY package.json .
RUN npm install --production

COPY server.js .

EXPOSE 3000
CMD ["node", "server.js"]
