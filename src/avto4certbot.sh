#!/bin/bash
#
# author: Koshuba V.O.
# license: GPL 2.0
# create 2022
#
version="0.5.10";
sname="avto4certbot";

# script path
path_script=$( cd -- $( dirname -- "${BASH_SOURCE[0]}" ) &> /dev/null && pwd );
source "$path_script/avto4certbot.conf";

# service LAMP
web_service="";

# new certificate or renewal event
event_sw=0;

# event begin or end the work script
event_key="1";

# message from errors
reports=();

# work_sites
active_sites=();

##--@S static values
# depends
pkgdep=("curl" "certbot" "letsencrypt") # packages
get_tools=("curl" "certbot" "letsencrypt")

# - options
cmd=$1;

# - for LAMP server
opt=$2;

# - for proxy mode
sw_proxy=$3;

#--@F Get info area
function getInfo() {
## test - null values
if [ $tmp_dir == "" ]; then
  tmp_dir="/tmp";
fi
web_dir="$tmp_dir/www"
conf_dir="$tmp_dir/conf"

if [ $log_file == "" ]; then
  log_file="/var/log/syslog";
fi

if [ $sites_nginx == "" ]; then
  available_nginx="/etc/nginx/sites-available";
fi

if [ $sites_apache == "" ]; then
  available_apache="/etc/apache2/sites-available";
fi

if [ $sites_nginx == "" ]; then
  sites_nginx="/etc/nginx/sites-enabled";
fi

if [ $sites_apache == "" ]; then
  sites_apache="/etc/apache2/sites-enabled";
  if [ "$(apachectl -M|grep rewrite|wc -m)" == "0" ]; then
    a2enmod rewrite
  fi
fi

## apache2 mode: prefork or worker (multi-instance)
if [ $apache2_service == "" ]; then
  apache2_service="apache2";
fi

if [ $path_ssl == "" ]; then
  path_ssl="/etc/ssl";
fi

if [ $path_cert == "" ]; then
  path_cert="/etc/letsencrypt/live";
fi

## create temp directory
if [ ! -d $tmp_dir ]; then
 mkdir -p $tmp_dir;
fi

## create web directory
if [ ! -d "$web_dir/.well-known/acme-challenge" ]; then
 mkdir -p $web_dir/.well-known/acme-challenge;
 chown -R www-data:www-data $web_dir;
fi

## create conf directory
if [ ! -d $conf_dir ]; then
 mkdir -p $conf_dir;
fi

## create info active config sites 
if [[ "$opt" != "" ]] && [[ $opt != "nginx" ]] && [[ "$opt" == "apache" ]]; then
  if [ "$(find $sites_apache/* -maxdepth 0 -type l -printf '%f\n'|wc -l)" != "0" ]; then
    ls -F -n $sites_apache/*|awk '{print$9":"$11}' >$tmp_dir/active_sites.inf
  else
    touch $tmp_dir/active_sites.inf
  fi
  get_tools[${#get_tools[@]}]="apache2";
  web_service="$apache2_service";
fi
if [[ "$opt" != "" ]] && [[ $opt != "apache" ]] && [[ "$opt" == "nginx" ]]; then
  if [ "$(find $sites_nginx/* -maxdepth 0 -type l -printf '%f\n'|wc -l)" != "0" ]; then
    ls -F -n $sites_nginx/*|awk '{print$9":"$11}' >$tmp_dir/active_sites.inf
  else
    touch $tmp_dir/active_sites.inf
  fi
  get_tools[${#get_tools[@]}]="nginx";
  web_service="nginx";
fi
}

#--@F Check the program dependency
function checkDep() {
    # - msg debug
    echo "check depends..."
    if [ ! "$lang" ]; then
        lang="C.UTF-8"
    fi
    for ((itools = 0; itools != ${#get_tools[@]}; itools++)); do
        checktool=$(whereis -b ${get_tools[$itools]} | awk '/^'${get_tools[$itools]}':/{print $2}')
        if [[ $checktool = "" ]]; then
            sudo apt install ${pkgdep[$itools]}
        fi
        checktool=$(whereis -b ${get_tools[$itools]} | awk '/^'${get_tools[$itools]}':/{print $2}')
        if [[ $checktool != "" ]]; then
            eval get_${get_tools[$itools]}=$(whereis -b ${get_tools[$itools]} | awk '/^'${get_tools[$itools]}':/{print $2}')
            list_tools[${#list_tools[@]}]="$(whereis -b ${get_tools[$itools]} | awk '/^'${get_tools[$itools]}':/{print $2}')"
        else
            ## lang messages if yes then lang else us...
            reports=()
            reports[${#reports[@]}]="Sorry, there are no required packages to work, please install:${pkgdep[@]}"
            makeErr
            exit 0
        fi
    done
}

function swSites(){
## clear active sites
if [ "$event_key" = "1" ]; then
  active_sites=( $(cat $tmp_dir/active_sites.inf|sed 's/:/ /g'|awk '{print$1}') );
  for ((xd=0; xd != ${#active_sites[@]}; xd++)); do
    if [[ "$opt" != "" ]] && [[ $opt != "nginx" ]] && [[ "$opt" == "apache" ]]; then
      if [ -f ${active_sites[$xd]} ]; then
        rm ${active_sites[$xd]}
      fi
    fi
    if [[ "$opt" != "" ]] && [[ $opt != "apache" ]] && [[ "$opt" == "nginx" ]]; then
      if [ -f ${active_sites[$xd]} ]; then
        rm ${active_sites[$xd]}
      fi
    fi
  done
fi
## restore active sites
if [ "$event_key" = "0" ]; then
  # clear tmp configs
  if [[ "$opt" != "" ]] && [[ $opt != "nginx" ]] && [[ "$opt" == "apache" ]]; then
    rm $sites_apache/*.conf
  fi
  if [[ "$opt" != "" ]] && [[ $opt != "apache" ]] && [[ "$opt" == "nginx" ]]; then
    rm $sites_nginx/*.conf
  fi
  # restore active links
  active_sites=( $(cat $tmp_dir/active_sites.inf) );
  for ((xd=0; xd != ${#active_sites[@]}; xd++)); do
    if [[ "$opt" != "" ]] && [[ $opt != "nginx" ]] && [[ "$opt" == "apache" ]]; then
      get_enable=$(echo -e ${active_sites[$xd]}|sed 's/:/ /g'|awk '{print$1}');
      get_available=$(echo -e ${active_sites[$xd]}|sed 's/:/ /g'|awk '{print$2}');
      if [ ! -f $get_enable ]; then
        ln -s $get_available $get_enable;
      fi
    fi
    if [[ "$opt" != "" ]] && [[ $opt != "apache" ]] && [[ "$opt" == "nginx" ]]; then
      get_enable=$(echo -e ${active_sites[$xd]}|sed 's/:/ /g'|awk '{print$1}');
      get_available=$(echo -e ${active_sites[$xd]}|sed 's/:/ /g'|awk '{print$2}');
      if [ ! -f $get_enable ]; then
        ln -s $get_available $get_enable;
      fi
    fi
  done
fi
}

##--@F make all errors
function makeErr() {
for ((rpt_index=0; rpt_index != ${#reports[@]}; rpt_index++))
    do
    echo  "$rdate $sname: ${reports[$rpt_index]}">>$log_file;
    echo   "${reports[$rpt_index]}";
    done
 exit 0;
}

function createCert() {
#
for ((xd=0; xd != ${#domains[@]}; xd++)); do
  local site_data=( $(echo -e ${domains[$xd]}|sed 's/ /\n /g') );
  site_name="${site_data[0]}";
  site_owner="${site_data[1]}";
  certbot -m "$site_owner" certonly --webroot --webroot-path $web_dir -d $site_name
  sleep 2;
done
}

##--@F exec task
function scanSSL(){
## if event - yes
event_sw=0;
rdate=$(date +%Y-%m-%d);
rtime=$(date +%H:%M);
for ((xd=0; xd != ${#domains[@]}; xd++)); do
  local site_data=( $(echo -e ${domains[$xd]}|sed 's/ /\n /g') );
  site_name="${site_data[0]}";
  if [ -d $path_cert/$site_name ]; then
    keydate=$(ls -l --time-style=long-iso $path_cert/$site_name/cert.pem |awk {'print$6'});
    keytime=$(ls -l --time-style=long-iso $path_cert/$site_name/cert.pem |awk {'print$7'});
    if [ ! -f $path_ssl/certs/$site_name.pem ]; then
      ((event_sw++));
      if [ -f $path_ssl/private/$site_name.pem ]; then
        cp -f $path_ssl/private/$site_name.pem $path_ssl/certs/$site_name.pem
        cd $path_ssl/certs
        chmod 600 $site_name.pem
        ln -sf $site_name.pem `openssl x509 -noout -hash < $site_name.pem`.0
        cd $path_ssl
        echo "$(date) - $sname: update cert for  $site_name">> $log_file;
      fi
    fi

    if [[ -f $path_ssl/private/$site_name.pem ]] && [[ "$keydate" = "$rdate" ]] && [[ "$keytime" = "$rtime" ]]; then
      ((event_sw++));
        cp -f $path_ssl/private/$site_name.pem $path_ssl/certs/$site_name.pem
        cd $path_ssl/certs
        chmod 600 $site_name.pem
        ln -sf $site_name.pem `openssl x509 -noout -hash < $site_name.pem`.0
        cd $path_ssl
        echo "$(date) - $sname: update cert for  $site_name">> $log_file;
    fi
  fi
done

if [ $event_sw != 0 ];then
  flistCerts;
fi
}

##--@F create from ssl
function flistCerts(){
echo>/etc/ssl/crt-list.txt
for ((xd=0; xd != ${#domains[@]}; xd++)); do
  local site_data=( $(echo -e ${domains[$xd]}|sed 's/ /\n /g') );
  site_name="${site_data[0]}";
  if [ -d $path_cert/$site_name ]; then
    cat $path_cert/$site_name/privkey.pem > $path_ssl/private/privkey_$site_name.pem;
    chmod 0640 $path_ssl/private/privkey_$site_name.pem;
    cat $path_cert/$site_name/fullchain.pem > $path_ssl/private/fullchain_$site_name.pem;
    cat $path_cert/$site_name/fullchain.pem > $path_ssl/private/$site_name.pem;
    cat $path_cert/$site_name/privkey.pem >> $path_ssl/private/$site_name.pem;
    echo "$path_ssl/$site_name.pem">>/etc/ssl/crt-list.txt
    cp -f $path_ssl/private/$site_name.pem $path_ssl/certs/$site_name.pem
    cd $path_ssl/certs
    chmod 600 $site_name.pem
    ln -sf $site_name.pem `openssl x509 -noout -hash < $site_name.pem`.0
    cd $path_ssl
  fi
done
}

##--@F create configs
function createConf(){
for ((xd=0; xd != ${#domains[@]}; xd++)); do
  local site_data=( $(echo -e ${domains[$xd]}|sed 's/ /\n /g') );
  site_name="${site_data[0]}";
  site_owner="${site_data[1]}";
  site_port="${site_data[2]}";
  ## apache2 config
  if [[ "$opt" != "" ]] && [[ $opt != "nginx" ]] && [[ "$opt" == "apache" ]]; then
    ## добавить проверку режима apache2 и путь для активации конфигурации
    echo >$conf_dir/$site_name.conf;
    echo -e '<VirtualHost *:'"$site_port"'>' >>$conf_dir/$site_name.conf;
    echo -e '  ServerName '"$site_name"'' >>$conf_dir/$site_name.conf;
    echo -e '  ServerAlias '"$site_name"'' >>$conf_dir/$site_name.conf;
    echo -e '  DocumentRoot '"$web_dir"'' >>$conf_dir/$site_name.conf;
    echo -e ''>>$conf_dir/$site_name.conf;
    echo -e '  <Directory '"$web_dir"'>' >>$conf_dir/$site_name.conf;
    echo -e '    RewriteEngine On'>>$conf_dir/$site_name.conf;
    echo -e '    RewriteCond %{REQUEST_URI} !^/\.well\-known/acme\-challenge/'>>$conf_dir/$site_name.conf;
    echo -e '    Options -Indexes +FollowSymLinks +MultiViews' >>$conf_dir/$site_name.conf;
    echo -e '    AllowOverride All' >>$conf_dir/$site_name.conf;
    echo -e '    Require all granted' >>$conf_dir/$site_name.conf;
    echo -e '  </Directory>\n' >>$conf_dir/$site_name.conf;
    echo -e '  ErrorLog ${APACHE_LOG_DIR}/error.log' >>$conf_dir/$site_name.conf;
    echo -e '  CustomLog ${APACHE_LOG_DIR}/access.log combined' >>$conf_dir/$site_name.conf;
    echo -e '</VirtualHost>' >>$conf_dir/$site_name.conf;
    if [ ! -f $sites_apache/$site_name.conf ]; then
      ln -s $conf_dir/$site_name.conf $sites_apache/$site_name.conf
    fi
  fi

  ## nginx config
  if [[ "$opt" != "" ]] && [[ $opt != "apache" ]] && [[ "$opt" == "nginx" ]]; then
    echo >$conf_dir/$site_name.conf;
    echo -e 'server { listen 0.0.0.0:'"$site_port"';' >>$conf_dir/$site_name.conf;
    echo -e '  server_name '"$site_name"';' >>$conf_dir/$site_name.conf;
    echo -e '  location /.well-known/acme-challenge {' >>$conf_dir/$site_name.conf;
    echo -e '    allow all;' >>$conf_dir/$site_name.conf;
    echo -e '    autoindex off;' >>$conf_dir/$site_name.conf;
    echo -e '    default_type "text/plain";' >>$conf_dir/$site_name.conf;
    echo -e '    root '"$web_dir"';' >>$conf_dir/$site_name.conf;
    echo -e '  }' >>$conf_dir/$site_name.conf;
    echo -e '  location = /.well-known {' >>$conf_dir/$site_name.conf;
    echo -e '    return 404;' >>$conf_dir/$site_name.conf;
    echo -e '  }' >>$conf_dir/$site_name.conf;
    echo -e '  error_page 404 /404.html;' >>$conf_dir/$site_name.conf;
    echo -e '  error_page 500 502 503 504 /50x.html;\n' >>$conf_dir/$site_name.conf;
    echo -e '  error_log /var/log/nginx/err-certbot.log;' >>$conf_dir/$site_name.conf;
    echo -e '  access_log /var/log/nginx/access-certbot.log;' >>$conf_dir/$site_name.conf;
    echo -e '}' >>$conf_dir/$site_name.conf;
    if [ ! -f $sites_nginx/$site_name.conf ]; then
      ln -s $conf_dir/$site_name.conf $sites_nginx/$site_name.conf
    fi
  fi
done
}

##--@F restart services
function updateScs(){
if [[ "${services[@]}" != "" ]] && [[ "${#services[@]}" != "0" ]]; then
  for ((scn=0; scn != ${#services[@]}; scn++)); do
     systemctl restart ${services[$scn]};
  done
fi
}

##--@F help
function pHelp(){
echo "$sname:$version"
echo "please input pameters: avto4certbot.sh --create [apache & nginx && proxy]| --update [apache & nginx] | --flist [apache & nginx]";
echo "avto4certbot.sh --create; create new certificate or --create [apache & nginx && proxy]; create new certificate " 
echo "avto4certbot.sh --update; update certificates or --update [apache & nginx && proxy]; update [apache & nginx];"
echo "avto4certbot.sh --flist; update certificates from ssl or --flist [apache & nginx && proxy]; rescan list certificates;"
echo "avto4certbot.sh --help; this help"
echo "* examples:"
echo "  avtocertbot.sh --update apache"
echo "  or"
echo "  avtocertbot.sh --update nginx"
echo "  or"
echo "  avtocertbot.sh --update apache proxy"
}

case "$cmd" in
  ## create cert
  "--create" | "--create" )
if [ "$opt" != "" ]; then
    getInfo;
    checkDep;
    event_key="1";
    if [ "$sw_proxy" == "proxy" ]; then
      if [[ "$http_proxy" != "" ]] && [[ "$(systemctl list-units|grep "$http_proxy"|wc -m)" != "0" ]]; then
        systemctl stop $http_proxy
        createConf;
        systemctl start $web_service;
        sleep 2;
        createCert;
        scanSSL;
        event_key="0";
        systemctl stop $web_service;
        swSites;
        updateScs;
        systemctl start $http_proxy
      else
        reports=()
        reports[${#reports[@]}]="Sorry, there are not found proxy: $http_proxy"
        makeErr
        exit
      fi
    else
      systemctl stop $web_service;
      swSites;
      createConf;
      systemctl start $web_service;
      sleep 2;
      createCert;
      scanSSL;
      event_key="0";
      systemctl stop $web_service;
      swSites;
      systemctl start $web_service;
      updateScs;
    fi
else
    pHelp;
fi
  ;;

  ## update cert
  "--update" | "--update" )
if [ "$opt" != "" ]; then
  getInfo;
  checkDep;
  event_key="1";
  if [ "$sw_proxy" == "proxy" ]; then
    if [[ "$http_proxy" != "" ]] && [[ "$(systemctl list-units|grep "$http_proxy"|wc -m)" != "0" ]]; then
      systemctl stop $http_proxy
      createConf;
      systemctl start $web_service;
      sleep 2;
      certbot -n renew;
      scanSSL;
      event_key="0";
      systemctl stop $web_service;
      swSites;
      updateScs;
      systemctl start $http_proxy
    else
      reports=()
      reports[${#reports[@]}]="Sorry, there are not found proxy: $http_proxy"
      makeErr
      exit
    fi
  else
    systemctl stop $web_service;
    swSites;
    createConf;
    systemctl start $web_service;
    sleep 2;
    certbot -n renew;
    scanSSL;
    event_key="0";
    systemctl stop $web_service;
    swSites;
    systemctl start $web_service;
    updateScs;
  fi
else
    pHelp;
fi
  ;;

  ## create cert
  "--flist" | "--flist" )
if [ "$opt" != "" ]; then
  getInfo;
  checkDep;
  if [ "$sw_proxy" == "proxy" ]; then
    if [[ "$http_proxy" != "" ]] && [[ "$(systemctl list-units|grep "$http_proxy"|wc -m)" != "0" ]]; then
      flistCerts;
      systemctl restart $http_proxy
      updateScs;
    else
        reports=()
        reports[${#reports[@]}]="Sorry, there are not found proxy: $http_proxy"
        makeErr
        exit
    fi
  else
      flistCerts;
      systemctl restart $web_service;
      updateScs;
  fi
else
    pHelp;
fi
  ;;

  ## start defaults
  * )
    pHelp;
    ;;
  esac

exit
