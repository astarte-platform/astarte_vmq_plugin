#!/usr/bin/env bash

IP_ADDRESS=$(ip -4 addr show eth0 | grep -oP "(?<=inet).*(?=/)"| sed -e "s/^[[:space:]]*//" | tail -n 1)

# Ensure the Erlang node name is set correctly
if env | grep -q "DOCKER_VERNEMQ_NODENAME"; then
    sed -i.bak -r "s/VerneMQ@.+/VerneMQ@${DOCKER_VERNEMQ_NODENAME}/" /opt/vernemq/etc/vm.args
else
    sed -i.bak -r "s/VerneMQ@.+/VerneMQ@${IP_ADDRESS}/" /opt/vernemq/etc/vm.args
fi

if env | grep -q "DOCKER_VERNEMQ_DISCOVERY_NODE"; then
    echo "-eval \"vmq_server_cmd:node_join('VerneMQ@${DOCKER_VERNEMQ_DISCOVERY_NODE}')\"" >> /opt/vernemq/etc/vm.args
fi

if env | grep -q "DISCOVERY_KUBERNETES"; then
    # Let's set our nodename correctly
    VERNEMQ_KUBERNETES_SUBDOMAIN=$(curl -X GET --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt https://kubernetes.default.svc.cluster.local/api/v1/namespaces/$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)/pods?labelSelector=app=vernemq -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" | jq '.items[0].spec.subdomain' | sed 's/"//g' | tr '\n' '\0')
    VERNEMQ_KUBERNETES_HOSTNAME=$MY_POD_NAME.$VERNEMQ_KUBERNETES_SUBDOMAIN.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local
    
    sed -i.bak -r "s/VerneMQ@.+/VerneMQ@${VERNEMQ_KUBERNETES_HOSTNAME}/" /opt/vernemq/etc/vm.args
    # Hack into K8S DNS resolution (temporarily)
    kube_pod_names=$(curl -X GET --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt https://kubernetes.default.svc.cluster.local/api/v1/namespaces/$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)/pods?labelSelector=app=vernemq -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" | jq '.items[].spec.hostname' | sed 's/"//g' | tr '\n' ' ')
    for kube_pod_name in $kube_pod_names;
    do
        if [ $kube_pod_name == "null" ]
            then
                echo "Kubernetes discovery selected, but no pods found. Maybe we're the first?"
                echo "Anyway, we won't attempt to join any cluster."
                break
        fi
        if [ $kube_pod_name != $MY_POD_NAME ]
            then
                echo "Will join an existing Kubernetes cluster with discovery node at $kube_pod_name.$VERNEMQ_KUBERNETES_SUBDOMAIN.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local"
                echo "-eval \"vmq_server_cmd:node_join('VerneMQ@${kube_pod_name}.${VERNEMQ_KUBERNETES_SUBDOMAIN}.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local')\"" >> /opt/vernemq/etc/vm.args
                break
        fi
    done
fi

sed -i '/########## Start ##########/,/########## End ##########/d' /opt/vernemq/etc/vernemq.conf

echo "########## Start ##########" >> /opt/vernemq/etc/vernemq.conf

env | grep DOCKER_VERNEMQ | grep -v 'DISCOVERY_NODE\|DOCKER_VERNEMQ_USER' | cut -c 16- | sed "s/^[^=]*=/\L&/g" | sed 's/__/./g' >> /opt/vernemq/etc/vernemq.conf

users_are_set=$(env | grep DOCKER_VERNEMQ_USER)
if [ ! -z "$users_are_set" ]
    then
        touch /opt/vernemq/etc/vmq.passwd
fi

for vernemq_user in $(env | grep DOCKER_VERNEMQ_USER);
    do
        username=$(echo $vernemq_user | awk -F '=' '{ print $1 }' | sed 's/DOCKER_VERNEMQ_USER_//g' | tr '[:upper:]' '[:lower:]')
        password=$(echo $vernemq_user | awk -F '=' '{ print $2 }')
        /opt/vernemq/bin/vmq-passwd /opt/vernemq/etc/vmq.passwd $username <<EOF
$password
$password
EOF
    done

echo "erlang.distribution.port_range.minimum = 9100" >> /opt/vernemq/etc/vernemq.conf
echo "erlang.distribution.port_range.maximum = 9109" >> /opt/vernemq/etc/vernemq.conf
echo "listener.tcp.default = ${IP_ADDRESS}:1883" >> /opt/vernemq/etc/vernemq.conf
if env | grep -q "VERNEMQ_ENABLE_SSL_LISTENER"; then
    echo "listener.ssl.default = ${IP_ADDRESS}:8883" >> /opt/vernemq/etc/vernemq.conf
fi
# We enable the revproxy listener regardless.
echo "listener.tcp.revproxy = ${IP_ADDRESS}:1885" >> /opt/vernemq/etc/vernemq.conf
echo "listener.vmq.clustering = ${IP_ADDRESS}:44053" >> /opt/vernemq/etc/vernemq.conf
echo "listener.http.metrics = ${IP_ADDRESS}:8888" >> /opt/vernemq/etc/vernemq.conf

echo "########## End ##########" >> /opt/vernemq/etc/vernemq.conf

# Check configuration file
/opt/vernemq/bin/vernemq config generate 2>&1 > /dev/null | tee /tmp/config.out | grep error

if [ $? -ne 1 ]; then
    echo "configuration error, exit"
    echo "$(cat /tmp/config.out)"
    exit $?
fi

if env | grep -q "VERNEMQ_ENABLE_SSL_LISTENER"; then
    # Let's do our magic. First of all, let's ask for certificates.
    if ! curl -s -d '{"label": "primary"}' -X POST $CFSSL_URL/api/v1/cfssl/info | jq -e -r ".result.certificate" > /etc/ssl/cfssl-ca-cert.crt; then
        echo "Could not retrieve certificate from CFSSL at $CFSSL_URL , exiting"
        exit $?
    fi
    if env | grep -q "USE_LETSENCRYPT"; then
        # TODO: Make this rotate in case we're using Let's encrypt
        echo "You have chosen Let's encrypt as the deploy mechanism - this means clustering Verne is impossible!"
        # Ensure certbot, first of all
        echo 'deb http://ftp.debian.org/debian jessie-backports main' | tee /etc/apt/sources.list.d/backports.list
        apt-get update
        apt-get -qq install nginx-light
        /etc/init.d/nginx start
        if ! apt-get -qq install certbot -t jessie-backports; then
            echo "Could not install certbot, exiting"
            exit $?
        fi
        # Obtain certificate
        if env | grep -q "LETSENCRYPT_STAGING"; then
            echo "Using staging Let's Encrypt - certificate won't be valid!"
            certbot_staging=--test-cert
        fi
        if ! certbot certonly -n $certbot_staging --webroot --webroot-path=/var/www/html --agree-tos --email $LETSENCRYPT_EMAIL --domains $LETSENCRYPT_DOMAINS; then
            echo "Certbot failed, exiting"
            exit $?
        fi
        /etc/init.d/nginx stop &
        letsencrypt_dir=/etc/letsencrypt/live/${LETSENCRYPT_DOMAINS%,*}
        # Then we copy our private key and certificate.
        cp $letsencrypt_dir/privkey.pem /opt/vernemq/etc/privkey.pem || exit 1
        cp $letsencrypt_dir/fullchain.pem /opt/vernemq/etc/cert.pem || exit 1
        # And now we merge.
        cat $letsencrypt_dir/fullchain.pem /etc/ssl/cfssl-ca-cert.crt > /opt/vernemq/etc/ca.pem
    else
        # Then we copy our private key and certificate. We assume there's a mount at /etc/ssl/vernemq-certs
        cp /etc/ssl/vernemq-certs/privkey /opt/vernemq/etc/privkey.pem || exit 1
        cp /etc/ssl/vernemq-certs/cert /opt/vernemq/etc/cert.pem || exit 1
        # And now we merge.
        cat /etc/ssl/vernemq-certs/cert /etc/ssl/cfssl-ca-cert.crt > /opt/vernemq/etc/ca.pem
    fi
fi

pid=0

# SIGUSR1-handler
siguser1_handler() {
    echo "stopped"
}

# SIGTERM-handler
sigterm_handler() {
    if [ $pid -ne 0 ]; then
        # this will stop the VerneMQ process
        /opt/vernemq/bin/vmq-admin cluster leave node=VerneMQ@$IP_ADDRESS -k > /dev/null
        wait "$pid"
    fi
    exit 143; # 128 + 15 -- SIGTERM
}

# setup handlers
# on callback, kill the last background process, which is `tail -f /dev/null`
# and execute the specified handler
trap 'kill ${!}; siguser1_handler' SIGUSR1
trap 'kill ${!}; sigterm_handler' SIGTERM

if ! /opt/vernemq/bin/vernemq start; then
    echo "Could not start VerneMQ!"
    cat /opt/vernemq/log/console.log
    exit $?
fi
pid=$(ps aux | grep '[b]eam.smp' | awk '{print $2}')

while true
do
    tail -f /opt/vernemq/log/console.log & wait ${!}
done