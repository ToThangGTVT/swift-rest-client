//
//  RequestBodyBuilder.swift
//  CocoaRestClientCore
//

import Foundation
import UniformTypeIdentifiers

#if canImport(zlib)
import zlib
#endif

public struct RequestBodyResult: Sendable {
    public let data: Data?
    public let contentType: String?
    
    public init(data: Data?, contentType: String?) {
        self.data = data
        self.contentType = contentType
    }
}

public struct RequestBodyBuilder: Sendable {
    public init() {}

    public static func build(
        for request: RestRequest,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> RequestBodyResult {
        guard request.method.allowsBody else {
            return RequestBodyResult(data: nil, contentType: nil)
        }

        switch request.bodyType {
        case .raw:
            let resolved = EnvironmentVariableResolver.resolve(request.rawBody, environment: environment)
            let data = resolved.data(using: .utf8)
            let ct = request.rawBodyContentType.isEmpty ? "application/json" : request.rawBodyContentType
            return RequestBodyResult(data: data, contentType: ct)

        case .formUrlEncoded:
            var pairs: [String] = []
            for param in request.params where param.isEnabled && !param.key.isEmpty {
                let resolvedKey = EnvironmentVariableResolver.resolve(param.key, environment: environment)
                let resolvedVal = EnvironmentVariableResolver.resolve(param.value, environment: environment)
                
                let encodedKey = percentEncodeForm(resolvedKey)
                let encodedVal = percentEncodeForm(resolvedVal)
                pairs.append("\(encodedKey)=\(encodedVal)")
            }
            let formString = pairs.joined(separator: "&")
            let data = formString.data(using: .utf8)
            return RequestBodyResult(data: data, contentType: "application/x-www-form-urlencoded")

        case .multipart:
            let boundary = "Boundary-\(UUID().uuidString)"
            var bodyData = Data()
            
            // Text fields
            for param in request.params where param.isEnabled && !param.key.isEmpty {
                let resolvedKey = EnvironmentVariableResolver.resolve(param.key, environment: environment)
                let resolvedVal = EnvironmentVariableResolver.resolve(param.value, environment: environment)
                
                bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
                bodyData.append("Content-Disposition: form-data; name=\"\(resolvedKey)\"\r\n\r\n".data(using: .utf8)!)
                bodyData.append("\(resolvedVal)\r\n".data(using: .utf8)!)
            }
            
            // File attachments
            for file in request.files where file.isEnabled && !file.key.isEmpty && !file.filePath.isEmpty {
                let resolvedKey = EnvironmentVariableResolver.resolve(file.key, environment: environment)
                let fileUrl = URL(fileURLWithPath: file.filePath)
                
                guard let rawFileData = try? Data(contentsOf: fileUrl) else {
                    continue
                }
                
                let fileData: Data
                let mimeType: String
                
                if file.isGzipped {
                    fileData = gzipCompress(rawFileData) ?? rawFileData
                    mimeType = "application/x-gzip"
                } else {
                    fileData = rawFileData
                    mimeType = file.resolvedMimeType
                }
                
                bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
                bodyData.append("Content-Disposition: form-data; name=\"\(resolvedKey)\"; filename=\"\(fileUrl.lastPathComponent)\"\r\n".data(using: .utf8)!)
                bodyData.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                bodyData.append(fileData)
                bodyData.append("\r\n".data(using: .utf8)!)
            }
            
            bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
            let contentType = "multipart/form-data; boundary=\(boundary)"
            return RequestBodyResult(data: bodyData, contentType: contentType)

        case .binaryFile:
            guard !request.binaryFilePath.isEmpty else {
                return RequestBodyResult(data: nil, contentType: "application/octet-stream")
            }
            let fileUrl = URL(fileURLWithPath: request.binaryFilePath)
            let data = try? Data(contentsOf: fileUrl)
            return RequestBodyResult(data: data, contentType: "application/octet-stream")

        case .graphql:
            let resolvedQuery = EnvironmentVariableResolver.resolve(request.graphqlQuery, environment: environment)
            let resolvedVars = EnvironmentVariableResolver.resolve(request.graphqlVariables, environment: environment)
            
            var payload: [String: Any] = ["query": resolvedQuery]
            if let varsData = resolvedVars.data(using: .utf8),
               let jsonVars = try? JSONSerialization.jsonObject(with: varsData) {
                payload["variables"] = jsonVars
            }
            
            let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            return RequestBodyResult(data: jsonData, contentType: "application/json")
        }
    }

    private static func percentEncodeForm(_ string: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        let encoded = string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
        return encoded.replacingOccurrences(of: " ", with: "+")
    }

    public static func gzipCompress(_ data: Data) -> Data? {
        guard !data.isEmpty else { return data }
        
        var stream = z_stream()
        let initResult = deflateInit2_(
            &stream,
            Z_DEFAULT_COMPRESSION,
            Z_DEFLATED,
            MAX_WBITS + 16, // +16 for gzip header
            8,
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initResult == Z_OK else { return nil }
        defer { deflateEnd(&stream) }
        
        var compressed = Data()
        let chunkSize = 16384
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        
        data.withUnsafeBytes { rawBuffer in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: rawBuffer.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(data.count)
            
            while stream.avail_in > 0 {
                buffer.withUnsafeMutableBufferPointer { buffPtr in
                    stream.next_out = buffPtr.baseAddress
                    stream.avail_out = uInt(chunkSize)
                    deflate(&stream, Z_NO_FLUSH)
                    let bytesWritten = chunkSize - Int(stream.avail_out)
                    if bytesWritten > 0 {
                        compressed.append(buffPtr.baseAddress!, count: bytesWritten)
                    }
                }
            }
            
            var finish = Z_OK
            while finish != Z_STREAM_END {
                buffer.withUnsafeMutableBufferPointer { buffPtr in
                    stream.next_out = buffPtr.baseAddress
                    stream.avail_out = uInt(chunkSize)
                    finish = deflate(&stream, Z_FINISH)
                    let bytesWritten = chunkSize - Int(stream.avail_out)
                    if bytesWritten > 0 {
                        compressed.append(buffPtr.baseAddress!, count: bytesWritten)
                    }
                }
            }
        }
        
        return compressed
    }
}
