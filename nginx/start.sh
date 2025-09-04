# start.sh
docker rm -f gateway

docker run --name=gateway --restart=always -v /root/nginx:/etc/nginx/conf.d/ -v /root/nginx/cert:/etc/nginx/cert/ -v /tmp/gateway:/tmp/ -p 443:443 -p 80:80 -d nginx