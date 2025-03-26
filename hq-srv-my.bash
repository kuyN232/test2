#!/bin/bash

int1=$1
hq_srv_hostname=$2
srv_user=$3
srv_uid=$4
vid_srv=$5
vid_mngt=$6
ip_mngt=$7
port=$8

if (( $# < 8 )); then
	echo "Бивень, надо так:"
	echo "$0 int1 hq-srv_hostname srv_user srv_uid vid_srv vid_managment ip_mngt port"
	exit 1
fi

echo "Пинаем управленьческий int"
mkdir /etc/net/ifaces/$int1.$vid_mngt
cp /etc/net/ifaces/$int1.$vid_srv/options /etc/net/ifaces/$int1.$vid_mngt/options
sed -i "s/VID=$vid_srv/VID=$vid_nmgt/" /etc/net/ifaces/$int1.$vid_mngt/options
echo "$ip_mngt" > /etc/net/ifaces/$int1.$vid_mngt/ipv4address

###
echo "Меняем имя хоста, настраиваем время"
echo "$hq_srv_hostname" > /etc/hostname
apt-get update && apt-get install -y tzdata && timedatectl set-timezone Asia/Novosibirsk

###
echo "Настраиваем удалённый доступ" 
echo "Authorized access only" > /etc/banner
echo "Banner /etc/banner" >> /etc/openssh/sshd_config

sed -i "s/#Port 22/Port $port/g" /etc/openssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 2/' /etc/openssh/sshd_config
echo "AllowUsers $srv_user" >> /etc/openssh/sshd_config

systemctl restart sshd

###
echo "Создаём пользователя. Пароль пишем ручками. Ибо я устал. =-="
adduser $srv_user -u $srv_uid
echo "$srv_user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
usermod -aG wheel $srv_user
passwd $srv_user


exit 0


###
echo "Настройка DNS"
apt-get update && apt-get install bind bind-utils && systemctl enable --now bind
cd /var/lib/bind/etc
echo '
zone "au-team.irpo" {
    type master;
    file "test.db";
};

zone "100.16.172.in-addr.arpa" {
    type master;
    file "17216100.db";
};
zone "200.16.172.in-addr.arpa" {
    type master;
    file "17216200.db";
};
' >> local.conf
cd /var/lib/bind/etc/bind/zone
touch 17216100.db
echo '$TTL  1D
@    IN    SOA  au-team.irpo. root.au-team.irpo. (
                2025020600    ; serial
                12H           ; refresh
                1H            ; retry
                1W            ; expire
                1H            ; ncache
            )
     IN    NS     au-team.irpo.
1    IN    PTR    hq-rtr.au-team.irpo.
2    IN    PTR    hq-srv.au-team.irpo.
' >> 17216100.db
cd /var/lib/bind/etc/bind/zone
touch 17216200.db
echo '$TTL  1D
@    IN    SOA  au-team.irpo. root.au-team.irpo. (
                2025020600    ; serial
                12H           ; refresh
                1H            ; retry
                1W            ; expire
                1H            ; ncache
            )
      IN    NS     au-team.irpo.
10    IN    PTR    hq-cli.au-team.irpo.
' >> 17216200.db
cd /var/lib/bind/etc/bind/zone
echo '$TTL  1D
@    IN    SOA  au-team.irpo. root.au-team.irpo. (
                2025020600    ; serial
                12H           ; refresh
                1H            ; retry
                1W            ; expire
                1H            ; ncache
            )
        IN    NS       au-team.irpo.
        IN    A        127.0.0.1
hq-rtr  IN    A        172.16.100.1
br-rtr  IN    A        172.16.77.2
hq-srv  IN    A        172.16.100.2
hq-cli  IN    A        172.16.200.10
br-srv  IN    A        172.16.15.2
moodle  IN    CNAME    hq-rtr
wiki    IN    CNAME    hq-rtr
' >> test.db
