//
//  UsageLimitView.swift
//  innerBloom
//
//  B-026: 用量已用完提示（S-006）
//  溫暖提示 + 引導升級 Premium
//

import SwiftUI

/// 用量限制類型
enum UsageLimitType {
    case interaction  // 陪伴互動次數用完
    case summary      // 每日總結次數用完
}

/// S-006：用量已用完提示 Sheet
struct UsageLimitView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var localization = LocalizationManager.shared
    
    let limitType: UsageLimitType
    var onUpgrade: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // 圖示
            Image(systemName: limitType == .interaction ? "bubble.left.and.bubble.right" : "doc.text")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.accent, Theme.accent.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 4)
            
            // 標題
            Text(String.localized(.usageLimitTitle))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            
            // 描述
            Text(limitType == .interaction
                 ? String.localized(.usageLimitInteractionDesc)
                 : String.localized(.usageLimitSummaryDesc))
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            // 升級按鈕
            Button(action: {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onUpgrade?()
                }
            }) {
                Text(String.localized(.upgradePremium))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            
            // 明天再說
            Button(action: {
                dismiss()
            }) {
                Text(String.localized(.usageLimitDismiss))
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.bottom, 32)
        }
        .background(Theme.background)
        .presentationDetents([.medium])
    }
}
