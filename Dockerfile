FROM nginxinc/nginx-unprivileged:1.27-alpine

LABEL org.opencontainers.image.title="fivestep" \
      org.opencontainers.image.description="FiveStep joke builder (static site on Nginx)"

COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY src/ /usr/share/nginx/html/

EXPOSE 8080
