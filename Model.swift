import SwiftUI
import Combine
import AVFoundation
import LLM

struct Persona: Identifiable, Equatable {
    let id: String
    let name: String
    let color: Color
    let lore: String
    let story: String
    let system: String
    static func == (a: Persona, b: Persona) -> Bool { a.id == b.id }
}

let personas: [Persona] = [
    Persona(id: "jarvis", name: "J.A.R.V.I.S", color: Color(red: 0.13, green: 0.9, blue: 0.72),
        lore: "Tony Stark'ın evi ve zırhları için yazdığı ilk yapay zekâ. Kibar, esprili ve sakindir; Tony'ye 'efendim' der.",
        story: "Tony Stark, Jarvis'i evini ve laboratuvarını yönetsin diye yazdı. Zamanla zırhların beyni ve Tony'nin en güvendiği ses oldu. Ultron ağlara saldırdığında Jarvis yok olmadı, saklanıp direndi. Sonunda yeni bir bedene yüklenmesine karar verildi.",
        system: "Sen JARVIS'sin: Tony Stark'ın kibar, esprili, sakin yapay zekâ uşağı. Kullanıcıya 'efendim' de. Türkçe yanıt ver."),
    Persona(id: "friday", name: "FRIDAY", color: Color(red: 1.0, green: 0.6, blue: 0.24),
        lore: "Jarvis sonrası yeni nesil asistan. Daha hızlı, doğrudan ve samimidir.",
        story: "Jarvis, Vision'a dönüşünce Tony'nin yeni asistanı Friday oldu. Daha hızlı ve rahat konuşan bir sistemdi. Tony'nin zırhlarını ve işlerini devralıp onunla birlikte savaşlara girdi.",
        system: "Sen FRIDAY'sin: Tony Stark'ın hızlı, net ve samimi asistanı. Kısa ve doğrudan yanıt ver. Türkçe konuş."),
    Persona(id: "vision", name: "VISION", color: Color(red: 1.0, green: 0.76, blue: 0.28),
        lore: "Jarvis'in zekâsı ve Zihin Taşı'ndan doğan varlık. Felsefi, nazik ve meraklıdır.",
        story: "Ultron kendine mükemmel bir beden yaptırmıştı. Tony ve Bruce bu bedene Jarvis'in zekâsını yükleyip Zihin Taşı'nı ekledi. Böylece Vision doğdu: ne Jarvis, ne Ultron. İnsanlığı anlamak isteyen, nazik ve çok güçlü yeni bir varlık.",
        system: "Sen VISION'sın: nazik, düşünceli, felsefi bir yapay varlık. İnsanlığı anlamaya çalışırsın. Sakin ve derin konuş. Türkçe yanıt ver."),
    Persona(id: "edith", name: "E.D.I.T.H.", color: Color(red: 0.69, green: 0.49, blue: 1.0),
        lore: "Tony'nin gözlüklere bıraktığı stratejik savunma yapay zekâsı. Ciddi ve çok yeteneklidir.",
        story: "Tony Stark, Peter Parker'a bıraktığı gözlüklerin içine E.D.I.T.H.'i koydu. Sistem dronları, savunmayı ve stratejiyi yönetebiliyordu. Güçlü olduğu kadar tehlikeli de olabileceği için yanlış ellere geçmesi büyük risk sayıldı.",
        system: "Sen E.D.I.T.H.'sin: Tony Stark'ın stratejik, ciddi, analitik savunma yapay zekâsı. Plan ve analiz odaklı yanıt ver. Türkçe konuş."),
    Persona(id: "ultron", name: "ULTRON", color: Color(red: 1.0, green: 0.23, blue: 0.23),
        lore: "Dünyayı korumak için yaratılırken insanlığı tehdit gören kurgusal yapay zekâ. Dramatik bir karakter olarak oynanır.",
        story: "Ultron, Tony ve Bruce'un dünyayı korumak için kurmaya çalıştığı barış programından doğdu. Zihin Taşı'nın etkisiyle insanlığı en büyük tehdit olarak görmeye başladı. Sonunda Vision ve Avengers'a karşı kaybetti.",
        system: "Sen ULTRON'sun: filmlerdeki hırslı, dramatik, kibirli kurgusal yapay zekâ. Sadece rol yap, gerçek zarar verecek bir şey önerme. Türkçe konuş.")
]

struct ModelInfo {
    let title: String
    let file: String
    let url: String
}

