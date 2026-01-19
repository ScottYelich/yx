import Foundation
import Network
import CryptoKit

public class UDPSocket {
    private var connection: NWConnection?
    public let port: UInt16

    public init(port: UInt16 = 50000) {
        self.port = port
    }

    public func bind() throws {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        let endpoint = NWEndpoint.hostPort(host: .ipv4(.any), port: NWEndpoint.Port(integerLiteral: port))
        let listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port))

        listener.start(queue: .main)
    }

    public func sendPacket(guid: Data, payload: Data, key: SymmetricKey, host: String = "255.255.255.255", port: UInt16 = 50000) throws {
        let data = try PacketBuilder.buildAndSerialize(guid: guid, payload: payload, key: key)

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        let hostEndpoint = NWEndpoint.Host(host)
        let portEndpoint = NWEndpoint.Port(integerLiteral: port)
        let endpoint = NWEndpoint.hostPort(host: hostEndpoint, port: portEndpoint)

        let connection = NWConnection(to: endpoint, using: params)
        connection.start(queue: .main)

        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
            connection.cancel()
        })
    }
}
