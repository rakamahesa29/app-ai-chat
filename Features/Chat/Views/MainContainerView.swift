import SwiftUI

struct MainContainerView: View {
    @State private var isSidebarOpen = false
    @State private var rooms: [ChatRoom] = []
    @State private var selectedRoomID: String? = nil
    @State private var showCreateRoom = false
    @State private var isLoadingRooms = false
    
    var body: some View {
        GeometryReader { geo in
            let isMobile = geo.size.width < 700
            
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    if !isMobile {
                        SidebarView(
                            rooms: $rooms,
                            selectedRoomID: $selectedRoomID,
                            onNewChat: { showCreateRoom = true },
                            onDeleteRoom: { roomId in
                                rooms.removeAll { $0.id == roomId }
                                selectedRoomID = rooms.first?.id
                                Task { await deleteRoomAPI(roomId) }
                            }
                        )
                        Divider().foregroundColor(.hermes.border)
                    }
                    
                    Group {
                        if showCreateRoom {
                            ChatCreateView(
                                onDismiss: { showCreateRoom = false },
                                onCreateRoom: { newRoom in
                                    rooms.insert(newRoom, at: 0)
                                    selectedRoomID = newRoom.id
                                    showCreateRoom = false
                                    Task { await createRoomAPI(newRoom) }
                                }
                            )
                        } else if let roomID = selectedRoomID,
                                  let room = rooms.first(where: { $0.id == roomID }) {
                            ChatRoomView(
                                room: room,
                                isMobile: isMobile,
                                isSidebarOpen: $isSidebarOpen,
                                onDeleteRoom: {
                                    rooms.removeAll { $0.id == roomID }
                                    selectedRoomID = rooms.first?.id
                                    Task { await deleteRoomAPI(roomID) }
                                }
                            )
                            .id(room.id)  // Force re-creation on room switch
                        } else {
                            emptyState
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Mobile Overlay
                if isMobile && isSidebarOpen {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) { isSidebarOpen = false }
                        }
                        .zIndex(1)
                    
                    SidebarView(
                        rooms: $rooms,
                        selectedRoomID: Binding(
                            get: { selectedRoomID },
                            set: { newValue in
                                selectedRoomID = newValue
                                withAnimation(.easeInOut(duration: 0.25)) { isSidebarOpen = false }
                            }
                        ),
                        onNewChat: {
                            showCreateRoom = true
                            withAnimation(.easeInOut(duration: 0.25)) { isSidebarOpen = false }
                        },
                        onDeleteRoom: { roomId in
                            rooms.removeAll { $0.id == roomId }
                            selectedRoomID = rooms.first?.id
                            Task { await deleteRoomAPI(roomId) }
                        }
                    )
                    .transition(.move(edge: .leading))
                    .zIndex(2)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isSidebarOpen)
        }
        .task { await fetchRooms() }
    }
    
    private var emptyState: some View {
        HermesEmptyState(
            icon: "message.badge",
            title: "No conversation selected",
            message: "Select a conversation or start a new one",
            actionLabel: "New Conversation",
            action: { showCreateRoom = true }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hermes.bg)
    }
    
    // MARK: - API
    
    private func fetchRooms() async {
        isLoadingRooms = true
        do {
            let apiRooms = try await APIClient.shared.fetchRooms()
            rooms = apiRooms.map { $0.toChatRoom() }
            if selectedRoomID == nil { selectedRoomID = rooms.first?.id }
        } catch {
            print("Failed to fetch rooms: \(error)")
        }
        isLoadingRooms = false
    }
    
    private func createRoomAPI(_ room: ChatRoom) async {
        do {
            let response = try await APIClient.shared.createRoom(
                title: room.title, category: room.category, persona: room.persona, model: room.model
            )
            // Update local room with server ID
            if let idx = rooms.firstIndex(where: { $0.id == room.id }) {
                rooms[idx].id = String(response.id)
                if selectedRoomID == room.id { selectedRoomID = String(response.id) }
            }
        } catch {
            print("Failed to create room: \(error)")
        }
    }
    
    private func deleteRoomAPI(_ id: String) async {
        do {
            try await APIClient.shared.deleteRoom(id: id)
        } catch {
            print("Failed to delete room: \(error)")
        }
    }
}

#Preview {
    MainContainerView()
        .environmentObject(AppState())
}
