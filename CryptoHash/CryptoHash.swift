//
//  CryptoHash.swift
//  CryptoHash
//
//  Created by Ruben Nine on 11/11/2016.
//  Copyright © 2016 9Labs. All rights reserved.
//

import Foundation
import CommonCrypto

public enum DigestAlgorithm {

    case md5
    case sha1
    case sha224
    case sha256
    case sha384
    case sha512

    public var digestLength: Int {

        switch self {
        case .md5: return Int(CC_MD5_DIGEST_LENGTH)
        case .sha1: return Int(CC_SHA1_DIGEST_LENGTH)
        case .sha224: return Int(CC_SHA224_DIGEST_LENGTH)
        case .sha256: return Int(CC_SHA256_DIGEST_LENGTH)
        case .sha384: return Int(CC_SHA384_DIGEST_LENGTH)
        case .sha512: return Int(CC_SHA512_DIGEST_LENGTH)
        }
    }
}

private let defaultChunkSize: Int = 4096


// MARK: - Public Extensions

public extension URL {

    /**
        Returns a checksum of the file's content referenced by this URL using the specified digest algorithm.

        - Parameter algorithm: The digest algorithm to use.
        - Parameter *(optional)* chunkSize: The internal buffer's size (mostly relevant for large file computing)
     
        - Note: Use only with URL's pointing to local or LAN network files.

        - Returns: *(optional)* A String with the computed checksum.
     */
    func checksum(algorithm: DigestAlgorithm, chunkSize: Int = defaultChunkSize) throws -> String? {

        let data = try Data(contentsOf: self, options: .mappedIfSafe)
        return try data.checksum(algorithm: algorithm, chunkSize: chunkSize)
    }

    /**
        TODO: Add async checksum computation function with progress reporting.
    
        Useful for:

        - URLs representing large files on the local filesystem (or LAN)
        - Remote URLs (http)
    */
}


public extension String {

    /**
        Returns a checksum of the String's content using the specified digest algorithm.
     
        - Parameter algorithm: The digest algorithm to use.

        - Returns: *(optional)* A String with the computed checksum.
     */
    func checksum(algorithm: DigestAlgorithm) throws -> String? {

        if let data = data(using: .utf8) {
            return try data.checksum(algorithm: algorithm)
        } else {
            return nil
        }
    }
}


public extension Data {

    /**
        Returns a checksum of the Data's content using the specified digest algorithm.

        - Parameter algorithm: The digest algorithm to use.
        - Parameter *(optional)* chunkSize: The internal buffer's size (mostly relevant for large file computing)

        - Returns: *(optional)* A String with the computed checksum.
     */
    func checksum(algorithm: DigestAlgorithm, chunkSize: Int = defaultChunkSize) throws -> String? {

        let cc = CCWrapper(algorithm: algorithm)
        var bytesLeft = count

        withUnsafeBytes { (u8Ptr: UnsafePointer<UInt8>) in
            var uMutablePtr = UnsafeMutablePointer(mutating: u8Ptr)

            while bytesLeft > 0 {
                //let bytesToCopy = min(bytesLeft, chunkSize)
                let bytesToCopy = [bytesLeft, chunkSize].min()!

                cc.update(data: uMutablePtr, length: CC_LONG(bytesToCopy))

                bytesLeft -= bytesToCopy
                uMutablePtr += bytesToCopy
            }
        }
        
        cc.final()
        return cc.hexString()
    }
}


// MARK: - CCWrapper (for internal use)

private class CCWrapper {

    private typealias CC_XXX_Update = (UnsafeRawPointer, CC_LONG) -> Void
    private typealias CC_XXX_Final = (UnsafeMutablePointer<UInt8>) -> Void

    public let algorithm: DigestAlgorithm

