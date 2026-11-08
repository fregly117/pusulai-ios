import WidgetKit
import SwiftUI
import ActivityKit
import UIKit

@main
struct PusulAIWidgets: WidgetBundle {
    var body: some Widget {
        MatchLiveActivity()
    }
}

private let brand = Color(red: 55 / 255, green: 77 / 255, blue: 245 / 255)   // #374DF5
private let liveRed = Color(red: 1, green: 0.25, blue: 0.27)
private let goldText = Color(red: 1, green: 0.78, blue: 0)

struct MatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivityAttributes.self) { context in
            LockScreenView(attrs: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.88))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            MatchLiveActivity.island(context)
        }
    }

    static func island(_ context: ActivityViewContext<MatchActivityAttributes>) -> DynamicIsland {
        let a = context.attributes
        let s = context.state
        return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TeamBadge(short: a.homeShort, name: a.home, logoURL: a.homeLogoURL, thumb: a.homeThumb, size: 38)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TeamBadge(short: a.awayShort, name: a.away, logoURL: a.awayLogoURL, thumb: a.awayThumb, size: 38)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        if s.recentGoal {
                            Text("⚽ GOL!")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(goldText)
                        }
                        ScoreText(state: s, size: 30)
                        StatusLabel(state: s)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if s.recentGoal {
                        Text("\(s.goalSide == "home" ? a.home : a.away) attı · \(s.minute)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(goldText)
                            .lineLimit(1)
                    } else {
                        Text(a.league)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                // SofaScore gibi: ev sahibi logosu + skoru
                HStack(spacing: 5) {
                    TeamLogo(short: a.homeShort, logoURL: a.homeLogoURL, thumb: a.homeThumb, size: 20)
                    if s.phase != "pre" {
                        Text("\(s.homeScore)")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                    }
                }
            } compactTrailing: {
                // deplasman skoru + logosu (başlamadıysa saat)
                HStack(spacing: 5) {
                    if s.recentGoal {
                        Text("GOL")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(goldText)
                    }
                    Text(s.phase == "pre" ? s.minute : "\(s.awayScore)")
                        .font(.system(size: s.phase == "pre" ? 12 : 15, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                    TeamLogo(short: a.awayShort, logoURL: a.awayLogoURL, thumb: a.awayThumb, size: 20)
                }
            } minimal: {
                TeamLogo(short: a.homeShort, logoURL: a.homeLogoURL, thumb: a.homeThumb, size: 20)
            }
            .keylineTint(brand)
    }
}

// MARK: - Kilit ekranı / bildirim merkezi görünümü

struct LockScreenView: View {
    let attrs: MatchActivityAttributes
    let state: MatchActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).fill(brand).frame(width: 14, height: 14)
                        .overlay(Text("P").font(.system(size: 10, weight: .black)).foregroundColor(.white))
                    if state.recentGoal {
                        Text("⚽ GOL! \(state.goalSide == "home" ? attrs.home : attrs.away)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(goldText)
                            .lineLimit(1)
                    } else {
                        Text(attrs.league.isEmpty ? "PusulAI" : attrs.league)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
                Spacer()
                StatusLabel(state: state)
            }
            HStack(alignment: .center, spacing: 8) {
                TeamBadge(short: attrs.homeShort, name: attrs.home, logoURL: attrs.homeLogoURL, thumb: attrs.homeThumb, size: 40)
                    .frame(maxWidth: .infinity)
                ScoreText(state: state, size: 34)
                    .frame(minWidth: 96)
                TeamBadge(short: attrs.awayShort, name: attrs.away, logoURL: attrs.awayLogoURL, thumb: attrs.awayThumb, size: 40)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .foregroundColor(.white)
    }
}

// MARK: - Parçalar

/// Takım logosu: ortak klasördeki logo → gömülü küçük logo → harf kısaltması
struct TeamLogo: View {
    let short: String
    let logoURL: String?
    let thumb: Data?
    let size: CGFloat

    var body: some View {
        if let file = LogoStore.fileURL(for: logoURL), let img = UIImage(contentsOfFile: file.path) {
            // Şeffaf orijinal logo (SofaScore gibi doğrudan)
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else if let thumb = thumb, let img = UIImage(data: thumb) {
            // Beyaz zeminli küçük logo
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(brand)
                .frame(width: size, height: size)
                .overlay(
                    Text(short)
                        .font(.system(size: size * 0.32, weight: .heavy))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                )
        }
    }
}

struct TeamBadge: View {
    let short: String
    let name: String
    let logoURL: String?
    let thumb: Data?
    let size: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            TeamLogo(short: short, logoURL: logoURL, thumb: thumb, size: size)
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

struct ScoreText: View {
    let state: MatchActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        if state.phase == "pre" {
            Text(state.minute)
                .font(.system(size: size * 0.8, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
        } else {
            Text("\(state.homeScore) - \(state.awayScore)")
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

struct StatusLabel: View {
    let state: MatchActivityAttributes.ContentState

    var body: some View {
        switch state.phase {
        case "live":
            HStack(spacing: 4) {
                Circle().fill(liveRed).frame(width: 6, height: 6)
                Text(state.minute).font(.system(size: 12, weight: .bold)).foregroundColor(liveRed)
            }
        case "ht":
            Text("Devre arası").font(.system(size: 12, weight: .bold)).foregroundColor(goldText)
        case "ended":
            Text("Maç sonu").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.7))
        default:
            Text("Başlamadı").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.7))
        }
    }
}
