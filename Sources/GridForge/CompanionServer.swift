import Foundation
import Network
import GridForgeCore

/// CompanionServer — lightweight NWListener HTTP/1.1 server on localhost:14731.
///
/// Exposes all GridForge UI actions as REST routes so Claude and other AI tools
/// can drive the app headlessly (HEADLESS/UI PARITY convention, 2026-06-02):
///
///   GET  /get-state        — version, hotkey, layouts[], shortcuts[], snapshots[]
///   GET  /list-layouts     — [{id, name, entries[]}]
///   POST /apply-layout     — {"name":"Code Mode"}
///   POST /save-layout      — {"name":"Code Mode"}
///   GET  /list-shortcuts   — [{keyCombo, selection, name}]
///   GET  /list-snapshots   — [{id, name, createdAt, entryCount}]
///   POST /apply-snapshot   — {"name":"Work"}
///   POST /set-window       — {"colStart":0,"rowStart":0,"colEnd":2,"rowEnd":3}
///   GET  /analytics        — stub; full implementation in GH#11
///
/// Port: UserDefaults "gf_companion_port" (default 14731).
/// Started from AppState.setup(); one instance per app lifetime.
final class CompanionServer {

    // MARK: - Constants

    static let defaultPort: UInt16 = 14731
    static let portDefaultsKey     = "gf_companion_port"

    // MARK: - State

    private let listener:  NWListener
    private weak var appState: AppState?
    private let queue = DispatchQueue(label: "com.gridforge.companion", qos: .utility)

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Lifecycle

    init(appState: AppState) {
        self.appState = appState

        let raw     = UserDefaults.standard.integer(forKey: Self.portDefaultsKey)
        let portNum = (raw >= 1024 && raw <= 65535) ? UInt16(raw) : Self.defaultPort
        let nwPort  = NWEndpoint.Port(rawValue: portNum) ?? NWEndpoint.Port(rawValue: Self.defaultPort)!

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: nwPort)

