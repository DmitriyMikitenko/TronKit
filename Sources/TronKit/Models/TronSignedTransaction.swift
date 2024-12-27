import Foundation

public struct TronSignedTransaction: Encodable {
    let txID: String
    let raw_data: RawData
    let raw_data_hex: String
    let visible: Bool
    let signature: [String]
    
    struct RawData: Encodable {
        let contract: [ContractRequest]?
        let refBlockBytes: String
        let refBlockHash: String
        let expiration: Int
        let feeLimit: Int?
        let timestamp: Int
    }
    
    struct ContractRequest: Encodable {
        let parameter: Parameter
        let type: String
        
        struct Parameter: Encodable {
            let value: Value
            let type_url: String
        }
        
        struct Value: Encodable {
            let data: String
            let owner_address: String
            let contract_address: String
        }
    }

    func toJSON() -> Data? {
        var json = "{"
        
        json += "\"txID\":\"\(txID)\","
        json += "\"raw_data\":{"
        json += "\"ref_block_bytes\":\"\(raw_data.refBlockBytes)\","
        json += "\"ref_block_hash\":\"\(raw_data.refBlockHash)\","
        json += "\"expiration\":\(raw_data.expiration),"
        json += "\"timestamp\":\(raw_data.timestamp),"
        
        if let feeLimit = raw_data.feeLimit {
            json += "\"fee_limit\":\(feeLimit),"
        }
        
        if let contract = raw_data.contract {
            json += "\"contract\":["
            for (index, c) in contract.enumerated() {
                json += "{"
                json += "\"type\":\"\(c.type)\","
                json += "\"parameter\":{"
                json += "\"type_url\":\"\(c.parameter.type_url)\","
                json += "\"value\":{"
                json += "\"contract_address\":\"\(c.parameter.value.contract_address)\","
                json += "\"data\":\"\(c.parameter.value.data)\","
                json += "\"owner_address\":\"\(c.parameter.value.owner_address)\""
                json += "}"
                json += "}"
                json += "}"
                
                if index != contract.count - 1 {
                    json += ","
                }
            }
            json += "],"
        }
        
        json += "},"
        json += "\"raw_data_hex\":\"\(raw_data_hex)\","
        json += "\"visible\":\(visible),"
        json += "\"signature\":["
        
        for (index, sig) in signature.enumerated() {
            json += "\"\(sig)\""
            if index != signature.count - 1 {
                json += ","
            }
        }
        
        json += "]"
        json += "}"
        
        return Data(json.utf8)
    }
}
