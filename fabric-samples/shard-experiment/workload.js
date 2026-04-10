'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

function getShardId(userId, shardCount) {
    // Parse the user ID to get a number from the string
    const uid = parseInt(userId.replace('User', ''), 10);
    
    // Evenly distribute users across the available shards using a modulus approach
    return 'shard-' + (uid % shardCount);
}

class MyWorkload extends WorkloadModuleBase {

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);

        this.workerIndex = workerIndex;
        this.totalWorkers = totalWorkers;
        this.txIndex = 0;

        // Save roundArguments for later use
        this.roundArguments = roundArguments || {};

        // Get the shardCount from the roundArguments, or environment variable, or default to 4
        this.shardCount = parseInt(this.roundArguments.shardCount || process.env.SHARD_COUNT || '4', 10);

        // Get the contractId from the roundArguments, or default to 'ev-cc'
        this.contractId = this.roundArguments.contractId || 'ev-cc';

        // Default payload size is 4KB
        this.payloadSize = parseInt(this.roundArguments.payloadSize || process.env.PAYLOAD_SIZE || '4096', 10);

        // Pre-generate payload to reuse for each transaction, avoiding client-side generation overhead
        this.payload = 'x'.repeat(this.payloadSize);

        // Optionally log the initialization for debugging
        // console.log(`[init] shardCount=${this.shardCount}, payloadSize=${this.payloadSize}`);
    }

    async submitTransaction() {
        const globalId = (this.workerIndex + this.txIndex * this.totalWorkers);
        this.txIndex++;

        const txId = globalId.toString();
        const userId = 'User' + (globalId % 100000);
        const shardId = getShardId(userId, this.shardCount);

        // Optionally log transaction details for debugging
        // if (this.txIndex <= 5) console.log({ shardId, txId, userId, payloadSize: this.payloadSize });

        // Send the transaction to the contract
        await this.sutAdapter.sendRequests({
            contractId: this.contractId,
            contractFunction: 'RecordCharging',
            contractArguments: [shardId, txId, userId, '50.5', Date.now().toString(), this.payload],
        });
    }
}

function createWorkloadModule() {
    return new MyWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;