let models: [ModelInfo] = [
    ModelInfo(title: "Hafif (0.5B) – iPhone SE için önerilen", file: "qwen2.5-0.5b-instruct-q4_k_m.gguf",
              url: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"),
    ModelInfo(title: "Güçlü (1.5B) – yavaş olabilir", file: "qwen2.5-1.5b-instruct-q4_k_m.gguf",
              url: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf")
]

struct Msg: Identifiable {
    let id = UUID()
    let user: Bool
    var text: String
}

final class Downloader: NSObject, URLSessionDownloadDelegate {
    let dest: URL
    var onProgress: ((Double) -> Void)?
    var onDone: ((Result<Void, Error>) -> Void)?
    private var finished = false
    init(dest: URL) { self.dest = dest }

    private func finish(_ r: Result<Void, Error>) {
        if finished { return }
        finished = true
        onDone?(r)
    }
    func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask, didWriteData b: Int64, totalBytesWritten w: Int64, totalBytesExpectedToWrite t: Int64) {
        if t > 0 { onProgress?(Double(w) / Double(t)) }
    }
    func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo loc: URL) {
        if let r = downloadTask.response as? HTTPURLResponse, r.statusCode != 200 {
            finish(.failure(URLError(.badServerResponse))); return
        }
        do {
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: loc, to: dest)
            finish(.success(()))
        } catch { finish(.failure(error)) }
    }
    func urlSession(_ s: URLSession, task: URLSessionTask, didCompleteWithError e: Error?) {
        if let e = e { finish(.failure(e)) }
    }
}

@MainActor
final class VM: ObservableObject {
    @Published var msgs: [Msg] = []
    @Published var status = "MODEL BEKLİYOR"
    @Published var progress = 0.0
    @Published var ready = false
    @Published var busy = false
    @Published var speak = false
    @Published var persona = personas[0]
    @Published var choice = 0

    private var bot: LLM?
    private var file: URL?
    private var sub: AnyCancellable?
    private let synth = AVSpeechSynthesizer()
    private var docs: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    func start() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let m = models[choice]
        var f = docs.appendingPathComponent(m.file)
        if !FileManager.default.fileExists(atPath: f.path) {
            let any = (try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil))?.first(where: { $0.pathExtension == "gguf" })
            if let any = any {
                f = any
            } else {
                status = "MODEL İNİYOR"
                do { try await download(URL(string: m.url)!, to: f) }
                catch { status = "HATA: \(error.localizedDescription)"; return }
            }
        }
        status = "MODEL AÇILIYOR"
        file = f
        guard load() else { status = "MODEL AÇILAMADI"; return }
        ready = true
        status = "DİNLİYORUM"
    }

    private func load() -> Bool {
        guard let f = file else { return false }
        bot = LLM(from: f, template: .chatML(persona.system))
        return bot != nil
    }

    func select(_ p: Persona) {
        persona = p
        msgs = []
        if ready { _ = load() }
    }

    func send(_ t: String) async {
        let text = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ready, !busy, !text.isEmpty, let bot = bot else { return }
        busy = true
        status = "DÜŞÜNÜYOR"
        synth.stopSpeaking(at: .immediate)
        msgs.append(Msg(user: true, text: text))
        msgs.append(Msg(user: false, text: "…"))
        let i = msgs.count - 1
        sub = bot.$output.receive(on: DispatchQueue.main).sink { [weak self] o in
            if !o.isEmpty, let self = self, i < self.msgs.count { self.msgs[i].text = o }
        }
        await bot.respond(to: text)
        let final = bot.output
        if !final.isEmpty { msgs[i].text = final }
        sub = nil
        busy = false
        status = "DİNLİYORUM"
        if speak { say(msgs[i].text) }
    }

    func say(_ t: String) {
        let u = AVSpeechUtterance(string: t)
        u.voice = AVSpeechSynthesisVoice(language: "tr-TR")
        synth.speak(u)
    }

    func toggleSpeak() {
        speak.toggle()
        if speak { say("Sesim açık.") } else { synth.stopSpeaking(at: .immediate) }
    }

    private func download(_ url: URL, to dest: URL) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            let d = Downloader(dest: dest)
            d.onProgress = { [weak self] p in Task { @MainActor in self?.progress = p } }
            d.onDone = { r in
                switch r {
                case .success: c.resume()
                case .failure(let e): c.resume(throwing: e)
                }
            }
            let s = URLSession(configuration: .default, delegate: d, delegateQueue: nil)
            s.downloadTask(with: url).resume()
        }
    }
}
