//
//  CompanionRoleSheet.swift
//  innerBloom
//
//  B-029: S-007 陪伴角色選擇（卡片清單 Bottom Sheet）
//  F-025: 阿暖、阿衡、阿樂、阿澄
//  非 Premium：灰階 + 鎖頭，點選 → S-005
//  Premium：可切換，立即生效
//

import SwiftUI

struct CompanionRoleSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settingsManager = SettingsManager.shared
    @Bindable private var iapManager = IAPManager.shared
    @Bindable private var localization = LocalizationManager.shared
    
    @State private var showPremium = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(AIToneStyle.allCases, id: \.self) { role in
                            CompanionRoleCard(
                                role: role,
                                isSelected: settingsManager.aiToneStyle == role,
                                isLocked: !iapManager.premiumStatus.isPremium
                            ) {
                                handleRoleTap(role)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(String.localized(.companionRole))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String.localized(.done)) {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
            .sheet(isPresented: $showPremium) {
                PremiumView()
            }
        }
        .preferredColorScheme(.dark)
        .id(localization.languageChangeId)
    }
    
    private func handleRoleTap(_ role: AIToneStyle) {
        if iapManager.premiumStatus.isPremium {
            settingsManager.setAIToneStyle(role)
            dismiss()
        } else {
            // F-025: 非 Premium 點選 → 直接導去 S-005
            showPremium = true
        }
    }
}

// MARK: - 角色卡片

struct CompanionRoleCard: View {
    let role: AIToneStyle
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 角色圖示（抽象符號風格 A）
                Image(systemName: role.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isLocked ? Theme.textSecondary.opacity(0.5) : Theme.accent)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(isLocked ? Color.white.opacity(0.05) : Color.white.opacity(0.08))
                    )
                
                // 文字區
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(role.roleName)｜\(role.roleTag)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isLocked ? Theme.textSecondary.opacity(0.7) : Theme.textPrimary)
                        
                        Spacer()
                        
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondary.opacity(0.6))
                        } else if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Theme.accent)
                        }
                    }
                    
                    Text(role.description)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary.opacity(isLocked ? 0.6 : 1))
                        .lineLimit(2)
                    
                    Text("\"\(role.exampleReply)\"")
                        .font(.system(size: 12))
                        .italic()
                        .foregroundColor(Theme.textSecondary.opacity(isLocked ? 0.5 : 0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isLocked ? Color.white.opacity(0.03) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected && !isLocked ? Theme.accent.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .opacity(isLocked ? 0.85 : 1)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CompanionRoleSheet()
}
