import Foundation

struct RemoteCommand: Hashable, Sendable {
    let name: String
    let codeSet: Int
    let code: Int
    let action: String

    init(_ name: String, codeSet: Int, code: Int, action: String = "KEYPRESS") {
        self.name = name
        self.codeSet = codeSet
        self.code = code
        self.action = action
    }

    static let down = RemoteCommand("Down", codeSet: 3, code: 0)
    static let left = RemoteCommand("Left", codeSet: 3, code: 1)
    static let select = RemoteCommand("OK", codeSet: 3, code: 2)
    static let right = RemoteCommand("Right", codeSet: 3, code: 7)
    static let up = RemoteCommand("Up", codeSet: 3, code: 8)

    static let back = RemoteCommand("Back", codeSet: 4, code: 0)
    // SmartCast is 4/3; the actual Home command is 4/15.
    static let home = RemoteCommand("Home", codeSet: 4, code: 15)
    static let menu = RemoteCommand("Menu", codeSet: 4, code: 8)

    static let volumeDown = RemoteCommand("Volume down", codeSet: 5, code: 0)
    static let volumeUp = RemoteCommand("Volume up", codeSet: 5, code: 1)
    static let mute = RemoteCommand("Mute", codeSet: 5, code: 4)

    static let input = RemoteCommand("Input", codeSet: 7, code: 1)
    static let channelDown = RemoteCommand("Channel down", codeSet: 8, code: 0)
    static let channelUp = RemoteCommand("Channel up", codeSet: 8, code: 1)

    static let pause = RemoteCommand("Pause", codeSet: 2, code: 2)
    static let play = RemoteCommand("Play", codeSet: 2, code: 3)

    static let power = RemoteCommand("Power", codeSet: 11, code: 2)

    var payload: [String: Any] {
        [
            "KEYLIST": [[
                "CODESET": codeSet,
                "CODE": code,
                "ACTION": action
            ]]
        ]
    }
}
