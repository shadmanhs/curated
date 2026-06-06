import SwiftUI
import AVFoundation

enum RevealPhase {
    case analyzing
    case synthesizing
    case reveal
}

struct VibeRevealView: View {
    @EnvironmentObject var vibeStore: VibeStore
    @Environment(\.dismiss) private var dismiss

    let vibeMarkdown: String

    @State private var phase: RevealPhase = .analyzing
    @State private var analysisProgress: Double = 0
    @State private var showParticles = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var orbRotation: Double = 0
    @State private var textOpacity: Double = 0
    @State private var revealScale: CGFloat = 0.8
    @State private var revealOpacity: Double = 0
    @State private var analysisLines: [String] = []
    @State private var currentLineIndex = 0

    private let synthesizer = AVSpeechSynthesizer()

    private let analysisMessages = [
        "Scanning your aesthetic...",
        "Decoding your color palette...",
        "Analyzing fashion choices...",
        "Mapping your taste patterns...",
        "Synthesizing your vibe..."
    ]

    var body: some View {
        ZStack {
            // Background gradient
            DesignSystem.Colors.cream
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Animated Orb
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(
                                DesignSystem.Colors.sunsetGradient,
                                lineWidth: 2
                            )
                            .frame(width: 120 + CGFloat(i) * 40, height: 120 + CGFloat(i) * 40)
                            .opacity(phase == .analyzing ? 0.3 - Double(i) * 0.1 : 0)
                            .scaleEffect(phase == .analyzing ? pulseScale : 1)
                    }

                    // Main orb
                    Circle()
                        .fill(
                            phase == .reveal
                                ? DesignSystem.Colors.sunsetGradient
                                : LinearGradient(
                                    colors: [DesignSystem.Colors.primary, DesignSystem.Colors.sunshine500],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: phase == .reveal ? "sparkles" : "eye.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        )
                        .rotationEffect(.degrees(orbRotation))
                        .scaleEffect(phase == .reveal ? revealScale : 1)
                        .shadow(
                            color: DesignSystem.Colors.primary.opacity(0.5),
                            radius: phase == .reveal ? 30 : 15,
                            x: 0,
                            y: 0
                        )

                    // Particle effects during analysis
                    if phase == .analyzing && showParticles {
                        ForEach(0..<6) { i in
                            AnalysisParticle(index: i)
                        }
                    }
                }
                .frame(height: 200)

                // Phase content
                VStack(spacing: DesignSystem.Spacing.lg) {
                    switch phase {
                    case .analyzing:
                        AnalyzingContent(
                            messages: analysisMessages,
                            currentIndex: currentLineIndex,
                            progress: analysisProgress
                        )

                    case .synthesizing:
                        SynthesizingContent()

                    case .reveal:
                        RevealContent(profile: vibeStore.profile)
                            .opacity(revealOpacity)
                            .scaleEffect(revealScale)
                    }
                }
                .frame(height: 180)

                Spacer()

                // Continue button (only on reveal)
                if phase == .reveal {
                    CuratedButton(title: "Continue to My Vibe", style: .primary) {
                        dismiss()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .onAppear {
            vibeStore.load(from: vibeMarkdown)
            startAnalysisAnimation()
        }
    }

    private func startAnalysisAnimation() {
        // Phase 1: Analyzing with rotating text
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }

        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            orbRotation = 360
        }

        showParticles = true

        // Cycle through analysis messages
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { timer in
            if phase != .analyzing {
                timer.invalidate()
                return
            }

            withAnimation {
                currentLineIndex = (currentLineIndex + 1) % analysisMessages.count
            }
        }

        // Progress to synthesis after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeInOut(duration: 0.5)) {
                phase = .synthesizing
                showParticles = false
            }

            // Progress to reveal after 1.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    phase = .reveal
                }

                // Dramatic reveal animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    revealScale = 1.0
                    revealOpacity = 1.0
                }

                // Speak the dramatic reveal
                speakVibeReveal()
            }
        }
    }

    private func speakVibeReveal() {
        guard let profile = vibeStore.profile else { return }

        let utteranceText = "I see you. You are... \(profile.oneLiner)"

        let utterance = AVSpeechUtterance(string: utteranceText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45  // Slow and dramatic
        utterance.pitchMultiplier = 0.95  // Slightly deeper
        utterance.volume = 1.0

        // Add dramatic pauses
        utterance.preUtteranceDelay = 0.3

        synthesizer.speak(utterance)
    }
}

// MARK: - Analysis Particle

