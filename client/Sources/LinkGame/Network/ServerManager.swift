import Foundation

@MainActor
class ServerManager: ObservableObject {
    enum Status: Equatable {
        case stopped
        case starting
        case running
        case failed(String)
    }

    @Published var status: Status = .stopped

    private var process: Process?
    private let port = 9090

    func start() {
        if case .running = status { return }
        if case .starting = status { return }

        status = .starting

        // 先检查服务器是否已在运行（例如被另一个 App 实例启动）
        checkExistingServer { [weak self] alreadyRunning in
            guard let self = self else { return }
            if alreadyRunning {
                self.status = .running
                return
            }
            self.launchServer()
        }
    }

    private func checkExistingServer(completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: URL(string: "http://localhost:\(port)/api/health")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 1
        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                let ok = (response as? HTTPURLResponse)?.statusCode == 200
                completion(ok)
            }
        }.resume()
    }

    private func launchServer() {
        var foundPath: String?
        var searchPaths: [String] = []

        if let rp = Bundle.main.resourcePath {
            searchPaths.append(rp + "/linkgame-server")
        }
        if let ep = Bundle.main.executablePath {
            let exeDir = (ep as NSString).deletingLastPathComponent
            searchPaths.append(exeDir + "/../Resources/linkgame-server")
        }
        searchPaths.append(NSHomeDirectory() + "/linkgame/server/linkgame-server")

        for p in searchPaths {
            if FileManager.default.fileExists(atPath: p) {
                foundPath = p
                break
            }
        }

        guard let path = foundPath else {
            status = .failed("找不到服务器程序，请先编译后端")
            return
        }

        let serverProc = Process()
        serverProc.executableURL = URL(fileURLWithPath: path)

        var env = ProcessInfo.processInfo.environment
        env["QQ_MAIL_AUTH_CODE"] = "qbiezwuwwfvbeaib"
        env["TZ"] = "Asia/Shanghai"
        serverProc.environment = env

        let outPipe = Pipe()
        serverProc.standardOutput = outPipe
        serverProc.standardError = outPipe

        do {
            try serverProc.run()
            process = serverProc
        } catch {
            status = .failed("启动服务器失败: \(error.localizedDescription)")
            return
        }

        checkHealthAsync(proc: serverProc)
    }

    private func checkHealthAsync(proc: Process) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.pollHealth(proc: proc, until: Date().addingTimeInterval(5))
        }
    }

    private func pollHealth(proc: Process, until deadline: Date) {
        guard Date() < deadline, proc.isRunning else {
            if proc.isRunning { status = .failed("服务器启动超时") }
            return
        }

        var request = URLRequest(url: URL(string: "http://localhost:\(port)/api/health")!)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    self?.status = .running
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.pollHealth(proc: proc, until: deadline)
                    }
                }
            }
        }.resume()
    }

    func stop() {
        process?.terminate()
        process = nil
        status = .stopped
    }
}
