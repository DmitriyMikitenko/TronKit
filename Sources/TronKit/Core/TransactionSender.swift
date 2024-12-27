import Foundation

class TransactionSender {
    private let tronGridProvider: TronGridProvider

    init(tronGridProvider: TronGridProvider) {
        self.tronGridProvider = tronGridProvider
    }
}

extension TransactionSender {
    public func rawTransaction(contract: Contract, signer: Signer, feeLimit: Int?) async throws -> Data {
        var createdTransaction: CreatedTransactionResponse

        guard let contract = contract as? SupportedContract else {
            throw Kit.SendError.notSupportedContract
        }

        switch contract {
        case let transfer as TransferContract:
            createdTransaction = try await tronGridProvider.createTransaction(ownerAddress: transfer.ownerAddress.hex, toAddress: transfer.toAddress.hex, amount: transfer.amount)

        case let smartContract as TriggerSmartContract:
            guard let functionSelector = smartContract.functionSelector,
                  let parameter = smartContract.parameter,
                  let feeLimit
            else {
                throw Kit.SendError.invalidParameter
            }

            createdTransaction = try await tronGridProvider.triggerSmartContract(
                ownerAddress: smartContract.ownerAddress.hex,
                contractAddress: smartContract.contractAddress.hex,
                functionSelector: functionSelector,
                parameter: parameter,
                feeLimit: feeLimit
            )

        default: throw Kit.SendError.notSupportedContract
        }

        let rawData = try Protocol_Transaction.raw(serializedData: createdTransaction.rawDataHex)

        guard rawData.contract.count == 1,
              let contractMessage = rawData.contract.first,
              try contractMessage.parameter.value == (contract.protoMessage.serializedData())
        else {
            throw Kit.SendError.abnormalSend
        }
        
        let signature = try signer.signature(hash: createdTransaction.txID)
        let contractRequest = parseContract(createdTransaction.rawData.contract)
        let rawContractData = TronSignedTransaction.RawData(contract: contractRequest,
                                                            refBlockBytes: createdTransaction.rawData.refBlockBytes,
                                                            refBlockHash: createdTransaction.rawData.refBlockHash,
                                                            expiration: createdTransaction.rawData.expiration,
                                                            feeLimit: createdTransaction.rawData.feeLimit,
                                                            timestamp: createdTransaction.rawData.timestamp)
        let signedTransaction = TronSignedTransaction(txID: createdTransaction.txID.hs.hex,
                                                      raw_data: rawContractData,
                                                      raw_data_hex: createdTransaction.rawDataHex.hs.hex,
                                                      visible: false,
                                                      signature: [signature.hs.hex])
        
        guard let resultData = signedTransaction.toJSON()
        else {
            throw Kit.SendError.invalidParameter
        }
                
        return resultData
    }
    
    func sendTransaction(contract: Contract, signer: Signer, feeLimit: Int?) async throws -> CreatedTransactionResponse {
        var createdTransaction: CreatedTransactionResponse

        guard let contract = contract as? SupportedContract else {
            throw Kit.SendError.notSupportedContract
        }

        switch contract {
        case let transfer as TransferContract:
            createdTransaction = try await tronGridProvider.createTransaction(ownerAddress: transfer.ownerAddress.hex, toAddress: transfer.toAddress.hex, amount: transfer.amount)

        case let smartContract as TriggerSmartContract:
            guard let functionSelector = smartContract.functionSelector,
                  let parameter = smartContract.parameter,
                  let feeLimit
            else {
                throw Kit.SendError.invalidParameter
            }

            createdTransaction = try await tronGridProvider.triggerSmartContract(
                ownerAddress: smartContract.ownerAddress.hex,
                contractAddress: smartContract.contractAddress.hex,
                functionSelector: functionSelector,
                parameter: parameter,
                feeLimit: feeLimit
            )

        default: throw Kit.SendError.notSupportedContract
        }

        let rawData = try Protocol_Transaction.raw(serializedData: createdTransaction.rawDataHex)

        guard rawData.contract.count == 1,
              let contractMessage = rawData.contract.first,
              try contractMessage.parameter.value == (contract.protoMessage.serializedData())
        else {
            throw Kit.SendError.abnormalSend
        }

        let signature = try signer.signature(hash: createdTransaction.txID)

        var transaction = Protocol_Transaction()
        transaction.rawData = rawData
        transaction.signature = [signature]

        try await tronGridProvider.broadcastTransaction(hexData: transaction.serializedData())

        return createdTransaction
    }
}

extension TransactionSender {
    private func parseContract(_ input: Any?) -> [TronSignedTransaction.ContractRequest]? {
        guard let contractArray = input as? [[String: Any]] else { return nil }
        
        return contractArray.compactMap { contractDict in
            guard let type = contractDict["type"] as? String,
                  let parameter = contractDict["parameter"] as? [String: Any],
                  let valueDict = parameter["value"] as? [String: Any],
                  let data = valueDict["data"] as? String,
                  let ownerAddress = valueDict["owner_address"] as? String,
                  let contractAddress = valueDict["contract_address"] as? String,
                  let typeUrl = parameter["type_url"] as? String else {
                return nil
            }
            
            let value = TronSignedTransaction.ContractRequest.Value(data: data, owner_address: ownerAddress, contract_address: contractAddress)
            let parameterObject = TronSignedTransaction.ContractRequest.Parameter(value: value, type_url: typeUrl)
            return TronSignedTransaction.ContractRequest(parameter: parameterObject, type: type)
        }
    }
}
