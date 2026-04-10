'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class EVChargingWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.workerIndex = workerIndex;
        this.totalWorkers = totalWorkers;
        this.roundIndex = roundIndex;
        
        console.log(`Worker ${workerIndex}/${totalWorkers} initialized for round ${roundIndex}`);
    }

    async submitTransaction() {
        this.txIndex++;
        
        // 生成唯一 ID：worker编号-轮次-交易序号-时间戳
        const uniqueID = `W${this.workerIndex}-R${this.roundIndex}-${this.txIndex}-${Date.now()}`;
        const userID = `User${Math.floor(Math.random() * 1000)}`;
        const kwh = (Math.random() * 100).toFixed(2);
        const timestamp = Date.now().toString();

        const request = {
            contractId: this.roundArguments.contractId,
            contractFunction: 'RecordCharging',
            contractArguments: [uniqueID, userID, kwh, timestamp],
            readOnly: false,
            timeout: 30
        };

        await this.sutAdapter.sendRequests(request);
    }

    async cleanupWorkloadModule() {
        console.log(`Worker ${this.workerIndex} completed ${this.txIndex} transactions`);
    }
}

function createWorkloadModule() {
    return new EVChargingWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;
