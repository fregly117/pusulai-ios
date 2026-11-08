import SwiftUI

public struct SettingsView: View {
    @AppStorage("pusulai_sound_enabled") private var soundEnabled = true
    @AppStorage("pusulai_haptics_enabled") private var hapticsEnabled = true
    @AppStorage("pusulai_dark_mode") private var darkMode = true
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Bildirim ve Sesler")) {
                    Toggle(isOn: $soundEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.blue)
                            Text("Canlı Gol Sesleri")
                        }
                    }
                    .onChange(of: soundEnabled) { val in
                        SoundManager.shared.setMuted(!val)
                    }
                    
                    Toggle(isOn: $hapticsEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundColor(.purple)
                            Text("Taptic Engine Titreşimi")
                        }
                    }
                }
                
                Section(header: Text("Görünüm")) {
                    Toggle(isOn: $darkMode) {
                        HStack(spacing: 12) {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.indigo)
                            Text("SofaScore Koyu Mod (#0E0E11)")
                        }
                    }
                }
                
                Section(header: Text("Sunucu ve Model Durumu")) {
                    HStack {
                        Text("Yapay Zeka Motoru")
                        Spacer()
                        Text("Dixon-Coles Poisson v4.6")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("API Durumu")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Bağlı (Railway)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section(header: Text("Hakkında")) {
                    HStack {
                        Text("Uygulama")
                        Spacer()
                        Text("PusulAI Pro Native iOS")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Sürüm")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
