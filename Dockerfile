FROM nginx:alpine
LABEL org.opencontainers.image.title="codyssey-custom-nginx"
ENV APP_ENV=dev
COPY site/ /usr/share/nginx/html/