    private var digest: UnsafeMutablePointer<UInt8>?
    private var md5Ctx: UnsafeMutablePointer<CC_MD5_CTX>?
    private var sha1Ctx: UnsafeMutablePointer<CC_SHA1_CTX>?
    private var sha256Ctx: UnsafeMutablePointer<CC_SHA256_CTX>?
    private var sha512Ctx: UnsafeMutablePointer<CC_SHA512_CTX>?
    private var updateFun: CC_XXX_Update?
    private var finalFun: CC_XXX_Final?


    init(algorithm: DigestAlgorithm) {

        self.algorithm = algorithm

        switch algorithm {
        case .md5:
            md5Ctx = UnsafeMutablePointer<CC_MD5_CTX>.allocate(capacity: algorithm.digestLength)
            CC_MD5_Init(md5Ctx)

            updateFun = { (data, len) in CC_MD5_Update(self.md5Ctx, data, len) }
            finalFun = { (digest) in CC_MD5_Final(digest, self.md5Ctx) }

        case .sha1:
            sha1Ctx = UnsafeMutablePointer<CC_SHA1_CTX>.allocate(capacity: algorithm.digestLength)
            CC_SHA1_Init(sha1Ctx)

            updateFun = { (data, len) in CC_SHA1_Update(self.sha1Ctx, data, len) }
            finalFun = { (digest) in CC_SHA1_Final(digest, self.sha1Ctx) }

        case .sha224:
            sha256Ctx = UnsafeMutablePointer<CC_SHA256_CTX>.allocate(capacity: algorithm.digestLength)
            CC_SHA224_Init(sha256Ctx)

            updateFun = { (data, len) in CC_SHA224_Update(self.sha256Ctx, data, len) }
            finalFun = { (digest) in CC_SHA224_Final(digest, self.sha256Ctx) }

        case .sha256:
            sha256Ctx = UnsafeMutablePointer<CC_SHA256_CTX>.allocate(capacity: algorithm.digestLength)
            CC_SHA256_Init(sha256Ctx)

            updateFun = { (data, len) in CC_SHA256_Update(self.sha256Ctx, data, len) }
            finalFun = { (digest) in CC_SHA256_Final(digest, self.sha256Ctx) }

        case .sha384:
            sha512Ctx = UnsafeMutablePointer<CC_SHA512_CTX>.allocate(capacity: algorithm.digestLength)
            CC_SHA384_Init(sha512Ctx)

            updateFun = { (data, len) in CC_SHA384_Update(self.sha512Ctx, data, len) }
            finalFun = { (digest) in CC_SHA384_Final(digest, self.sha512Ctx) }

        case .sha512:
            sha512Ctx = UnsafeMutablePointer<CC_SHA512_CTX>.allocate(capacity: algorithm.digestLength)
            CC_SHA512_Init(sha512Ctx)

            updateFun = { (data, len) in CC_SHA512_Update(self.sha512Ctx, data, len) }
            finalFun = { (digest) in CC_SHA512_Final(digest, self.sha512Ctx) }

        }
    }

    deinit {

        md5Ctx?.deallocate(capacity: algorithm.digestLength)
        sha1Ctx?.deallocate(capacity: algorithm.digestLength)
        sha256Ctx?.deallocate(capacity: algorithm.digestLength)
        sha512Ctx?.deallocate(capacity: algorithm.digestLength)
        digest?.deallocate(capacity: algorithm.digestLength)
    }

    func update(data: UnsafeMutableRawPointer, length: CC_LONG) {

        updateFun?(data, length)
    }

    func final() {

        // We already got a digest, return early
        guard digest == nil else { return }

        digest = UnsafeMutablePointer<UInt8>.allocate(capacity: algorithm.digestLength)

        if let digest = digest {
            finalFun?(digest)
        }
    }

    func hexString() -> String? {

        // We DON'T have a digest YET, return early
        guard let digest = digest else { return nil }

        var string = ""

        for i in 0..<algorithm.digestLength {
            string += String(format: "%02x", digest[i])
        }
        
        return string
    }
}
