package main

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SmartContract struct {
	contractapi.Contract
}

// ChargingRecord 充电记录
type ChargingRecord struct {
	ID        string `json:"id"`
	UserID    string `json:"userId"`
	KWh       string `json:"kwh"`
	Timestamp string `json:"timestamp"`
	ShardID   string `json:"shardId"`
	Payload   string `json:"payload"` // 新增：用于增大写入负载
}

// =======================
// 写入（带 shard + 大 payload）
// =======================
func (s *SmartContract) RecordCharging(
	ctx contractapi.TransactionContextInterface,
	shardId string,
	id string,
	userId string,
	kwh string,
	timestamp string,
	payload string, // 新增第 6 个参数
) error {

	record := ChargingRecord{
		ID:        id,
		UserID:    userId,
		KWh:       kwh,
		Timestamp: timestamp,
		ShardID:   shardId,
		Payload:   payload,
	}

	recordJSON, err := json.Marshal(record)
	if err != nil {
		return err
	}

	key := shardId + ":" + id
	return ctx.GetStub().PutState(key, recordJSON)
}

// =======================
// 查询（带 shard）
// =======================
func (s *SmartContract) QueryCharging(
	ctx contractapi.TransactionContextInterface,
	shardId string,
	id string,
) (*ChargingRecord, error) {

	key := shardId + ":" + id

	recordJSON, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if recordJSON == nil {
		return nil, fmt.Errorf("record %s does not exist", key)
	}

	var record ChargingRecord
	err = json.Unmarshal(recordJSON, &record)
	if err != nil {
		return nil, err
	}

	return &record, nil
}

func main() {
	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		fmt.Printf("Error creating ev-charging chaincode: %s", err.Error())
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting ev-charging chaincode: %s", err.Error())
	}
}

