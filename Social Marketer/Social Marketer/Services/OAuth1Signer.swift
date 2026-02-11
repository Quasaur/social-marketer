//
//  OAuth1Signer.swift
//  SocialMarketer
//
//  OAuth 1.0a request signing utility for X (Twitter) API
//

import Foundation
import CommonCrypto

/// Signs URLRequests with OAuth 1.0a authorization headers (HMAC-SHA1)
struct OAuth1Signer {
    
    let consumerKey: String
    let consumerSecret: String
    let accessToken: String
    let accessTokenSecret: String
    
    /// Sign a URLRequest with OAuth 1.0a and return a new request with the Authorization header
    func sign(_ request: URLRequest) -> URLRequest {
        var signedRequest = request
        let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? ""
        let authHeader = authorizationHeader(
            httpMethod: request.httpMethod ?? "GET",
            url: request.url!,
            body: request.httpBody,
            contentType: contentType
        )
        signedRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
        return signedRequest
    }
    
    // MARK: - Private
    
    private func authorizationHeader(httpMethod: String, url: URL, body: Data?, contentType: String) -> String {
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let timestamp = String(Int(Date().timeIntervalSince1970))
        
        // Base OAuth parameters
        var oauthParams: [(String, String)] = [
            ("oauth_consumer_key", consumerKey),
            ("oauth_nonce", nonce),
            ("oauth_signature_method", "HMAC-SHA1"),
            ("oauth_timestamp", timestamp),
            ("oauth_token", accessToken),
            ("oauth_version", "1.0")
        ]
        
        // Collect all parameters (OAuth + query string + form body)
        var allParams = oauthParams
        
        // Add query parameters
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            for item in queryItems {
                allParams.append((item.name, item.value ?? ""))
            }
        }
        
        // Only include body params for application/x-www-form-urlencoded (RFC 5849 §3.4.1.3.1)
        // JSON and multipart bodies are NOT part of the signature base string
        if contentType.contains("application/x-www-form-urlencoded"),
           let body = body,
           let bodyString = String(data: body, encoding: .utf8),
           !bodyString.isEmpty {
            let pairs = bodyString.components(separatedBy: "&")
            for pair in pairs {
                let kv = pair.components(separatedBy: "=")
                if kv.count == 2 {
                    let key = kv[0].removingPercentEncoding ?? kv[0]
                    let value = kv[1].removingPercentEncoding ?? kv[1]
                    allParams.append((key, value))
                }
            }
        }
        
        // Sort parameters
        allParams.sort { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
        
        // Build parameter string
        let paramString = allParams
            .map { "\(percentEncode($0.0))=\(percentEncode($0.1))" }
            .joined(separator: "&")
        
        // Build base URL (without query string)
        var baseURL = url.absoluteString
        if let range = baseURL.range(of: "?") {
            baseURL = String(baseURL[..<range.lowerBound])
        }
        
        // Build signature base string
        let signatureBase = "\(httpMethod.uppercased())&\(percentEncode(baseURL))&\(percentEncode(paramString))"
        
        // Build signing key
        let signingKey = "\(percentEncode(consumerSecret))&\(percentEncode(accessTokenSecret))"
        
        // HMAC-SHA1
        let signature = hmacSHA1(key: signingKey, data: signatureBase)
        
        // Add signature to OAuth params
        oauthParams.append(("oauth_signature", signature))
        
        // Build Authorization header
        let headerParts = oauthParams.map { "\(percentEncode($0.0))=\"\(percentEncode($0.1))\"" }
        return "OAuth " + headerParts.joined(separator: ", ")
    }
    
    private func percentEncode(_ string: String) -> String {
        // RFC 5849 / RFC 3986 percent encoding
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
    
    private func hmacSHA1(key: String, data: String) -> String {
        let keyData = key.data(using: .utf8)!
        let dataData = data.data(using: .utf8)!
        
        var result = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        
        keyData.withUnsafeBytes { keyBytes in
            dataData.withUnsafeBytes { dataBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA1),
                    keyBytes.baseAddress, keyData.count,
                    dataBytes.baseAddress, dataData.count,
                    &result
                )
            }
        }
        
        return Data(result).base64EncodedString()
    }
}
