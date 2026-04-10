#!/bin/bash

PEER_COUNT=$1
OUT_FILE=$2

cat <<EOF > $OUT_FILE
version: '2.4'
networks:
  test:
    name: fabric_test
services:
  orderer.example.com:
    extends:
      file: docker/docker-compose-test-net.yaml
      service: orderer.example.com
EOF

for ((i=0;i<$PEER_COUNT;i++)); do
cat <<EOF >> $OUT_FILE

  peer${i}.org1.example.com:
    container_name: peer${i}.org1.example.com
    extends:
      file: docker/docker-compose-test-net.yaml
      service: peer0.org1.example.com
    environment:
      - CORE_PEER_ID=peer${i}.org1.example.com
      - CORE_PEER_ADDRESS=peer${i}.org1.example.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
    ports:
      - "$((7051 + i*1000)):7051"
    networks:
      - test
EOF
done

