#!/bin/bash

#set -euo pipefail

_me=$(basename "$0")

_CFG=""
_CMD=""
_CSV_NAME=""

#--------------------------------------------------------
_CLR_RED="\033[0;31m"   #'0;31' is Red's ANSI color code
_CLR_GREEN="\033[0;32m"   #'0;32' is Green's ANSI color code
_CLR_YELLOW="\033[1;33m"   #'1;32' is Yellow's ANSI color code
_CLR_BLUE="\033[0;34m"   #'0;34' is Blue's ANSI color code
_CLR_NC="\033[0m"

#--------------------------------------------------------
_INST_TMP_FOLDER="/tmp"
setTemporaryFolder () {
  _OK=0
  _ERR_MSG_FOLDER="is a folder"
  _ERR_MSG_PERMISSIONS=""
  if [[ ! -z "${CP4BA_INST_TMP_FOLDER}" ]]; then
    if [[ -d "${CP4BA_INST_TMP_FOLDER}" ]]; then
      if [[ -r "${CP4BA_INST_TMP_FOLDER}" ]] && [[ -w "${CP4BA_INST_TMP_FOLDER}" ]]; then 
        _OK=1
      else
        _ERR_MSG_PERMISSIONS=", you have not rights to read and/or write"
        _OK=-1
      fi
    else
      _ERR_MSG_FOLDER="is NOT a folder"
    fi

    if [[ $_OK -lt 1 ]]; then
      echo -e "${_CLR_RED}[✗] ERROR '${_CLR_YELLOW}${CP4BA_INST_TMP_FOLDER}${_CLR_RED}' is not a valid temporary folder, check if it is a folder or if you have write permissions !${_CLR_NC}"
      echo -e "${_CLR_RED} '${_CLR_YELLOW}${CP4BA_INST_TMP_FOLDER}${_CLR_RED}' ${_ERR_MSG_FOLDER}${_ERR_MSG_PERMISSIONS}${_CLR_NC}"
      exit 1
    fi
    export _INST_TMP_FOLDER="${CP4BA_INST_TMP_FOLDER}"
  fi
  log_info "${_CLR_GREEN}Running with temporary folder '${_CLR_YELLOW}${_INST_TMP_FOLDER}${_CLR_GREEN}'${_CLR_NC}"

}

#--------------------------------------------------------
# read command line params
while getopts c:k: flag
do
    case "${flag}" in
        c) _CFG=${OPTARG};;
        k) _CMD=${OPTARG};;
    esac
done

usage() {
  echo "usage: $_me -c path-of-config-file -k [install|remove]"
}

if [[ -z "${_CFG}" ]]; then
  usage 
  exit 1
fi

source "${_CFG}" 2>/dev/null 1>/dev/null

