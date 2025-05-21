#!/bin/bash

base=$(dirname "$0")

for i in "$@"
do
case $i in
    # app is pass by yml, can be diff from APP
    --app=*)
    app="${i#*=}"
    shift # past argument=value
    ;;
    --run-test=*)
    run_test="${i#*=}"
    shift # past argument=value
    ;;
    --beta)
    beta="true"
    shift # past argument with no value
    ;;
    *)
          # unknown option
    ;;
esac
done

if [[ "${run_test}" == "true" ]]; then
    cd ${base}

    ./kubectl config set-cluster kubernetes \
      --certificate-authority=/run/secrets/kubernetes.io/serviceaccount/ca.crt \
      --embed-certs=true \
      --server=https://${KUBERNETES_SERVICE_HOST}

    ./kubectl config set-credentials me --token=$(cat /run/secrets/kubernetes.io/serviceaccount/token)

    ./kubectl config set-context kubernetes \
      --cluster=kubernetes \
      --namespace=$(cat /run/secrets/kubernetes.io/serviceaccount/namespace) \
      --user=me

    ./kubectl config use-context kubernetes

    if [[ -z "${app}" ]]; then
        app=${APP}
    fi

    ./kubectl rollout status deploy/${app}

    build_user=$(grep git.build.user.email /app/classes/git.properties)

    build_user=${build_user#git.build.user.email=}

    curl -XPOST http://docker-env-cleaner.base:8080/run-smokeTest

fi

