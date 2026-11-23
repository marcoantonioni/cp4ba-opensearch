# cp4ba-opensearch

## Installation steps

This tool is an automated sequence of steps as from

https://www.ibm.com/docs/en/cacms/1.0.x?topic=o2iocfcdus-optional-installing-opensearch-cluster-from-cp4ba-deployment-manually

Install custom cluster
```bash
_PTC=/home/$USER/cp4ba-projects/cp4ba-installations/configs26
CONFIG_FILE=${_PTC}/env1-runtime-opensearch-foundation.properties
./cp4ba-opensearch-setup-cluster.sh -c ${CONFIG_FILE} -k install
```

Remove custom cluster
```bash
_PTC=/home/$USER/cp4ba-projects/cp4ba-installations/configs26
CONFIG_FILE=${_PTC}/env1-runtime-opensearch-foundation.properties
./cp4ba-opensearch-setup-cluster.sh -c ${CONFIG_FILE} -k remove
```


## OpenSearch Dashboard

TBD

