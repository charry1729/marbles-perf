#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
# http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

################################################################################
#
#   simple entrypoint script for hyperledger fabric
#
################################################################################

BROADCAST_MSG() {
  local MESSAGE=$1

  echo
  echo "======================================================================="
  echo "   > ${MESSAGE}"
  echo "======================================================================="
  echo
}

ENROLL_CLIENT() {
  BROADCAST_MSG "ENROLLING CLIENT... ${FABRIC_CA_CLIENT_URL}"

  rm -fr ${MSPDIR}/*
  /usr/local/ca-bin/fabric-ca-client enroll --url "${FABRIC_CA_CLIENT_URL}"

  BROADCAST_MSG "TEMP HACKS. COPY ADMINCERTS, TLSCERTS"

  if [[ -z "${ORDERER_GENERAL_LOCALMSPDIR}" ]]; then
    cp -rp ${ADMIN_MSP_DIR}/signcerts /etc/hyperledger/fabric/msp/admincerts
    echo "diff admin certs..."
    diff ${ADMIN_MSP_DIR}/signcerts/cert.pem /etc/hyperledger/fabric/msp/signcerts/cert.pem
    ls -al /etc/hyperledger/fabric/msp/signcerts/
  else
    cp -rp /data/adminOrdererOrg1MSP/signcerts ${ORDERER_GENERAL_LOCALMSPDIR}/admincerts
    echo "diff admin certs..."
    diff /data/adminOrdererOrg1MSP/signcerts/cert.pem ${ORDERER_GENERAL_LOCALMSPDIR}/signcerts/cert.pem
  fi

  echo
  echo "copying tlscacerts..."
  if [[ -z "${ORDERER_GENERAL_LOCALMSPDIR}" ]]; then
    mkdir -p /etc/hyperledger/fabric/msp/tlscacerts
    cp -rp /data/tls/ca_root.pem /etc/hyperledger/fabric/msp/tlscacerts/

  else
    mkdir -p ${ORDERER_GENERAL_LOCALMSPDIR}/tlscacerts
    cp -rp /data/tls/ca_root.pem ${ORDERER_GENERAL_LOCALMSPDIR}/tlscacerts/

    # tmp hack, get tlscacerts in geneisis
    cp -rp ${ORDERER_GENERAL_LOCALMSPDIR}/tlscacerts ${ADMIN_MSP_DIR}/
    cp -rp ${ORDERER_GENERAL_LOCALMSPDIR}/tlscacerts /data/adminOrdererOrg1MSP/
  fi
}


START_DAEMON() {
  BROADCAST_MSG "STARTING DAEMON... $@"
  exec "$@"
}

# ======================================
# main
# ======================================

if [ ! -z "${FABRIC_CA_CLIENT_MSPDIR}" ] ; then
  export MSPDIR=${FABRIC_CA_CLIENT_MSPDIR}
else
  export MSPDIR=${FABRIC_CA_CLIENT_HOME}/msp
fi

if [ ! -z "${WAIT_SIGNAL_FILES}" ] ; then
    wait-for-files.sh ${WAIT_SIGNAL_FILES}
fi

#
# only enroll once, skip enrollment on restart...
# otherwise it would cause problems to gossip 
#
enroll_status_file=$HOME/.fabric_peer_enroll_status
if [ ! -r $enroll_status_file ] ; then
  echo starting peer client enrollment process
  ENROLL_CLIENT
  if [ $? -eq 0 ] ; then
    echo "enrollment completed at $(date)" > $enroll_status_file
  fi
else
  echo skipping client enrollment, found enrollment status file $enroll_status_file
  cat $enroll_status_file
fi

START_DAEMON "$@"
