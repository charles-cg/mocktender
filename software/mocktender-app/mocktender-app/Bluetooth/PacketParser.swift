import Foundation

// Mirror of the FSM states declared in firmware/include/fsm.h. The firmware
// transmits these as raw bytes (0…8) in the `State:` field of every packet.
// Cup remains ASCII ('0'…'3') because classifyCup() emits a character.
enum FirmwareState: UInt8 {
    case calibrate   = 0
    case idle        = 1
    case cupPlaced   = 2
    case dispense    = 3
    case deliver     = 4
    case maintenance = 5
    case cleaning    = 6
    case refill      = 7
    case error       = 8
}

// One parsed packet from the Atmega.
//
// Wire format (firmware/src/USART.c::sendPacket):
//
//   State:<1>,Cup:<1>,Error:<1>,OJ:<2>,PJ:<2>,CJ:<2>,LJ:<2>,GR:<2>,GS:<2>\r\n
//
// State and Error are single raw bytes (0…N); Cup is an ASCII digit
// emitted by classifyCup(). The six bottle fields (OJ…GS) are
// `uint16_t usedMl[i]` from EEPROM, transmitted little-endian (low byte
// first), in pump order P1…P6.
struct MachinePacket: Equatable {
    var state: FirmwareState
    var cupClass: UInt8
    var errorCode: UInt8
    /// usedMl per pump, indexed P1…P6 (i.e. OJ, PJ, CJ, LJ, GR, GS). Each
    /// value is the 16-bit `usedMl[i]` straight from the firmware, transmitted
    /// little-endian (low byte first).
    var usedMl: [UInt16]    // count == 6
}

/// Streaming parser that consumes UART bytes as they arrive over BLE and emits
/// a packet each time a complete frame has been seen.
///
/// The frame is fixed-length (51 bytes) so the parser slides forward looking
/// for the literal `State:` prefix, then reads the remaining bytes
/// positionally. The value bytes can contain anything (including `,`, `\r`,
/// `\n`) so we cannot split on delimiters.
struct PacketParser {
    private static let header: [UInt8] = Array("State:".utf8)
    // Offsets of the payload bytes, measured from the start of the 59-byte
    // frame. State/Cup/Error are 1 byte each; the six bottle fields are 2
    // bytes (little-endian uint16). Bottle offsets point at the LOW byte.
    //   0:  State:_
    //   7:  ,Cup:_
    //   13: ,Error:_
    //   21: ,OJ:__   27: ,PJ:__   33: ,CJ:__
    //   39: ,LJ:__   45: ,GR:__   51: ,GS:__
    //   57: \r\n    (frame length = 59)
    static let frameLength = 59
    private static let stateOffset = 6
    private static let cupOffset = 12
    private static let errorOffset = 20
    private static let bottleOffsets: [Int] = [25, 31, 37, 43, 49, 55]

    private var buffer: [UInt8] = []

    mutating func feed(_ data: Data) -> [MachinePacket] {
        buffer.append(contentsOf: data)
        var out: [MachinePacket] = []

        while let frameStart = indexOfHeader() {
            // Drop anything before the header — partial frame or noise.
            if frameStart > 0 {
                buffer.removeFirst(frameStart)
            }
            guard buffer.count >= Self.frameLength else { break }
            if let pkt = parseFrame(buffer.prefix(Self.frameLength)) {
                out.append(pkt)
            }
            // Skip past the parsed (or unparseable) frame and keep scanning.
            // Skipping the whole frame on parse failure avoids re-matching the
            // same bad header forever.
            buffer.removeFirst(Self.frameLength)
        }

        // Cap the buffer so a stream that never matches doesn't grow forever.
        if buffer.count > 4 * Self.frameLength {
            buffer.removeFirst(buffer.count - 2 * Self.frameLength)
        }
        return out
    }

    private func indexOfHeader() -> Int? {
        let h = Self.header
        if buffer.count < h.count { return nil }
        outer: for i in 0...(buffer.count - h.count) {
            for j in 0..<h.count where buffer[i + j] != h[j] {
                continue outer
            }
            return i
        }
        return nil
    }

    private func parseFrame(_ bytes: ArraySlice<UInt8>) -> MachinePacket? {
        let base = bytes.startIndex
        // State and Error are raw bytes; cup is ASCII from classifyCup().
        let stateRaw = bytes[base + Self.stateOffset]
        let errorRaw = bytes[base + Self.errorOffset]
        guard let state = FirmwareState(rawValue: stateRaw) else { return nil }
        let cup = bytes[base + Self.cupOffset]
        let err = errorRaw
        let used: [UInt16] = Self.bottleOffsets.map { off in
            let lo = UInt16(bytes[base + off])
            let hi = UInt16(bytes[base + off + 1])
            return lo | (hi << 8)
        }
        return MachinePacket(state: state, cupClass: cup, errorCode: err, usedMl: used)
    }
}
