import SwiftUI

struct ChatBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer() }
            Text(text)
                .font(.system(size: 16))
                .padding(12)
                .background(isUser ? Color.blue.opacity(0.22) : Color.gray.opacity(0.16))
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
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

struct ChatView: View {
    @StateObject var vm = ChatVM()
    @State private var draft: String = ""
    @FocusState private var typing: Bool

    var body: some View {
        VStack(spacing: 0) {
            AgentHeader()

            if vm.isListening && !vm.partial.isEmpty {
                Text(vm.partial)
                    .font(.footnote).foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal).padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(vm.messages) { m in
                            ChatBubble(text: m.text, isUser: m.role == .user)
                                .id(m.id)
                        }
                    }
                    .padding(.top, 4)
                }
                .onChange(of: vm.messages.count) { _ in
                    if let last = vm.messages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onTapGesture { typing = false }
            }

            // Yazı alanı
            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("Type a message…")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                    }
                    TextEditor(text: $draft)
                        .font(.system(size: 16))
                        .frame(minHeight: 44, maxHeight: 46)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($typing)
                        .disabled(vm.isListening)
                        .opacity(vm.isListening ? 0.6 : 1)
                }

                Button("Send") { sendCurrent() }
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .disabled(vm.isListening || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal).padding(.vertical, 8)

            // mic / stop alanı
            VStack(spacing: 10) {
                // Ses seviyesi çubuğu
                ProgressView(value: Double(min(max(vm.level, 0), 1)))
                    .progressViewStyle(.linear)
                    .frame(height: 4)
                    .padding(.horizontal)

                Button(action: { vm.toggle() }) {
                    Image(systemName: vm.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .resizable().frame(width: 70, height: 70)
                        .foregroundStyle(vm.isListening ? .red : .blue)
                        .shadow(radius: 3, y: 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: vm.isListening)
                }
                Text(vm.isListening ? "Listening… tap to stop" : "Tap to speak")
                    .font(.footnote).foregroundColor(.secondary)
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 8) }
            .padding(.bottom, 8)
        }
        .animation(.default, value: vm.partial)
    }

    private func sendCurrent() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        draft = ""
        typing = false
        vm.sendTyped(t)
    }
}
