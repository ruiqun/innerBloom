//
//  PremiumView.swift
//  innerBloom
//
//  B-023: 付費牆 UI（S-005）
//  顯示：權益、月/年方案、購買按鈕、Restore、條款/隱私
//

import SwiftUI
import StoreKit

struct PremiumView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Bindable private var iapManager = IAPManager.shared
    @Bindable private var localization = LocalizationManager.shared
    
    @State private var isPurchasing = false
    @State private var selectedProduct: Product?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRestoreSuccess = false
    @State private var isRetryingProducts = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // 標題
                        headerSection
                        
                        // Premium 權益
                        benefitsSection
                        
                        // 已訂閱：顯示狀態 + 管理訂閱；未訂閱：顯示方案與購買按鈕
                        if iapManager.premiumStatus.isPremium {
                            alreadySubscribedSection
                        } else if iapManager.isSyncing || isRetryingProducts {
                            syncingPlaceholder
                        } else if iapManager.products.isEmpty {
                            productsEmptySection
                        } else {
                            plansSection
                            if let product = selectedProduct ?? iapManager.products.first {
                                purchaseButton(product: product)
                            }
                        }
                        
                        // Restore
                        restoreButton
                        
                        // 條款/隱私
                        legalSection
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(String.localized(.premium))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String.localized(.close)) {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
            .alert(String.localized(.hint), isPresented: $showError) {
                Button(String.localized(.confirm)) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if showRestoreSuccess {
                    restoreSuccessToast
                }
            }
        }
        .preferredColorScheme(.dark)
        .id(localization.languageChangeId)
        .task {
            // 進入時重新載入產品（確保 StoreKit 有機會完成 Sign in 模擬）
            await iapManager.loadProducts()
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.accent)
            
            Text(String.localized(.premiumTitle))
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundColor(Theme.textPrimary)
            
            Text(String.localized(.premiumSubtitle))
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String.localized(.premiumBenefits))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            
            VStack(alignment: .leading, spacing: 12) {
                benefitRow(icon: "infinity", text: String.localized(.premiumBenefitUnlimitedChat))
                benefitRow(icon: "doc.text.fill", text: String.localized(.premiumBenefitUnlimitedSummary))
                benefitRow(icon: "bolt.fill", text: String.localized(.premiumBenefitPriority))
                benefitRow(icon: "person.2.fill", text: String.localized(.premiumBenefitRoles))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Theme.accent)
                .frame(width: 24, alignment: .center)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Theme.textPrimary)
            Spacer()
        }
    }
    
    /// 產品載入失敗時：提示 Sign in + 重試按鈕
    private var productsEmptySection: some View {
        VStack(spacing: 16) {
            Text(String.localized(.premiumProductsLoadHint))
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: { Task { await retryLoadProducts() } }) {
                Text(String.localized(.premiumRetryLoad))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.accent)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
    
    /// 已訂閱狀態：顯示「已是會員」+ 到期日 + 管理訂閱按鈕
    private var alreadySubscribedSection: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.accent)
                Text(String.localized(.premiumAlreadySubscribed))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.vertical, 8)
            
            if let expiresAt = iapManager.premiumStatus.expiresAt {
                HStack(spacing: 6) {
                    Text(String.localized(.premiumExpiresOn))
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                    Text(formatExpiryDate(expiresAt))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                }
            }
            
            Button {
                showManageSubscriptions()
            } label: {
                Text(String.localized(.manageSubscription))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.accent)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
    
    private var syncingPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
            Text(String.localized(.premiumSyncing))
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
    
    private var plansSection: some View {
        VStack(spacing: 12) {
            ForEach(iapManager.products, id: \.id) { product in
                let info = iapManager.productInfos.first { $0.productId == product.id }
                planRow(product: product, info: info)
            }
        }
    }
    
    private func planRow(product: Product, info: PremiumProductInfo?) -> some View {
        let isSelected = selectedProduct?.id == product.id || (selectedProduct == nil && product.id == iapManager.products.first?.id)
        let isYearly = product.id.contains("yearly")
        
        return Button {
            selectedProduct = product
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isYearly ? String.localized(.premiumYearly) : String.localized(.premiumMonthly))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    if let trial = info?.trialText {
                        Text(trial)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.accent)
                    }
                    if let monthly = info?.pricePerMonth, isYearly {
                        Text("(\(String.localized(.premiumPerMonth, args: monthly)))")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.accent)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.accent : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            if selectedProduct == nil { selectedProduct = iapManager.products.first }
        }
    }
    
    private func purchaseButton(product: Product) -> some View {
        Button {
            Task {
                await performPurchase(product)
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                } else {
                    Text(String.localized(.premiumSubscribe))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent)
            .cornerRadius(14)
        }
        .disabled(isPurchasing || iapManager.isSyncing)
    }
    
    private var restoreButton: some View {
        Button {
            Task {
                await performRestore()
            }
        } label: {
            Text(String.localized(.restorePurchases))
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
        }
        .disabled(iapManager.isSyncing)
    }
    
    private var legalSection: some View {
        VStack(spacing: 8) {
            Link(String.localized(.termsOfService), destination: URL(string: "https://innerbloom.app/terms")!)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
            Link(String.localized(.privacyPolicy), destination: URL(string: "https://innerbloom.app/privacy")!)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
            Text(String.localized(.subscriptionTerms))
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
    
    private var restoreSuccessToast: some View {
        VStack {
            Spacer()
            Text(String.localized(.restoreSuccess))
                .font(.system(size: 15))
                .foregroundColor(Theme.background)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.accent.opacity(0.9))
                .cornerRadius(10)
                .padding(.bottom, 100)
        }
    }
    
    // MARK: - Actions
    
    private func performPurchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let success = try await iapManager.purchase(product)
            if success {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func performRestore() async {
        do {
            try await iapManager.restorePurchases()
            if iapManager.premiumStatus.isPremium {
                showRestoreSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showRestoreSuccess = false
                    dismiss()
                }
            } else {
                // 無購買記錄：涵蓋「從未購買」與「已取消到期」兩種情況
                errorMessage = String.localized(.restoreNoPurchaseHint) + "\n\n" + String.localized(.restoreCanceledHint)
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func retryLoadProducts() async {
        isRetryingProducts = true
        defer { isRetryingProducts = false }
        await iapManager.loadProducts()
    }
    
    private func formatExpiryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = .current
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    /// 開啟系統訂閱管理頁面（可切換方案、取消等）
    private func showManageSubscriptions() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }
        Task {
            try? await AppStore.showManageSubscriptions(in: scene)
        }
    }
}

#Preview {
    PremiumView()
}
