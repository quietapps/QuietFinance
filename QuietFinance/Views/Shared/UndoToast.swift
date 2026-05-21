import SwiftUI
import SwiftData

struct UndoToast: View {
    @EnvironmentObject var stash: UndoStash
    @Environment(\.modelContext) private var context
    @Query private var people: [Person]
    @Query private var countries: [Country]
    @Query private var types: [AssetType]
    @Query private var accounts: [Account]
    @Query private var snapshots: [Snapshot]

    var body: some View {
        Group {
            if let err = stash.restoreError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.lLoss)
                    Text(err)
                        .font(Typo.sans(12, weight: .medium))
                        .foregroundStyle(Color.lInk)
                    Spacer(minLength: 8)
                    Button {
                        stash.clearRestoreError()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.lInk3)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.lLossSoft.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lLoss.opacity(0.4), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                .frame(maxWidth: 480)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let p = stash.pending {
                HStack(spacing: 14) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.lInk3)
                    Text(p.label)
                        .font(Typo.sans(12.5, weight: .medium))
                        .foregroundStyle(Color.lInk)
                    Spacer(minLength: 8)
                    countdown
                    Button {
                        stash.restore(
                            context: context,
                            people: people,
                            countries: countries,
                            types: types,
                            accounts: accounts,
                            snapshots: snapshots
                        )
                    } label: {
                        Text("Undo")
                            .font(Typo.sans(12, weight: .semibold))
                            .foregroundStyle(Color.lPanel)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.lInk)
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    Button {
                        stash.clear()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.lInk3)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.lPanel)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.lLine, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                .frame(maxWidth: 480)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: stash.pending == nil)
    }

    private var countdown: some View {
        ZStack {
            Circle()
                .stroke(Color.lLine, lineWidth: 1.5)
                .frame(width: 18, height: 18)
            Circle()
                .trim(from: 0, to: max(0, min(1, stash.remaining / 10)))
                .stroke(Color.lInk2, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 18, height: 18)
        }
    }
}

