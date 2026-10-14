import SwiftUI

struct PasswordModalView: View {
    @ObservedObject var model: AppModel
    @State private var isSecured: Bool = true
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42))
                .foregroundColor(.orange)

            VStack(spacing: 6) {
                Text("Archive có mật khẩu")
                    .font(.headline)
                Text("Vui lòng nhập mật khẩu để mở hoặc giải nén nội dung:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if isSecured {
                        SecureField("Mật khẩu...", text: $model.passwordInput)
                            .focused($isFocused)
                    } else {
                        TextField("Mật khẩu...", text: $model.passwordInput)
                            .focused($isFocused)
                    }

                    Button(action: { isSecured.toggle() }) {
                        Image(systemName: isSecured ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isSecured ? "Hiển thị mật khẩu" : "Ẩn mật khẩu")
                }
                .textFieldStyle(.roundedBorder)

                if let err = model.passwordError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .frame(width: 320)

            HStack(spacing: 12) {
                Button("Huỷ") {
                    model.cancelPasswordPrompt()
                }
                .keyboardShortcut(.cancelAction)

                Button("Mở khoá") {
                    model.submitPassword()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.passwordInput.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear {
            isFocused = true
        }
    }
}
