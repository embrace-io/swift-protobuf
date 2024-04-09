// Sources/SwiftProtobuf/SwiftProtobufError.swift
//
// Copyright (c) 2024 Apple Inc. and the project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See LICENSE.txt for license information:
// https://github.com/apple/swift-protobuf/blob/main/LICENSE.txt
//
// -----------------------------------------------------------------------------

/// A SwiftProtobuf specific error.
///
/// All errors have a high-level ``SwiftProtobufError/Code-swift.struct`` which identifies the domain
/// of the error. For example, an issue when encoding a proto into binary data will result in a
/// ``SwiftProtobufError/Code-swift.struct/binaryEncodingError`` error code.
/// Errors also include a message describing what went wrong and how to remedy it (if applicable). The
/// ``SwiftProtobufError/message`` is not static and may include dynamic information such as the
/// type URL for a type that could not be decoded, for example.
public struct SwiftProtobufError: Error, @unchecked Sendable {
    // Note: @unchecked because we use a backing class for storage.

    private var storage: Storage
    private mutating func ensureStorageIsUnique() {
        if !isKnownUniquelyReferenced(&self.storage) {
            self.storage = self.storage.copy()
        }
    }
    
    private final class Storage {
        var code: Code
        var message: String
        var location: SourceLocation

        init(
            code: Code,
            message: String,
            location: SourceLocation
        ) {
            self.code = code
            self.message = message
            self.location = location
        }

        func copy() -> Self {
            return Self(
                code: self.code,
                message: self.message,
                location: self.location
            )
        }
    }
    
    /// A high-level error code to provide broad a classification.
    public var code: Code {
        get { self.storage.code }
        set {
            self.ensureStorageIsUnique()
            self.storage.code = newValue
        }
    }

    /// A message describing what went wrong and how it may be remedied.
    internal var message: String {
        get { self.storage.message }
        set {
            self.ensureStorageIsUnique()
            self.storage.message = newValue
        }
    }
    
    private var location: SourceLocation {
        get { self.storage.location }
        set {
            self.ensureStorageIsUnique()
            self.storage.location = newValue
        }
    }

    public init(
        code: Code,
        message: String,
        location: SourceLocation
    ) {
        self.storage = Storage(code: code, message: message, location: location)
    }
}

extension SwiftProtobufError {
    /// A high level indication of the kind of error being thrown.
    public struct Code: Hashable, Sendable, CustomStringConvertible {
        private enum Wrapped: Hashable, Sendable, CustomStringConvertible {
            case binaryEncodingError
            case binaryDecodingError
            case jsonEncodingError
            case jsonDecodingError
            case textFormatDecodingError
            case invalidArgument
            case internalError

            var description: String {
                switch self {
                case .binaryEncodingError:
                    return "Binary encoding error"
                case .binaryDecodingError:
                    return "Binary decoding error"
                case .jsonEncodingError:
                    return "JSON encoding error"
                case .jsonDecodingError:
                    return "JSON decoding error"
                case .textFormatDecodingError:
                    return "Text format decoding error"
                case .invalidArgument:
                    return "An argument provided by the user is invalid"
                case .internalError:
                    return "Other internal error"
                }
            }
        }

        public var description: String {
            String(describing: self.code)
        }

        private var code: Wrapped
        private init(_ code: Wrapped) {
            self.code = code
        }

        public static var binaryEncodingError: Self {
            Self(.binaryEncodingError)
        }
        
        public static var binaryDecodingError: Self {
            Self(.binaryDecodingError)
        }
        
        public static var jsonEncodingError: Self {
            Self(.jsonEncodingError)
        }
        
        public static var jsonDecodingError: Self {
            Self(.jsonDecodingError)
        }
        
        public static var textFormatDecodingError: Self {
            Self(.textFormatDecodingError)
        }
        
        public static var invalidArgument: Self {
            Self(.invalidArgument)
        }
        
        public static var internalError: Self {
            Self(.internalError)
        }
    }

    /// A location within source code.
    public struct SourceLocation: Sendable, Hashable {
        /// The function in which the error was thrown.
        public var function: String

        /// The file in which the error was thrown.
        public var file: String

        /// The line on which the error was thrown.
        public var line: Int

        public init(function: String, file: String, line: Int) {
            self.function = function
            self.file = file
            self.line = line
        }