struct AnalysisParticle: View {
    let index: Int
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .fill(DesignSystem.Colors.sunshine500)
            .frame(width: 6, height: 6)
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                let angle = Double(index) * (360.0 / 6.0) * .pi / 180
                let distance: CGFloat = 80

                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.2)
                ) {
                    offset = CGSize(
                        width: cos(angle) * distance,
                        height: sin(angle) * distance
                    )
                    opacity = 0.8
                }
            }
    }
}

// MARK: - Analyzing Content

struct AnalyzingContent: View {
    let messages: [String]
    let currentIndex: Int
    let progress: Double

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i <= currentIndex % 5 ? DesignSystem.Colors.primary : DesignSystem.Colors.muted)
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
            }

            // Current message
            Text(messages[currentIndex])
                .font(DesignSystem.Typography.bodyMd())
                .foregroundColor(DesignSystem.Colors.ink)
                .multilineTextAlignment(.center)
                .transition(.opacity)
                .id(currentIndex)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(DesignSystem.Colors.hairline)
                        .frame(height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    Rectangle()
                        .fill(DesignSystem.Colors.sunsetGradient)
                        .frame(width: geo.size.width * CGFloat(min(Double(currentIndex + 1) / 5.0, 1.0)), height: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Synthesizing Content

struct SynthesizingContent: View {
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Spinning synthesis indicator
            ZStack {
                ForEach(0..<3) { i in
                    ArcShape(startAngle: Double(i) * 120, endAngle: Double(i) * 120 + 60)
                        .stroke(
                            DesignSystem.Colors.sunsetGradient,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(rotation))
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }

            Text("Synthesizing your essence...")
                .font(DesignSystem.Typography.bodyMd())
                .foregroundColor(DesignSystem.Colors.ink)
        }
    }
}

// MARK: - Arc Shape

struct ArcShape: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle - 90),
            endAngle: .degrees(endAngle - 90),
            clockwise: false
        )
        return path
    }
}

// MARK: - Reveal Content

struct RevealContent: View {
    let profile: VibeProfile?

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("I see you.")
                .font(DesignSystem.Typography.heading2())
                .foregroundColor(DesignSystem.Colors.steel)

            Text("You are...")
                .font(DesignSystem.Typography.bodyMd())
                .foregroundColor(DesignSystem.Colors.stone)

            if let profile = profile {
                Text(profile.oneLiner)
                    .font(DesignSystem.Typography.heroDisplay())
                    .foregroundColor(DesignSystem.Colors.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleVibe = """
    ```yaml
    vibe_id: "sample_preview"
    version: 1
    generated_from: "instagram"
    updated: "2024-01-01"
    one_liner: "Minimalist curator with a warm, nostalgic soul"
    aesthetic:
      keywords: ["minimalist", "warm tones", "film photography"]
      color_palette: ["cream", "terracotta", "sage"]
      avoid: ["neon", "overly polished"]
    fashion:
      silhouette: "relaxed tailored"
      fits: ["oversized shirts", "tapered trousers"]
      loved_brands: ["COS", "A.P.C.", "Our Legacy"]
      avoided_brands: ["fast fashion"]
      materials: ["linen", "organic cotton", "wool"]
      footwear_bias: ["loafers", "clean sneakers"]
      accessories: "minimal jewelry and vintage watches"
    interests: ["film photography", "coffee culture", "slow living"]
    food:
      loves: ["natural wine", "sourdough", "seasonal vegetables"]
      avoids: ["processed food"]
      ordering_style: "share everything"
    travel:
      style: "immersive and slow"
      pace: "relaxed"
      lodging: "boutique guesthouses"
      loved_destinations: ["Copenhagen", "Tokyo", "Lisbon"]
      seeks: ["local experiences", "design stores"]
      avoids: ["tourist traps"]
    music: ["jazz", "indie folk", "ambient"]
    values: ["authenticity", "craftsmanship", "sustainability"]
    personality:
      tone: "warm but discerning"
      humor: "dry wit"
      decisiveness: "confident"
      social_energy: "selectively social"
    communication_prefs:
      assistant_voice: "thoughtful friend with impeccable taste"
      address_as: "you"
      avoid: ["hype", "aggressive sales"]
      brevity: "concise but warm"
    engagement_signals:
      most_liked_categories: ["interior design", "coffee"]
      most_saved: ["recipes", "travel guides"]
      follows_archetypes: ["creatives", "makers"]
      recurring_hashtags: ["#slowliving", "#filmphotography"]
      rarely_engages: ["celebrity gossip"]
    anti_vibe: ["loud branding", "trend chasing", "disposability"]
    confidence_by_domain:
      fashion: "high"
      food: "high"
      travel: "medium"
    ```
    """

    return VibeRevealView(vibeMarkdown: sampleVibe)
        .environmentObject(VibeStore())
}
