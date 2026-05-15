# ``CodecsCore``

Composable byte encoders, byte decoders and codecs.

## Overview

`CodecsCore` defines the base protocols used by the package codec stack. Encoders write Swift values into byte buffers, decoders read Swift values from byte buffers and codecs combine both directions.

Use fixed-size codecs when the encoded byte count is known ahead of time. Use variable-size codecs when the encoded length depends on the value or encoded data.

## Topics

### Protocols

- ``Encoder``
- ``Decoder``
- ``Codec``
- ``FixedSizeCodec``
- ``VariableSizeCodec``

### Construction

- ``createCodec(fixedSize:write:read:)``
- ``createCodec(maxSize:getSizeFromValue:write:read:)``
- ``combineCodec(_:_:)``

### Transformation

- ``transformCodec(_:encode:decode:)``
- ``fixCodecSize(_:fixedBytes:)``
