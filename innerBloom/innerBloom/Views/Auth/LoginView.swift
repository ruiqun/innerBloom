//
//  LoginView.swift
//  innerBloom
//
//  登入/註冊頁面 - S-004, B-018
//  支持：Email OTP（一次性驗證碼）/ Email + 密碼
//  V2: Dark Luxury Gold 風格升級
//

import SwiftUI

/// 登入方式
private enum LoginMode {
    case otp       // Email OTP（驗證碼）
    case password  // Email + 密碼
}

/// 登入流程步驟（OTP 模式）
private enum OTPStep {
    case enterEmail   // 輸入 Email
    case enterCode    // 輸入驗證碼
}

struct LoginView: View {
    
    // MARK: - Properties
    
    @Bindable private var authManager = AuthManager.shared
    @Bindable private var localization = LocalizationManager.shared
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var otpCode: String = ""
    @State private var loginMode: LoginMode = .password
    @State private var otpStep: OTPStep = .enterEmail
    @State private var isSignUpMode: Bool = false
    @State private var showError: Bool = false
    @State private var errorText: String = ""
    @State private var showCodeSentToast: Bool = false
    @State private var showSignUpSuccessToast: Bool = false
    
    /// 動畫用
    @State private var logoScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0.0
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 背景（暖黑漸層）
            Theme.background
                .ignoresSafeArea()
            
