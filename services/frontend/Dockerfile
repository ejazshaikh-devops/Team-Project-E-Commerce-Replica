FROM nginx:1.25-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY dist/ /usr/share/nginx/html/
RUN rm -f /etc/nginx/conf.d/default.conf.bak
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost/ping || exit 1
CMD ["nginx", "-g", "daemon off;"]
