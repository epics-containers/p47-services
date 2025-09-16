#!/bin/bash

# log commands and stop on errors
set -xe

# wrap this script in stdio-expose if running in Kubernetes
# this allows the IOC to expose its console on a Unix socket
if [[ -n ${KUBERNETES_PORT} && -z ${STDIO_EXPOSED} ]]; then
    STDIO_EXPOSED=YES stdio-expose ${IOC}/start.sh
    exit 0
fi


# error reporting *************************************************************

function ibek_error {
    echo "${1}"

    # Wait for a bit so the container does not exit and restart continually
    sleep 120
}

# environment setup ************************************************************


cd ${IOC}
CONFIG_DIR=${IOC}/config

# add module paths to environment for use in ioc startup script
if [[ -f ${SUPPORT}/configure/RELEASE.shell ]]; then
source ${SUPPORT}/configure/RELEASE.shell
fi

# folder for runtime assets
export RUNTIME_DIR=${EPICS_ROOT}/runtime
mkdir -p ${RUNTIME_DIR}

# query gigE cameras for configuration parameters
readarray entities < <(yq -o=j -I=0 '.entities[]' ${ibek_src})
for ((count = 0 ; count < ${#entities[@]} ; count++ ))  # Interate over each entity
do
    instance_type=$(yq .entities[${count}].type ${ibek_src})
    if [ $instance_type = "ADAravis.aravisCamera" ]
    then
        instance_class=$(yq .entities[${count}].CLASS ${ibek_src})
        instance_id=$(yq .entities[${count}].ID ${ibek_src})

        if [[ $instance_class == "AutoADGenICam" ]]; then
            instance_class=auto-${instance_id}
            # Auto generate GenICam database from camera parameters XML
            arv-tool-0.8 -a ${instance_id} genicam > /tmp/${instance_id}-genicam.xml
            if [[ ! -s /tmp/${instance_id}-genicam.xml ]]; then
                # can't contact the camera - make an empty template
                echo "Can't connect to camera ${instance_id}"
                touch /epics/support/ADGenICam/db/${instance_class}.template
            else
                # make a db file from the GenICam XML
                python /epics/support/ADGenICam/scripts/makeDb.py /tmp/${instance_id}-genicam.xml /epics/support/ADGenICam/db/${instance_class}.template
            fi
        fi
        # Generate pvi device from the GenICam DB
        template=/epics/support/ADGenICam/db/$instance_class.template
        pvi convert device --template $template --name $instance_class --label "GenICam $instance_id" /epics/pvi-defs/
    fi
done

defs=()
defs+=(find /epics/ibek-defs/ -name '*.ibek.support.yaml')
defs+=(find /epics/ioc/config -name '*.ibek.support.yaml')
cat /epics/ioc/config/ioc.yaml /epics/ioc/config/runtime.yaml > ${RUNTIME_DIR}/all_ioc.yaml

# prepare the runtime assets: ioc.db, st.cmd + protocol, autosave files
ibek runtime generate ${RUNTIME_DIR}/all_ioc.yaml ${defs}
ibek runtime generate-autosave
if [[ -d /epics/support/configure/protocol ]] ; then
    rm -fr ${RUNTIME_DIR}/protocol
    cp -r /epics/support/configure/protocol  ${RUNTIME_DIR}
fi

# expand the generated substitution file
includes=$(for i in ${SUPPORT}/*/db; do echo -n "-I $i "; done)
bash -c "msi -o${epics_db} ${includes} -I${RUNTIME_DIR} -S${db_src}"



# Execute the IOC binary and pass the startup script as an argument
${IOC}/bin/linux-x86_64/ioc ${final_ioc_startup}