#----------------------------------------------------
_SCRIPT_PATH="${BASH_SOURCE}"
while [ -L "${_SCRIPT_PATH}" ]; do
  _SCRIPT_DIR="$(cd -P "$(dirname "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"
  _SCRIPT_PATH="$(readlink "${_SCRIPT_PATH}")"
  [[ ${_SCRIPT_PATH} != /* ]] && _SCRIPT_PATH="${_SCRIPT_DIR}/${_SCRIPT_PATH}"
done
_SCRIPT_PATH="$(readlink -f "${_SCRIPT_PATH}")"
_SCRIPT_DIR="$(cd -P "$(dirname -- "${_SCRIPT_PATH}")" >/dev/null 2>&1 && pwd)"

#----------------------------------------------------
if [[ ! -f "$_SCRIPT_DIR/../../cp4ba-logger/scripts/logger.sh" ]]; then
  echo "Error, log package not found !"
  echo "Clone it alongside with other cp4ba-..."
  echo "use the command: git clone https://github.com/marcoantonioni/cp4ba-logger"
  exit 1
fi
source $_SCRIPT_DIR/../../cp4ba-logger/scripts/logger.sh
if [[ -z "${CP4BA_LOGGING_ENABLED}" ]]; then 
  export CP4BA_LOGGING_ENABLED=true
fi
if [[ -z "${CP4BA_LOG_LEVEL}" ]]; then 
  export CP4BA_LOG_LEVEL="INFO"
fi
if [[ -z "${CP4BA_LOG_TO_CONSOLE}" ]]; then 
  export CP4BA_LOG_TO_CONSOLE=true
fi
if [[ -z "${CP4BA_LOG_TO_FILE}" ]]; then 
  export CP4BA_LOG_TO_FILE=false
fi
if [[ -z "${CP4BA_LOG_FILE}" ]]; then 
  export CP4BA_LOG_FILE=""
fi
if [[ -z "${CP4BA_LOG_MAX_SIZE}" ]]; then 
  export CP4BA_LOG_MAX_SIZE=$((10 * 1024 * 1024))
fi
if [[ -z "${CP4BA_LOG_BACKUP_COUNT}" ]]; then 
  export CP4BA_LOG_BACKUP_COUNT=5
fi

#-------------------------------
resourceExist () {
#    echo "namespace name: $1"
#    echo "resource type: $2"
#    echo "resource name: $3"
  if [ $(oc get $2 -n $1 $3 2> /dev/null | grep $3 2>/dev/null | wc -l) -lt 1 ];
  then
      return 0
  fi
  return 1
}

#-----------------------------------------------------------------
createTLSCertificate() {

  _TLS_ISSUER=$(oc get issuers.cert-manager.io -n $CP4BA_INST_NAMESPACE opensearch-tls-issuer --no-headers | wc -l)
  if [[ $_TLS_ISSUER -eq 0 ]]; then
    log_error "No 'opensearch-tls-issuer' found, cannot procede."
    exit 1
  fi

  _CPD_FQDN=$(oc get route -n ${CP4BA_INST_NAMESPACE} cpd -o jsonpath="{.spec.host}")
  IFS="." read -r skipIt1 skipIt2 _CLUSTER_DOMAIN <<< "${_CPD_FQDN}"
  unset IFS

if [[ ! -z "${_CLUSTER_DOMAIN}" ]]; then

cat <<EOF | oc create -f - 2>/dev/null 1>/dev/null
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${CP4BA_INST_OPENSEARCH_CUSTOM_CERT_NAME}
  namespace: ${CP4BA_INST_NAMESPACE}
  labels:
    app.kubernetes.io/created-by: ibm-opensearch-operator
    app.kubernetes.io/instance: single
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: cluster
    app.kubernetes.io/part-of: ibm-opensearch-operator
spec:
  commonName: Cluster
  dnsNames:
    - '*.cluster.local'
    - '*.svc.cluster.local'
    - localhost
    - 127.0.0.1
    - ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}-${CP4BA_INST_NAMESPACE}.apps.${_CLUSTER_DOMAIN}
    - ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}
    - ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}.${CP4BA_INST_NAMESPACE}
    - ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}.${CP4BA_INST_NAMESPACE}.svc
    - ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}.${CP4BA_INST_NAMESPACE}.svc.cluster.local
    - ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}-all
    - ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}-all.${CP4BA_INST_NAMESPACE}
    - ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}-all.${CP4BA_INST_NAMESPACE}.svc
    - ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}-all.${CP4BA_INST_NAMESPACE}.svc.cluster.local
  duration: ${CP4BA_INST_OPENSEARCH_CUSTOM_CERT_DURATION}
  issuerRef:
    kind: Issuer
    name: opensearch-tls-issuer  # Reused from CP4BA deployment (uses icp4a-root-ca certificate)
  privateKey:
    algorithm: RSA
    encoding: PKCS8
    size: 2048
  renewBefore: ${CP4BA_INST_OPENSEARCH_CUSTOM_CERT_RENEW_BEFORE}
  secretName: ${CP4BA_INST_OPENSEARCH_CUSTOM_CERT_SECRET_NAME}
  usages:
    - cert sign
    - signing
    - digital signature
    - key encipherment
    - server auth
    - client auth
EOF

else
  log_error "Cannot obtain cluster domain name from 'cpd' route."
  exit 1
fi

}

#-----------------------------------------------------------------
createAdminSecret() {

  oc create secret generic -n ${CP4BA_INST_NAMESPACE} ${CP4BA_INST_OPENSEARCH_CUSTOM_ADMIN_SECRET_NAME} --from-literal=opensearch-admin="${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_ADMIN_PASSWORD}" 2>/dev/null 1>/dev/null
}

#-----------------------------------------------------------------
createOpenSearchCluster() {

_OS_CTR_ENV=$(oc get ClusterServiceVersion -n ${CP4BA_INST_NAMESPACE} ${_CSV_NAME} -o jsonpath="{.spec.install.spec.deployments[0].spec.template.spec.containers[0].env}")

_OS_VER=$(echo ${_OS_CTR_ENV} | jq '.[] | select(.name=="OPENSEARCH_VERSION")' | jq .value | sed 's/"//g')
_OS_SEC_VER=$(echo ${_OS_CTR_ENV} | jq '.[] | select(.name=="OPENSEARCH_SECURITY_VERSION")' | jq .value | sed 's/"//g')
_OS_KNN_VER=$(echo ${_OS_CTR_ENV} | jq '.[] | select(.name=="OPENSEARCH_PLUGIN_KNN_VERSION")' | jq .value | sed 's/"//g')

cat <<EOF | oc create -f - 2>/dev/null 1>/dev/null
apiVersion: opensearch.cloudpackopen.ibm.com/v1
kind: Cluster
metadata:
  annotations:
    productID: 068a62892a1e4db39641342e592daa25
    productMetric: FREE
    productName: IBM Cloud Platform Common Services
  name: ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}
  namespace: ${CP4BA_INST_NAMESPACE}
  labels:
    app.kubernetes.io/created-by: ibm-opensearch-operator
    app.kubernetes.io/instance: single
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: cluster
    app.kubernetes.io/part-of: ibm-opensearch-operator
spec:
  backup:
    brConfigmapPriority: 100
    checkpointConfigmapPriority: 100
    enable: true
    sizeLimit: 50Gi
    snapshotPVC: ''
    snapshotPVCStorageClass: ${CP4BA_INST_SC_FILE}
    snapshotWhitelistIndices: ''
  enableDefaultNetworkPolicy: true
  license:
    accept: true
  nodePools:
    - resources:
        limits:
          cpu: '2'
          ephemeral-storage: 5Gi
          memory: 2Gi
        requests:
          cpu: 500m
          ephemeral-storage: 10Mi
          memory: 820Mi
      opensearchyml: |
        plugins.security.ssl.http.enabled: true
        plugins.security.allow_default_init_securityindex: true
        plugins.security.restapi.roles_enabled: ["all_access", "security_rest_api_access"]
        plugins.security.unsupported.restapi.allow_securityconfig_modification: true
        http.compression: false
        plugins.security.ssl.http.clientauth_mode: OPTIONAL
        plugins.security.authcz.admin_dn: [CN=Cluster]
        knn.memory.circuit_breaker.enabled: true  # Required for k-NN plugin
        knn.memory.circuit_breaker.limit: 50%
        action.auto_create_index: "+ibm-genai-*,-*"
      name: all
      captureContainerLogLimit: 30
      enableInstanaMetricCollection: false
      resetUsers: false  # CRITICAL: Prevents user data loss during pod restarts
      storage:
        data:
          sizeLimit: 50Gi  # Adjust based on sizing requirements
          storageClass: ${CP4BA_INST_SC_FILE}
          useEphemeral: false
        deployment:
          sizeLimit: 10Gi
          storageClass: ${CP4BA_INST_SC_FILE}
          useEphemeral: false
      replicas: 3  # Adjust based on sizing requirements
  plugins:
    security:
      enabled: true
      httpCertificateSecret: ${CP4BA_INST_OPENSEARCH_CUSTOM_CERT_SECRET_NAME}
      internalUserSecret: ${CP4BA_INST_OPENSEARCH_CUSTOM_ADMIN_SECRET_NAME}
      version: ${_OS_SEC_VER}
    knn:
      enabled: true  # REQUIRED for vector search capabilities
      version: ${_OS_KNN_VER}
    mapperSize: false
    queryInsights: false
    mapperAnnotatedText: false
    analysisKuromoji: false
    discoveryEc2: false
    telemetryOtel: false
    storeSMB: false
    ingestAttachment: false
    repositoryS3: true
    transportReactorNetty4: false
    transportNio: false
    cryptoKms: false
    analysisUkrainian: false
    mapperMurmur3: false
    discoveryAzureClassic: false
    identityShiro: false
    analysisNori: false
    analysisSmartcn: false
    discoveryGce: false
    analysisStempe: false
    analysisPhonetic: false
    cacheEhcache: false
    analysisICU: false
  quiesce: false
  serviceAccount: ''
  version: ${_OS_VER}
EOF

}

#-----------------------------------------------------------------
waitOpenSearchClusterReady() {
  while true;
  do
    _OS_AVAILABLE=$(oc get clusters.opensearch.cloudpackopen.ibm.com -n ${CP4BA_INST_NAMESPACE} ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME} --no-headers -o jsonpath="{.status.phase}" | sed 's/"//g')

    if [[ "${_OS_AVAILABLE}" = "Available" ]]; then
      break
    else
      sleep 1  
    fi
  done

  _NUM_POD_READY=0
  while [[ $_NUM_POD_READY -lt 3 ]]
  do
    sleep 1
    _NUM_POD_READY=$(oc get pod -n ${CP4BA_INST_NAMESPACE} | grep ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME} | grep Running | wc -l)

  done

  _SERVICE=0
  while [[ $_SERVICE -lt 1 ]]
  do
    sleep 1
    _SERVICE=$(oc get svc ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME} -n ${CP4BA_INST_NAMESPACE} --no-headers | wc -l)

  done

}

#-----------------------------------------------------------------
openSearchSetupClusterResources() {
  if [[ "${CP4BA_INST_OPENSEARCH_CUSTOM_INSTALL}" = "true" ]]; then
    _CSV_NAME=$(oc get ClusterServiceVersion -n ${CP4BA_INST_NAMESPACE} --no-headers | grep ibm-opensearch-operator | awk '{print $1}')

    if [[ -z "${_CSV_NAME}" ]]; then
      log_error "Cannot install cluster without IBM operator 'ibm-opensearch-operator' in namespace '${CP4BA_INST_NAMESPACE}'"  
      exit 1
    fi

    createTLSCertificate
    createAdminSecret
    createOpenSearchCluster
    waitOpenSearchClusterReady
  else
    log_error "OpenSearch custom cluster not configured, set CP4BA_INST_OPENSEARCH_CUSTOM_INSTALL=true"
  fi
}

#-----------------------------------------------------------------
openSearchDeleteClusterResources() {
  resourceExist ${CP4BA_INST_NAMESPACE} "clusters.opensearch.cloudpackopen.ibm.com" ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}
  if [ $? -eq 1 ]; then
    oc delete clusters.opensearch.cloudpackopen.ibm.com -n ${CP4BA_INST_NAMESPACE} ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME} 2>/dev/null 1>/dev/null

    _CRD_EXISTS=1
    while [[ $_CRD_EXISTS -eq 1 ]]  
    do
      sleep 1
      _CRD_EXISTS=$(oc get clusters.opensearch.cloudpackopen.ibm.com -n ${CP4BA_INST_NAMESPACE} ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME} --no-headers 2>/dev/null | wc -l)

    done
    sleep 3
    oc delete certificate -n ${CP4BA_INST_NAMESPACE} ${CP4BA_INST_OPENSEARCH_CUSTOM_CERT_NAME} 2>/dev/null 1>/dev/null
    oc delete secret -n ${CP4BA_INST_NAMESPACE} ${CP4BA_INST_OPENSEARCH_CUSTOM_CERT_SECRET_NAME} 2>/dev/null 1>/dev/null
    oc delete secret -n ${CP4BA_INST_NAMESPACE} ${CP4BA_INST_OPENSEARCH_CUSTOM_ADMIN_SECRET_NAME} 2>/dev/null 1>/dev/null
    oc delete secret -n ${CP4BA_INST_NAMESPACE} ${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME} 2>/dev/null 1>/dev/null
  else
    log_warning "OpenSearch cluster '${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}' doesn't exists."
  fi 
}

log_msg "=============================================================="
setTemporaryFolder

if [[ "${_CMD}" = "install" ]]; then
  log_info "${_CLR_GREEN}Creating custom Opensearch cluster '${_CLR_YELLOW}${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}${_CLR_GREEN}' in '${_CLR_YELLOW}${CP4BA_INST_NAMESPACE}${_CLR_GREEN}' namespace${_CLR_NC}"
  openSearchSetupClusterResources
  log_info "${_CLR_GREEN}Opensearch cluster '${_CLR_YELLOW}${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}${_CLR_GREEN}' is ready.${_CLR_NC}"
else
  if [[ "${_CMD}" = "remove" ]]; then
    log_info "${_CLR_GREEN}Removing custom Opensearch cluster '${_CLR_YELLOW}${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}${_CLR_GREEN}' from '${_CLR_YELLOW}${CP4BA_INST_NAMESPACE}${_CLR_GREEN}' namespace${_CLR_NC}"
    openSearchDeleteClusterResources
  log_info "${_CLR_GREEN}Opensearch cluster '${_CLR_YELLOW}${CP4BA_INST_OPENSEARCH_CUSTOM_CLUSTER_NAME}${_CLR_GREEN}' no longer exists.${_CLR_NC}"
  else
    log_error "Command -k not valid"
    usage
    exit 1
  fi
fi
exit 0