        @usableFromInline
        internal static func here(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> Self {
            return SourceLocation(function: function, file: file, line: line)
        }
    }
}

extension SwiftProtobufError: CustomStringConvertible {
    public var description: String {
        "\(self.code) (at \(self.location)): \(self.message)"
    }
}

extension SwiftProtobufError: CustomDebugStringConvertible {
    public var debugDescription: String {
        "\(String(reflecting: self.code)) (at \(String(reflecting: self.location))): \(String(reflecting: self.message))"
    }
}

// - MARK: Common errors

extension SwiftProtobufError {
    /// Errors arising from encoding protobufs into binary data.
    public enum BinaryEncoding {
        /// The definition of the message or one of its nested messages has required
        /// fields but the message being encoded did not include values for them. You
        /// must pass `partial: true` during encoding if you wish to explicitly ignore
        /// missing required fields.
        public static func missingRequiredFields(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .binaryEncodingError,
                message: """
                The definition of the message or one of its nested messages has required fields, \
                but the message being encoded did not include values for them. \
                Decode with `partial: true` if you wish to explicitly ignore missing required fields.
            """,
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Messages are limited to a maximum of 2GB in encoded size.
        public static func tooLarge(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .binaryEncodingError,
                message: "Messages are limited to a maximum of 2GB in encoded size.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// `Any` fields that were decoded from JSON cannot be re-encoded to binary
        /// unless the object they hold is a well-known type or a type registered via
        /// `Google_Protobuf_Any.register()`.
        public static func anyTypeURLNotRegistered(
            typeURL: String,
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
          SwiftProtobufError(
            code: .binaryEncodingError,
            message: """
                Any fields that were decoded from JSON format cannot be re-encoded to binary \
                unless the object they hold is a well-known type or a type registered via \
                `Google_Protobuf_Any.register()`. Type URL is \(typeURL).
            """,
            location: SourceLocation(function: function, file: file, line: line)
          )
        }
        
        /// When writing a binary-delimited message into a stream, this error will be thrown if less than
        /// the expected number of bytes were written.
        public static func truncated(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .binaryEncodingError,
                message: """
                    Less than the expected number of bytes were written when writing \
                    a binary-delimited message into an output stream.
                """,
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
    }

    /// Errors arising from binary decoding of data into protobufs.
    public enum BinaryDecoding {
        /// The end of the data was reached before it was expected.
        public static func truncated(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .binaryDecodingError,
                message: "The end of the data was reached before it was expected.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        // Extraneous data remained after decoding should have been complete.
        public static func trailingGarbage(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .binaryDecodingError,
                message: "Extraneous data remained after decoding should have been complete.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Message is too large. Bytes and Strings have a max size of 2GB.
        public static func tooLarge(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .binaryDecodingError,
                message: "Message too large: Bytes and Strings have a max size of 2GB.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// A string field was not encoded as valid UTF-8.
        public static func invalidUTF8(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .binaryDecodingError,
                message: "A string field was not encoded as valid UTF-8.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// The binary data was malformed in some way, such as an invalid wire format or field tag.
        public static func malformedProtobuf(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .binaryDecodingError,
                message: """
                    The binary data was malformed in some way, such as an \
                    invalid wire format or field tag.
                """,
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// The definition of the message or one of its nested messages has required
        /// fields but the binary data did not include values for them. You must pass
        /// `partial: true` during decoding if you wish to explicitly ignore missing
        /// required fields.
        public static func missingRequiredFields(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .binaryDecodingError,
                message: """
                    The definition of the message or one of its nested messages has required fields, \
                    but the binary data did not include values for them. \
                    Decode with `partial: true` if you wish to explicitly ignore missing required fields.
                """,
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// An internal error happened while decoding.  If this is ever encountered,
        /// please file an issue with SwiftProtobuf with as much details as possible
        /// for what happened (proto definitions, bytes being decoded (if possible)).
        public static func internalExtensionError(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .binaryDecodingError,
                message: "An internal error hapenned while decoding. Please file an issue with SwiftProtobuf.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }

        /// Reached the nesting limit for messages within messages while decoding.
        public static func messageDepthLimit(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .binaryDecodingError,
                message: "Reached the nesting limit for messages within messages while decoding.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
    }
    
    /// Errors arising from encoding protobufs into JSON.
    public enum JSONEncoding {
        /// Timestamp values can only be JSON encoded if they hold a value
        /// between 0001-01-01Z00:00:00 and 9999-12-31Z23:59:59.
        public static func timestampRange(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonEncodingError,
                message: """
                    Timestamp values can only be JSON encoded if they hold a value \
                    between 0001-01-01Z00:00:00 and 9999-12-31Z23:59:59.
                """,
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Duration values can only be JSON encoded if they hold a value
        /// less than +/- 100 years.
        public static func durationRange(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonEncodingError,
                message: "Duration values can only be JSON encoded if they hold a value less than +/- 100 years.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Field masks get edited when converting between JSON and protobuf.
        public static func fieldMaskConversion(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonEncodingError,
                message: "Field masks get edited when converting between JSON and protobuf.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Field names were not compiled into the binary.
        public static func missingFieldNames(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonEncodingError,
                message: "Field names were not compiled into the binary.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Instances of `Google_Protobuf_Value` can only be encoded if they have a
        /// valid `kind` (that is, they represent a null value, number, boolean,
        /// string, struct, or list).
        public static func missingValue(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonEncodingError,
                message: "Instances of `Google_Protobuf_Value` can only be encoded if they have a valid `kind`.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// `Google_Protobuf_Value` cannot encode double values for infinity or nan,
        /// because they would be parsed as a string.
        public static func valueNumberNotFinite(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonEncodingError,
                message: """
                    `Google_Protobuf_Value` cannot encode double values for \
                    infinity or nan, because they would be parsed as a string.
                """,
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Any fields that were decoded from binary format cannot be re-encoded into JSON unless the
        /// object they hold is a well-known type or a type registered via `Google_Protobuf_Any.register()`.
        public static func anyTypeURLNotRegistered(
            typeURL: String,
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonEncodingError,
                message: """
                    Any fields that were decoded from binary format cannot be re-encoded into JSON \
                    unless the object they hold is a well-known type or a type registered via \
                    `Google_Protobuf_Any.register()`. Type URL is \(typeURL).
                """,
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
    }
    
    /// Errors arising from JSON decoding of data into protobufs.
    public enum JSONDecoding {
        /// Something went wrong.
        public static func failure(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "Something went wrong.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }

        /// A number could not be parsed.
        public static func malformedNumber(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "A number could not be parsed.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Numeric value was out of range or was not an integer value when expected.
        public static func numberRange(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "Numeric value was out of range or was not an integer value when expected.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// A map could not be parsed.
        public static func malformedMap(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "A map could not be parsed.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// A bool could not be parsed.
        public static func malformedBool(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "A bool could not be parsed.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// We expected a quoted string, or a quoted string has a malformed backslash sequence.
        public static func malformedString(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "Expected a quoted string, or encountered a quoted string with a malformed backslash sequence.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// We encountered malformed UTF8.
        public static func invalidUTF8(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "Encountered malformed UTF8.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// The message does not have fieldName information.
        public static func missingFieldNames(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "The message does not have fieldName information.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// The data type does not match the schema description.
        public static func schemaMismatch(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "The data type does not match the schema description.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// A value (text or numeric) for an enum was not found on the enum.
        public static func unrecognizedEnumValue(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "A value (text or numeric) for an enum was not found on the enum.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// A 'null' token appeared in an illegal location.
        /// For example, Protobuf JSON does not allow 'null' tokens to appear in lists.
        public static func illegalNull(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "A 'null' token appeared in an illegal location.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// A map key was not quoted.
        public static func unquotedMapKey(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "A map key was not quoted.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// JSON RFC 7519 does not allow numbers to have extra leading zeros.
        public static func leadingZero(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "JSON RFC 7519 does not allow numbers to have extra leading zeros.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// We hit the end of the JSON string and expected something more.
        public static func truncated(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "Reached end of JSON string but expected something more.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// A JSON Duration could not be parsed.
        public static func malformedDuration(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "A JSON Duration could not be parsed.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// A JSON Timestamp could not be parsed.
        public static func malformedTimestamp(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "A JSON Timestamp could not be parsed.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// A FieldMask could not be parsed.
        public static func malformedFieldMask(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "A FieldMask could not be parsed.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Extraneous data remained after decoding should have been complete.
        public static func trailingGarbage(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError{
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "Extraneous data remained after decoding should have been complete.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// More than one value was specified for the same oneof field.
        public static func conflictingOneOf(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError{
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "More than one value was specified for the same oneof field.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Reached the nesting limit for messages within messages while decoding.
        public static func messageDepthLimit(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "Reached the nesting limit for messages within messages while decoding.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Encountered an unknown field with the given name.
        /// - Parameter name: The name of the unknown field.
        /// - Note: When parsing JSON, you can instead instruct the library to ignore this via
        /// `JSONDecodingOptions.ignoreUnknownFields`.
        public static func unknownField(
            _ name: String,
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: "Encountered an unknown field with name '\(name)'.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
    }
    
    /// Errors arising from text format decoding of data into protobufs.
    public enum TextFormatDecoding {
        /// Text data could not be parsed.
        public static func malformedText(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .textFormatDecodingError,
                message: "Text data could not be parsed",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// A number could not be parsed.
        public static func malformedNumber(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .textFormatDecodingError,
                message: "A number could not be parsed.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Extraneous data remained after decoding should have been complete.
        public static func trailingGarbage(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .textFormatDecodingError,
                message: "Extraneous data remained after decoding should have been complete.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// The data stopped before we expected.
        public static func truncated(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .textFormatDecodingError,
                message: "The data stopped before we expected.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// A string was not valid UTF8.
        public static func invalidUTF8(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .textFormatDecodingError,
                message: "A string was not valid UTF8.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// The data being parsed does not match the type specified in the proto file.
        public static func schemaMismatch(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .textFormatDecodingError,
                message: "The data being parsed does not match the type specified in the proto file.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Field names were not compiled into the binary.
        public static func missingFieldNames(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .textFormatDecodingError,
                message: "Field names were not compiled into the binary.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// A field identifier (name or number) was not found on the message.
        public static func unknownField(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .textFormatDecodingError,
                message: "A field identifier (name or number) was not found on the message.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// The enum value was not recognized.
        public static func unrecognizedEnumValue(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .textFormatDecodingError,
                message: "The enum value was not recognized.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Text format rejects conflicting values for the same oneof field.
        public static func conflictingOneOf(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .textFormatDecodingError,
                message: "Text format rejects conflicting values for the same oneof field.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// An internal error happened while decoding.  If this is ever encountered,
        /// please file an issue with SwiftProtobuf with as much details as possible
        /// for what happened (proto definitions, bytes being decoded (if possible)).
        public static func internalExtensionError(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .textFormatDecodingError,
                message: "An internal error happened while decoding: please file an issue with SwiftProtobuf.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
        
        /// Reached the nesting limit for messages within messages while decoding.
        public static func messageDepthLimit(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .textFormatDecodingError,
                message: "Reached the nesting limit for messages within messages while decoding.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
    }
    
    /// Describes errors that can occur when unpacking a `Google_Protobuf_Any`
    /// message.
    ///
    /// `Google_Protobuf_Any` messages can be decoded from protobuf binary, text
    /// format, or JSON. The contents are not parsed immediately; the raw data is
    /// held in the `Google_Protobuf_Any` message until you `unpack()` it into a
    /// message.  At this time, any error can occur that might have occurred from a
    /// regular decoding operation.  There are also other errors that can occur due
    /// to problems with the `Any` value's structure.
    public enum AnyUnpack {
        /// The `type_url` field in the `Google_Protobuf_Any` message did not match
        /// the message type provided to the `unpack()` method.
        public static func typeMismatch(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .invalidArgument,
                message: """
                    The `type_url` field in the `Google_Protobuf_Any` message did not match
                    the message type provided to the `unpack()` method.
                """,
                location: SourceLocation(function: function, file: file, line: line)
            )
        }

        /// Well-known types being decoded from JSON must have only two fields: the
        /// `@type` field and a `value` field containing the specialized JSON coding
        /// of the well-known type.
        public static func malformedWellKnownTypeJSON(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .jsonDecodingError,
                message: """
                    Malformed JSON type: well-known types being decoded from JSON must have only two fields:
                    the `@type` field and a `value` field containing the specialized JSON coding
                    of the well-known type.
                """,
                location: SourceLocation(function: function, file: file, line: line)
            )
        }

        /// The `Google_Protobuf_Any` message was malformed in some other way not
        /// covered by the other error cases.
        public static func malformedAnyField(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> SwiftProtobufError {
            SwiftProtobufError(
                code: .internalError,
                message: "The `Google_Protobuf_Any` message was malformed.",
                location: SourceLocation(function: function, file: file, line: line)
            )
        }
    }
}
