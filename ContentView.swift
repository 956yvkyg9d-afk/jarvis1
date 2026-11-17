import SwiftUI

struct Ring: View {
    let c: Color
    @State private var a = false
    var body: some View {
        ZStack {
            Circle().stroke(c.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .rotationEffect(.degrees(a ? 360 : 0))
            Circle().inset(by: 12).trim(from: 0, to: 0.75).stroke(c, lineWidth: 3)
                .rotationEffect(.degrees(a ? -360 : 0))
            Circle().inset(by: 30).stroke(c, lineWidth: 2).shadow(color: c, radius: a ? 14 : 4)
        }
        .frame(width: 100, height: 100)
        .onAppear { withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { a = true } }
    }
}

struct ContentView: View {
    @StateObject private var vm = VM()
    @State private var input = ""
    @State private var showStory = false
    @State private var overlay: String? = nil

    var body: some View {
        let c = vm.persona.color
        ZStack {
            Color(red: 0.01, green: 0.06, blue: 0.06).ignoresSafeArea()
            VStack(spacing: 8) {
                HStack {
                    Text(vm.persona.name).font(.system(.headline, design: .monospaced)).foregroundColor(c).tracking(4)
                    Spacer()
                    Button(vm.speak ? "🔊" : "🔇") { vm.toggleSpeak() }
                    Button("YENİ") { vm.msgs = [] }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(personas) { p in
                            Button(p.name) { vm.select(p); showStory = false }
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(p == vm.persona ? p.color : Color.gray.opacity(0.4)))
                                .foregroundColor(p.color)
                        }
                    }
                }
                Ring(c: c)
                Text(vm.status).font(.system(size: 11, design: .monospaced)).foregroundColor(c).tracking(3)
                Text(showStory ? vm.persona.story : vm.persona.lore)
                    .font(.system(size: 12, design: .monospaced)).foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                    .background(Color.white.opacity(0.05))
                HStack {
                    Button("📖 HİKÂYE") { showStory.toggle() }
                    Spacer()
                    Button("⚡ VISION'A DÖNÜŞÜM") { Task { await morph() } }
                }.font(.system(size: 12, design: .monospaced)).foregroundColor(c)
                if !vm.ready { setup }
                chat
                HStack {
                    TextField("Yazılı komut gönder...", text: $input).textFieldStyle(.roundedBorder).onSubmit(go)
                    Button("▶") { go() }
                }.padding(.bottom, 6)
            }
            .padding(.horizontal, 14)
            if let o = overlay {
                Color.black.opacity(0.92).ignoresSafeArea()
                Text(o).font(.system(size: 18, design: .monospaced)).foregroundColor(c).tracking(3).multilineTextAlignment(.center)
            }
        }
        .tint(c)
    }

    var setup: some View {
        VStack(spacing: 8) {
            Picker("Model", selection: $vm.choice) {
                ForEach(0..<models.count, id: \.self) { Text(models[$0].title).tag($0) }
            }
            Button("MODELİ İNDİR VE BAŞLAT") { Task { await vm.start() } }.disabled(vm.busy)
            if vm.busy && vm.progress > 0 { ProgressView(value: vm.progress) }
            Text("Model tek seferlik iner (Wi-Fi öner, ekranı açık tut). Sonra tamamen internetsiz çalışır.")
                .font(.caption).foregroundColor(.gray)
        }
    }

    var chat: some View {
        ScrollViewReader { r in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(vm.msgs) { m in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.user ? "SİZ" : vm.persona.name)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(m.user ? .gray : vm.persona.color)
                            Text(m.text).font(.system(size: 14, design: .monospaced))
                        }
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05)).id(m.id)
                    }
                }
            }
            .onChange(of: vm.msgs.last?.text) { _ in
                if let l = vm.msgs.last { r.scrollTo(l.id) }
            }
        }
    }

    func go() {
        let t = input
        input = ""
        Task { await vm.send(t) }
    }

    func morph() async {
        for s in ["Jarvis çekirdeği toplanıyor...", "Zihin Taşı bağlanıyor...", "Beden senkronu: %100", "VISION uyandı."] {
            overlay = s
            try? await Task.sleep(nanoseconds: 1_300_000_000)
        }
        vm.select(personas[2])
        overlay = nil
    }
}
