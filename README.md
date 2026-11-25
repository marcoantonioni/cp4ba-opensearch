# cp4ba-opensearch

Custom OpenSearch cluster installation using CP4BA ibm-opensearch-operator

This tool is an automated sequence of steps as from

https://www.ibm.com/docs/en/cacms/1.0.x?topic=o2iocfcdus-optional-installing-opensearch-cluster-from-cp4ba-deployment-manually


## Install examples

Install custom cluster
```bash
_PTC=/home/$USER/cp4ba-projects/cp4ba-installations/configs26
CONFIG_FILE=${_PTC}/env1-authoring-baw-cacms.properties
./cp4ba-opensearch-setup-cluster.sh -c ${CONFIG_FILE} -k install
```

### Post installation test

Assuming 'my-opensearch' the opensearch cluster name and 'cp4ba-opensearch-prod' the namespace 

```bash
oc exec -it my-opensearch-all-000 -n cp4ba-opensearch-prod -- curl -k -u opensearch-admin:dem0s-Dem0s -X GET "https://my-opensearch.cp4ba-opensearch-prod.svc.cluster.local:9200"
```

expected result
```json
{
  "name" : "my-opensearch-all-000",
  "cluster_name" : "my-opensearch",
  "cluster_uuid" : "pE3bk2_EQZW2HoHopH67-Q",
  "version" : {
    "distribution" : "opensearch",
    "number" : "3.7.0",
    "build_type" : "tar",
    "build_hash" : "72121f014083f9ca010fd5a7da83b2ec4886027f",
    "build_date" : "2026-09-29T08:08:07.107729842Z",
    "build_snapshot" : false,
    "lucene_version" : "10.4.0",
    "minimum_wire_compatibility_version" : "2.19.0",
    "minimum_index_compatibility_version" : "2.0.0"
  },
  "tagline" : "The OpenSearch Project: https://opensearch.org/"
}
```

## Uninstall examples

Remove custom cluster
```bash
_PTC=/home/$USER/cp4ba-projects/cp4ba-installations/configs26
CONFIG_FILE=${_PTC}/env1-runtime-opensearch-foundation.properties
./cp4ba-opensearch-setup-cluster.sh -c ${CONFIG_FILE} -k remove
```


## OpenSearch Dashboard

TBD