            // 微妙金色背景裝飾
            backgroundDecoration
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 80)
                    
                    // Logo 區域
                    logoSection
                        .scaleEffect(logoScale)
                    
                    Spacer()
                        .frame(height: 48)
                    
                    // 主要內容區域
                    VStack(spacing: 24) {
                        // 登入表單
                        loginFormSection
                        
                        // 主操作按鈕
                        primaryActionButton
                        
                        // 切換登入方式
                        switchModeSection
                        
                        // 隱私提示
                        privacyHintSection
                    }
                    .padding(.horizontal, 32)
                    .opacity(contentOpacity)
                    
                    Spacer()
                        .frame(height: 60)
                }
            }
        }
        .alert(String.localized(.hint), isPresented: $showError) {
            Button(String.localized(.confirm)) {
                authManager.clearError()
            }
        } message: {
            Text(errorText)
        }
        // Toast 提示
        .overlay {
            if showCodeSentToast {
                codeSentToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if showSignUpSuccessToast {
                signUpSuccessToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                logoScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                contentOpacity = 1.0
            }
        }
        .id(localization.languageChangeId)
    }
    
    // MARK: - Logo 區域（App 圖標 + 深色玻璃擬態 + 金色光暈）
    
    private var logoSection: some View {
        VStack(spacing: 16) {
            // App Logo — 深色玻璃擬態圓形 + App 圖標（有人頭）
            ZStack {
                // 極淡金色光暈（精品招牌燈感）
                Circle()
                    .fill(Theme.goldLight.opacity(0.08))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                // 深色玻璃擬態底
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 100, height: 100)
                
                // 極細金色描邊（1px）
                Circle()
                    .stroke(Theme.accent.opacity(0.4), lineWidth: 1)
                    .frame(width: 100, height: 100)
                
                // App 圖標（與外圈同大、貼齊）
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 135, height: 135)
                    .clipShape(Circle())
                    .shadow(color: Theme.goldLight.opacity(0.3), radius: 8, x: 0, y: 0)
            }
            
            // 歡迎文字
            Text(String.localized(.loginWelcome))
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundColor(Theme.textPrimary)
            
            Text(String.localized(.loginSubtitle))
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
        }
    }
    
    // MARK: - 登入表單
    
    private var loginFormSection: some View {
        VStack(spacing: 16) {
            switch loginMode {
            case .otp:
                otpFormSection
            case .password:
                passwordFormSection
            }
        }
    }
    
    // MARK: - OTP 表單
    
    private var otpFormSection: some View {
        VStack(spacing: 16) {
            // Email 輸入
            LoginTextField(
                icon: "envelope",
                placeholder: String.localized(.enterEmail),
                text: $email,
                keyboardType: .emailAddress,
                isEnabled: otpStep == .enterEmail
            )
            
            if otpStep == .enterCode {
                // 驗證碼輸入
                LoginTextField(
                    icon: "lock.shield",
                    placeholder: String.localized(.enterVerificationCode),
                    text: $otpCode,
                    keyboardType: .numberPad,
                    isEnabled: true
                )
                
                // 重新發送提示
                Button(action: {
                    otpStep = .enterEmail
                    otpCode = ""
                }) {
                    Text("< " + String.localized(.loginWithOTP))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.accent)
                }
            }
        }
    }
    
    // MARK: - 密碼表單
    
    private var passwordFormSection: some View {
        VStack(spacing: 16) {
            // Email 輸入
            LoginTextField(
                icon: "envelope",
                placeholder: String.localized(.enterEmail),
                text: $email,
                keyboardType: .emailAddress,
                isEnabled: true
            )
            
            // 密碼輸入
            LoginSecureField(
                icon: "lock",
                placeholder: String.localized(.enterPassword),
                text: $password
            )
            
            if isSignUpMode {
                Text(String.localized(.passwordMinLength))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
            }
        }
    }
    
    // MARK: - 主操作按鈕
    
    private var primaryActionButton: some View {
        Button(action: performPrimaryAction) {
            HStack(spacing: 8) {
                if authManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                }
                
                Text(primaryButtonText)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(primaryButtonEnabled ? Theme.accent : Theme.accent.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.goldLight.opacity(primaryButtonEnabled ? 0.3 : 0), lineWidth: 0.5)
            )
        }
        .disabled(!primaryButtonEnabled || authManager.isLoading)
    }
    
    /// 主按鈕文字
    private var primaryButtonText: String {
        if authManager.isLoading {
            switch loginMode {
            case .otp:
                return otpStep == .enterEmail
                    ? String.localized(.sendingCode)
                    : String.localized(.verifying)
            case .password:
                return isSignUpMode
                    ? String.localized(.signingUp)
                    : String.localized(.loggingIn)
            }
        }
        
        switch loginMode {
        case .otp:
            return otpStep == .enterEmail
                ? String.localized(.sendVerificationCode)
                : String.localized(.verifyAndLogin)
        case .password:
            return isSignUpMode
                ? String.localized(.signUp)
                : String.localized(.signIn)
        }
    }
    
    /// 主按鈕是否可用
    private var primaryButtonEnabled: Bool {
        switch loginMode {
        case .otp:
            if otpStep == .enterEmail {
                return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } else {
                return !otpCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        case .password:
            return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !password.isEmpty
        }
    }
    
    // MARK: - 切換區域
    
    private var switchModeSection: some View {
        VStack(spacing: 16) {
            // 分隔線（金色點綴）
            HStack {
                Rectangle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(height: 0.5)
                
                Text(String.localized(.orContinueWith))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary.opacity(0.5))
                    .fixedSize()
                
                Rectangle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(height: 0.5)
            }
            
            // 切換按鈕
            HStack(spacing: 16) {
                // 切換 OTP / 密碼模式
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if loginMode == .otp {
                            loginMode = .password
                        } else {
                            loginMode = .otp
                            otpStep = .enterEmail
                        }
                    }
                }) {
                    Text(loginMode == .otp
                         ? String.localized(.loginWithPassword)
                         : String.localized(.loginWithOTP))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            // 註冊/登入切換（僅密碼模式）
            if loginMode == .password {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSignUpMode.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isSignUpMode
                             ? String.localized(.haveAccount)
                             : String.localized(.noAccount))
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                        
                        Text(isSignUpMode
                             ? String.localized(.signIn)
                             : String.localized(.signUp))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
        }
    }
    
    // MARK: - 隱私提示
    
    private var privacyHintSection: some View {
        Text(String.localized(.loginPrivacyHint))
            .font(.system(size: 11))
            .foregroundColor(Theme.textSecondary.opacity(0.4))
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
    
    // MARK: - 背景裝飾（金色抽象幾何色塊 + 光暈）
    
    private var backgroundDecoration: some View {
        ZStack {
            // 頂部金色光暈（柔和，非常輕）
            Circle()
                .fill(Theme.goldLight.opacity(0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -50, y: -200)
            
            // 底部暖金光暈
            Circle()
                .fill(Theme.goldLight.opacity(0.025))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(x: 80, y: 300)
            
            // 抽象金色幾何切片（右上角，10-15% 不透明度）
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.accent.opacity(0.06))
                .frame(width: 80, height: 120)
                .rotationEffect(.degrees(-25))
                .offset(x: 140, y: -320)
                .blur(radius: 2)
            
            // 左下角金箔片裝飾
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.goldDeep.opacity(0.05))
                .frame(width: 60, height: 90)
                .rotationEffect(.degrees(15))
                .offset(x: -150, y: 280)
                .blur(radius: 1)
        }
    }
    
    // MARK: - 驗證碼已發送 Toast
    
    private var codeSentToast: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.accent)
                
                Text(String.localized(.codeSentDesc, args: email))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.accent.opacity(0.3), lineWidth: 0.5)
                    )
            )
            .padding(.top, 60)
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - 註冊成功 Toast
    
    private var signUpSuccessToast: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.accent)
                
                Text(String.localized(.signUpSuccessDesc))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.accent.opacity(0.3), lineWidth: 0.5)
                    )
            )
            .padding(.top, 60)
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    /// 執行主操作
    private func performPrimaryAction() {
        Task { @MainActor in
            do {
                switch loginMode {
                case .otp:
                    if otpStep == .enterEmail {
                        // 發送 OTP
                        try await authManager.sendOTP(to: email)
                        withAnimation {
                            otpStep = .enterCode
                            showCodeSentToast = true
                        }
                        // 3 秒後隱藏 Toast
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showCodeSentToast = false
                            }
                        }
                    } else {
                        // 驗證 OTP
                        try await authManager.verifyOTP(email: email, otp: otpCode)
                    }
                    
                case .password:
                    if isSignUpMode {
                        // 註冊
                        try await authManager.signUp(email: email, password: password)
                        // 註冊成功但未自動登入 → 切到登入頁
                        if authManager.authState != .authenticated {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSignUpMode = false
                                showSignUpSuccessToast = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    showSignUpSuccessToast = false
                                }
                            }
                        }
                    } else {
                        // 登入
                        try await authManager.signIn(email: email, password: password)
                    }
                }
            } catch {
                let msg = error.localizedDescription
                // "User already registered" → 自動切到登入頁
                if msg.lowercased().contains("already registered") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSignUpMode = false
                        showSignUpSuccessToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showSignUpSuccessToast = false
                        }
                    }
                } else {
                    errorText = msg
                    showError = true
                }
            }
        }
    }
}

// MARK: - 自定義輸入框組件

/// 登入用文字輸入框
private struct LoginTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isEnabled: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .foregroundColor(Theme.textPrimary)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(!isEnabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isEnabled ? 0.05 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(isEnabled ? 0.1 : 0.05), lineWidth: 0.5)
        )
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

/// 登入用密碼輸入框
private struct LoginSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isSecured: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 24)
            
            if isSecured {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            Button(action: {
                isSecured.toggle()
            }) {
                Image(systemName: isSecured ? "eye.slash" : "eye")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    LoginView()
}
