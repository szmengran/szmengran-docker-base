#!/bin/bash

#eurekaHost='eureka-server.mdw'
#
#if [[ "$ACTIVE_PROFILE" == "test" ]]; then
#    curl -XPUT "http://$eurekaHost/eureka/apps/$(hostname)/$POD_NAMESPACE:$POD_IP/status?value=UP"
#else
#    curl -XPUT "http://$eurekaHost/eureka/apps/$(hostname)/$POD_IP:8080/status?value=UP"
#fi

#set -x

curl -k -XPATCH -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" -H "Content-Type: application/merge-patch+json" -H "Accept: application/json" "https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/v1/namespaces/$POD_NAMESPACE/pods/$POD_NAME" -d '{"metadata":{"labels":{"offline":null}}}' > /data/dubbo/$(hostname)/log/pod-online.log

cat /data/dubbo/$(hostname)/log/pod-online.log

curl -XPOST "http://localhost:8088/actuator/nacos-register" > /data/dubbo/$(hostname)/log/nacos-online.log

cat /data/dubbo/$(hostname)/log/nacos-online.log
