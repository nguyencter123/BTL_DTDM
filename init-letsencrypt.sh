#!/bin/bash

domains=(nguyenbodoi.duckdns.org)
rsa_key_size=4096
data_path="./certbot"
email="your_email@gmail.com" # Tùy chọn, để Let's Encrypt gửi mail nhắc gia hạn
staging=0 # Đặt thành 1 nếu test nhiều lần để tránh bị block IP

if [ -d "$data_path" ]; then
  read -p "Cảnh báo: Thư mục certbot đã tồn tại. Bạn có muốn xóa chứng chỉ cũ và thay thế mới? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

echo "### Tải các thông số bảo mật TLS từ Let's Encrypt ..."
mkdir -p "$data_path/conf"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
echo

echo "### Tạo chứng chỉ giả (dummy) tạm thời để Nginx có thể khởi động..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo


echo "### Khởi động Nginx ..."
docker-compose up --force-recreate -d nginx
echo

echo "### Xóa chứng chỉ giả ..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo


echo "### Gửi yêu cầu xin chứng chỉ THẬT từ Let's Encrypt ..."
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

email_arg="--email $email"
if [ -z "$email" ]; then
  email_arg="--register-unsafely-without-email"
fi

if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Khởi động lại Nginx để nhận chứng chỉ mới ..."
docker-compose exec nginx nginx -s reload
