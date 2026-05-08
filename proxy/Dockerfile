FROM nginx:alpine
 
COPY nginx.conf /etc/nginx/nginx.conf

RUN apk update && apk add bash openssl

RUN mkdir /keys
RUN openssl genrsa -out /keys/notebook.com-key.pem 2048
RUN openssl req -x509 -new -nodes -batch \
  -key /keys/notebook.com-key.pem \
  -sha256 -days 365 \
  -subj "/CN=notebook.com" \
  -out /keys/notebook.com.pem