        do {
            listener = try NWListener(using: params, on: nwPort)
        } catch {
            NSLog("GridForge CompanionServer: init error: %@", error.localizedDescription)
            listener = try! NWListener(using: .tcp, on: nwPort)
        }
    }

    func start() {
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                let p = self?.listener.port?.rawValue ?? 0
                NSLog("GridForge CompanionServer: ready on port %d", p)
            case .failed(let error):
                NSLog("GridForge CompanionServer: failed — %@", error.localizedDescription)
            case .cancelled:
                NSLog("GridForge CompanionServer: cancelled")
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] conn in self?.handleConnection(conn) }
        listener.start(queue: queue)
    }

    func stop() { listener.cancel() }

    // MARK: - Connection

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.dispatch(raw: String(data: data, encoding: .utf8) ?? "", connection: connection)
            } else if isComplete || error != nil {
                connection.cancel()
            }
        }
    }

    // MARK: - Dispatch

    private func dispatch(raw: String, connection: NWConnection) {
        let lines  = raw.components(separatedBy: "\r\n")
        let tokens = (lines.first ?? "").split(separator: " ", maxSplits: 2)
        guard tokens.count >= 2 else {
            send(status: 400, body: "{\"error\":\"bad request\"}", to: connection); return
        }
        let method = String(tokens[0]).uppercased()
        let path   = String(tokens[1])

        var jsonBody: [String: Any]? = nil
        if let sep = raw.range(of: "\r\n\r\n") {
            let bodyStr = String(raw[sep.upperBound...])
            if !bodyStr.isEmpty, let d = bodyStr.data(using: .utf8) {
                jsonBody = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
            }
        }

        switch (method, path) {
        case ("GET",  "/get-state"):      handleGetState(connection: connection)
        case ("GET",  "/list-layouts"):   handleListLayouts(connection: connection)
        case ("POST", "/apply-layout"):   handleApplyLayout(body: jsonBody, connection: connection)
        case ("POST", "/save-layout"):    handleSaveLayout(body: jsonBody, connection: connection)
        case ("GET",  "/list-shortcuts"): handleListShortcuts(connection: connection)
        case ("GET",  "/list-snapshots"): handleListSnapshots(connection: connection)
        case ("POST", "/apply-snapshot"): handleApplySnapshot(body: jsonBody, connection: connection)
        case ("POST", "/set-window"):     handleSetWindow(body: jsonBody, connection: connection)
        case ("GET",  "/analytics"):      handleAnalytics(connection: connection)
        default:
            send(status: 404, body: "{\"error\":\"not found\",\"path\":\"\(path)\"}", to: connection)
        }
    }

    // MARK: - Route handlers

    private func handleGetState(connection: NWConnection) {
        Task { @MainActor [weak self] in
            guard let self, let s = self.appState else { return }
            let result: [String: Any] = [
                "version":       AppVersion.current,
                "hotkeyCode":    s.hotkeyCode,
                "hotkeyMods":    s.hotkeyModifiers.rawValue,
                "activeDisplay":  s.currentProfileKey,
                "layouts":       s.layouts.map   { ["id": $0.id, "name": $0.name] },
                "shortcuts":     s.shortcuts.map { ["keyCombo": $0.keyCombo, "selection": $0.selection.encoded, "name": $0.name ?? ""] as [String: Any] },
                "snapshots":     s.snapshots.map { ["id": $0.id, "name": $0.name, "entryCount": $0.entries.count] as [String: Any] }
            ]
            self.sendJSON(result, to: connection)
        }
    }

    private func handleListLayouts(connection: NWConnection) {
        Task { @MainActor [weak self] in
            guard let self, let s = self.appState else { return }
            let result: [[String: Any]] = s.layouts.map { l in
                ["id": l.id, "name": l.name,
                 "entries": l.entries.map { e -> [String: Any] in
                     ["bundleID": e.bundleID, "displayID": e.displayID, "selection": e.selection.encoded]
                 }]
            }
            self.sendJSON(result, to: connection)
        }
    }

    private func handleApplyLayout(body: [String: Any]?, connection: NWConnection) {
        guard let name = body?["name"] as? String, !name.isEmpty else {
            send(status: 400, body: "{\"error\":\"missing name\"}", to: connection); return
        }
        Task { @MainActor [weak self] in
            guard let self, let s = self.appState else { return }
            if let layout = s.layouts.first(where: { $0.name == name }) {
                s.applyLayout(layout)
                self.sendJSON(["ok": true, "applied": name], to: connection)
            } else {
                self.sendJSON(["ok": false, "error": "layout not found: \(name)"], to: connection)
            }
        }
    }

    private func handleSaveLayout(body: [String: Any]?, connection: NWConnection) {
        guard let name = body?["name"] as? String, !name.isEmpty else {
            send(status: 400, body: "{\"error\":\"missing name\"}", to: connection); return
        }
        Task { @MainActor [weak self] in
            guard let self, let s = self.appState else { return }
            s.saveCurrentAsLayout(name: name)
            self.sendJSON(["ok": true, "name": name], to: connection)
        }
    }

    private func handleListShortcuts(connection: NWConnection) {
        Task { @MainActor [weak self] in
            guard let self, let s = self.appState else { return }
            let result: [[String: Any]] = s.shortcuts.map {
                ["keyCombo": $0.keyCombo, "selection": $0.selection.encoded, "name": $0.name ?? ""]
            }
            self.sendJSON(result, to: connection)
        }
    }

    private func handleListSnapshots(connection: NWConnection) {
        Task { @MainActor [weak self] in
            guard let self, let s = self.appState else { return }
            let iso = Self.isoFormatter
            let result: [[String: Any]] = s.snapshots.map {
                ["id": $0.id, "name": $0.name,
                 "createdAt": iso.string(from: $0.createdAt),
                 "entryCount": $0.entries.count]
            }
            self.sendJSON(result, to: connection)
        }
    }

    private func handleApplySnapshot(body: [String: Any]?, connection: NWConnection) {
        guard let name = body?["name"] as? String, !name.isEmpty else {
            send(status: 400, body: "{\"error\":\"missing name\"}", to: connection); return
        }
        Task { @MainActor [weak self] in
            guard let self, let s = self.appState else { return }
            if let snap = s.snapshots.first(where: { $0.name == name }) {
                s.restoreSnapshot(snap)
                self.sendJSON(["ok": true, "applied": name], to: connection)
            } else {
                self.sendJSON(["ok": false, "error": "snapshot not found: \(name)"], to: connection)
            }
        }
    }

    private func handleSetWindow(body: [String: Any]?, connection: NWConnection) {
        guard let b = body,
              let colStart = (b["colStart"] as? NSNumber)?.intValue,
              let rowStart = (b["rowStart"] as? NSNumber)?.intValue,
              let colEnd   = (b["colEnd"]   as? NSNumber)?.intValue,
              let rowEnd   = (b["rowEnd"]   as? NSNumber)?.intValue else {
            send(status: 400,
                 body: "{\"error\":\"required: colStart, rowStart, colEnd, rowEnd (ints)\"}",
                 to: connection)
            return
        }
        let sel = GridSelection(startCell: GridCell(col: colStart, row: rowStart),
                                endCell:   GridCell(col: colEnd,   row: rowEnd))
        Task { @MainActor [weak self] in
            guard let self, let s = self.appState else { return }
            let screen = s.windowManager.screenForFocusedWindow()
            s.applySelection(sel, on: screen)
            self.sendJSON(["ok": true], to: connection)
        }
    }

    private func handleAnalytics(connection: NWConnection) {
        // TODO(GH#11): replace stub with appState.analyticsReport() serialised to JSON.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.sendJSON([
                "topPositions":    [Any](),
                "layoutFrequency": [Any](),
                "perAppUsage":     [Any]()
            ], to: connection)
        }
    }

    // MARK: - Response helpers

    private func sendJSON(_ object: Any, to connection: NWConnection) {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            send(status: 500, body: "{\"error\":\"serialization failed\"}", to: connection)
            return
        }
        send(status: 200, body: String(data: data, encoding: .utf8) ?? "{}", to: connection)
    }

    private func send(status: Int, body: String, to connection: NWConnection) {
        let phrase: String
        switch status {
        case 200: phrase = "OK"
        case 400: phrase = "Bad Request"
        case 404: phrase = "Not Found"
        default:  phrase = "Internal Server Error"
        }
        let raw = "HTTP/1.1 \(status) \(phrase)\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        guard let data = raw.data(using: .utf8) else { connection.cancel(); return }
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
    }
}
