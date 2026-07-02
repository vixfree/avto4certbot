#### Package scripts for auto update all certs.
#### Uses apache2 or nginx and the certbot package.
#### avto4certbot version:0.5.10

* Install:

```
git clone https://github.com/vixfree/avto4certbot.git
cd ~/avto4certbot/src
mkdir -p /etc/avto4certbot
cp * /etc/avto4certbot/
```

* edit avto4certbot.conf
* To check the operation, run the script without parameters, it will install the necessary packages or tell you what needs to be installed.
* if everything is installed, the answer will be:

```
please input pameters: avto4certbot.sh --create [apache & nginx && proxy]| --update [apache & nginx] | --flist [apache & nginx]
avto4certbot.sh --create; create new certificate or --create [apache & nginx && proxy]; create new certificate 
avto4certbot.sh --update; update certificates or --update [apache & nginx && proxy]; update [apache & nginx];
avto4certbot.sh --flist; update certificates from ssl or --flist [apache & nginx && proxy]; rescan list certificates;
avto4certbot.sh --help; this help
* examples:
  avtocertbot.sh --update apache
  or
  avtocertbot.sh --update nginx
  or
  avtocertbot.sh --update apache proxy
```

* Use the --create [apache or nginx] parameter to create the first certificate.
* example crontab:

```
## avtocertbot
24 01 * * * root /etc/avto4certbot/avto4certbot.sh --update nginx
```

* check work - create on server:

```
echo "WELCOME" >/var/www/certbot/www/.well-known/acme-challenge/test.txt
```
* check from an external client:

```
curl -ikL http://mydomen.ru/.well-known/acme-challenge/test.txt
```

License: GPLv2.0
