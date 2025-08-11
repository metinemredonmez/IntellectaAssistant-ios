import SwiftUI

struct ChatBubble: View {
    let text: String
    let isUser: Bool
    var body: some View {
        HStack {
            if isUser { Spacer() }
            Text(text)
                .padding(12)
                .background(isUser ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer() }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

struct AgentHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.horizontal.circle.fill").font(.largeTitle)
            VStack(alignment: .leading, spacing: 2) {
                Text("Intellecta – Meeting Assistant").font(.headline)
                Text("Speakable, short answers • EN-only")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
    }
}

struct ChatView: View {
    @StateObject var vm = ChatVM()
    @State private var draft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            AgentHeader()

            if vm.isListening && !vm.partial.isEmpty {
                Text(vm.partial)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(vm.messages) { m in
                            ChatBubble(text: m.text, isUser: m.role == .user)
                                .id(m.id)
                        }
                    }
                }
                .onChange(of: vm.messages.count) { _ in
                    if let last = vm.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Type a message…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    let t = draft; draft = ""
                    vm.sendTyped(t)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Button(action: { vm.toggle() }) {
                Image(systemName: vm.isListening ? "stop.circle.fill" : "mic.circle.fill")
                    .resizable().frame(width: 64, height: 64)
            }
            .padding(.bottom, 16)
        }
    }
}
