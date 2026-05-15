import CodecsCore
import Foundation
import SolanaErrors

public func assertValidBaseString(_ alphabet: String, _ testValue: String, givenValue: String? = nil) throws(CodecsError)

public func getBase10Encoder() -> AnyVariableSizeEncoder<String>
public func getBase10Decoder() -> AnyVariableSizeDecoder<String>
public func getBase10Codec() -> AnyVariableSizeCodec<String, String>

public func getBase16Encoder() -> AnyVariableSizeEncoder<String>
public func getBase16Decoder() -> AnyVariableSizeDecoder<String>
public func getBase16Codec() -> AnyVariableSizeCodec<String, String>

public func getBase58Encoder() -> AnyVariableSizeEncoder<String>
public func getBase58Decoder() -> AnyVariableSizeDecoder<String>
public func getBase58Codec() -> AnyVariableSizeCodec<String, String>

public func getBase64Encoder() -> AnyVariableSizeEncoder<String>
public func getBase64Decoder() -> AnyVariableSizeDecoder<String>
public func getBase64Codec() -> AnyVariableSizeCodec<String, String>

public func getBaseXEncoder(_ alphabet: String) -> AnyVariableSizeEncoder<String>
public func getBaseXDecoder(_ alphabet: String) -> AnyVariableSizeDecoder<String>
public func getBaseXCodec(_ alphabet: String) -> AnyVariableSizeCodec<String, String>

public func getBaseXResliceEncoder(_ alphabet: String, bits: Int) -> AnyVariableSizeEncoder<String>
public func getBaseXResliceDecoder(_ alphabet: String, bits: Int) -> AnyVariableSizeDecoder<String>
public func getBaseXResliceCodec(_ alphabet: String, bits: Int) -> AnyVariableSizeCodec<String, String>

public func removeNullCharacters(_ value: String) -> String
public func padNullCharacters(_ value: String, chars: Int) -> String

public func getUtf8Encoder() -> AnyVariableSizeEncoder<String>
public func getUtf8Decoder() -> AnyVariableSizeDecoder<String>
public func getUtf8Codec() -> AnyVariableSizeCodec<String, String>
