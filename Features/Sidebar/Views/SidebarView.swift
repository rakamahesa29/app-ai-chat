import SwiftUI

struct SidebarView: View {
    @Binding var rooms: [ChatRoom]
    @Binding var selectedRoomID: String?
    var onNewChat: () -> Void
    var onDeleteRoom: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: HermesSpacing.md) {
                Text("CONVERSATIONS").font(.hermes.badge).foregroundColor(.hermes.muted).kerning(0.5)
                Button(action: onNewChat) {
                    HStack(spacing: HermesSpacing.sm) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                        Text("New Chat").font(.hermes.bodyMedium)
                    }.frame(maxWidth: .infinity).padding(.vertical, HermesSpacing.sm + 2)
                    .foregroundColor(.hermes.muted)
                    .overlay(RoundedRectangle(cornerRadius: HermesRadius.sm).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundColor(.hermes.border))
                }.buttonStyle(PlainButtonStyle())
            }.padding(HermesSpacing.lg)
            
            Divider().foregroundColor(.hermes.border)
            
            // Room List
            ScrollView {
                VStack(spacing: 1) {
                    if rooms.isEmpty {
                        VStack(spacing: HermesSpacing.md) {
                            Image(systemName: "message.square.dashed").font(.system(size: 28, weight: .light)).foregroundColor(.hermes.border)
                            Text("No conversations yet").font(.hermes.caption).foregroundColor(.hermes.muted)
                        }.padding(.vertical, HermesSpacing.xxxl)
                    } else {
                        ForEach(rooms) { room in roomItem(room) }
                    }
                }.padding(.horizontal, HermesSpacing.md).padding(.vertical, HermesSpacing.sm)
            }
            
            Spacer()
            
            // Footer
            Divider().foregroundColor(.hermes.border)
            HStack(spacing: HermesSpacing.md) {
                Image(systemName: "database").font(.system(size: 14))
                Text("Knowledge Base").font(.hermes.bodyMedium)
                Spacer()
            }
            .padding(HermesSpacing.lg).foregroundColor(.hermes.muted)
        }
        .background(Color.hermes.surface).frame(width: 260)
    }
    
    private func roomItem(_ room: ChatRoom) -> some View {
        let isSelected = selectedRoomID == room.id
        
        return HStack(spacing: 0) {
            if isSelected { Rectangle().fill(Color.hermes.accent).frame(width: 2).cornerRadius(1) }
            Button(action: { selectedRoomID = room.id }) {
                HStack(spacing: HermesSpacing.md) {
                    Image(systemName: "message.circle").font(.system(size: 13)).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(room.title).font(.hermes.bodyMedium).lineLimit(1).foregroundColor(isSelected ? .hermes.accent : .hermes.text)
                        Text(room.category).font(.hermes.badge).foregroundColor(isSelected ? .hermes.accent.opacity(0.7) : .hermes.muted)
                    }
                    Spacer()
                }
                .padding(.leading, isSelected ? HermesSpacing.md : HermesSpacing.md + 2)
                .padding(.trailing, 0)
                .padding(.vertical, HermesSpacing.sm + 2)
                .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())
            .contextMenu {
                Button(role: .destructive, action: {
                    withAnimation { onDeleteRoom?(room.id) }
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            // Visible delete button
            Button(action: {
                withAnimation { onDeleteRoom?(room.id) }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.hermes.muted.opacity(0.6))
                    .padding(.trailing, HermesSpacing.sm + 2)
                    .padding(.vertical, HermesSpacing.sm + 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(isSelected ? 0.6 : 0.3)
        }
        .background(isSelected ? Color.hermes.accent.opacity(0.08) : .clear)
        .cornerRadius(HermesRadius.sm)
    }
}

#Preview {
    SidebarView(rooms: .constant(ChatRoom.samples), selectedRoomID: .constant("room_1"), onNewChat: {})
}
