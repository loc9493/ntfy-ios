import SwiftUI

enum ActiveAlert {
    case clear, unsubscribe, selected
}

struct NotificationListView: View {
    private let tag = "NotificationListView"
    
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var store: Store
    
    @ObservedObject var subscription: Subscription
    
    @State private var editMode = EditMode.inactive
    @State private var selection = Set<Notification>()
    
    @State private var showAlert = false
    @State private var activeAlert: ActiveAlert = .clear
    
    private var subscriptionManager: SubscriptionManager {
        return SubscriptionManager(store: store)
    }
    
    var body: some View {
        List(selection: $selection) {
            ForEach(subscription.notificationsSorted(), id: \.self) { notification in
                NotificationRowView(notification: notification)
            }
        }
        .listStyle(PlainListStyle())
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, self.$editMode)
        .navigationBarBackButtonHidden(self.editMode == .active)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(subscription.displayName()).font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if (self.editMode == .active) {
                    editButton
                } else {
                    Menu {
                        if subscription.notificationCount() > 0 {
                            editButton
                        }
                        Button("Send test notification") {
                            self.sendTestNotification()
                        }
                        if subscription.notificationCount() > 0 {
                            Button("Clear all notifications") {
                                self.showAlert = true
                                self.activeAlert = .clear
                            }
                        }
                        Button("Unsubscribe") {
                            self.showAlert = true
                            self.activeAlert = .unsubscribe
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                if (self.editMode == .active) {
                    Button(action: {
                        self.showAlert = true
                        self.activeAlert = .selected
                    }) {
                        Text("Delete")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .alert(isPresented: $showAlert) {
            switch activeAlert {
            case .clear:
                return Alert(
                    title: Text("Clear notifications"),
                    message: Text("Do you really want to delete all of the notifications in this topic?"),
                    primaryButton: .destructive(
                        Text("Permanently delete"),
                        action: deleteAll
                    ),
                    secondaryButton: .cancel())
            case .unsubscribe:
                return Alert(
                    title: Text("Unsubscribe"),
                    message: Text("Do you really want to unsubscribe from this topic and delete all of the notifications you received?"),
                    primaryButton: .destructive(
                        Text("Unsubscribe"),
                        action: unsubscribe
                    ),
                    secondaryButton: .cancel())
            case .selected:
                return Alert(
                    title: Text("Delete"),
                    message: Text("Do you really want to delete these selected notifications?"),
                    primaryButton: .destructive(
                        Text("Delete"),
                        action: deleteSelected
                    ),
                    secondaryButton: .cancel())
            }
        }
        .overlay(Group {
            if subscription.notificationCount() == 0 {
                VStack {
                    Text("You haven't received any notifications for this topic yet.")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.bottom)
                    Text("To send notifications to this topic, simply PUT or POST to the topic URL.\n\nExample:\n`$ curl -d \"hi\" ntfy.sh/\(subscription.topicName())`\n\nDetailed instructions are available on [ntfy.sh](https;//ntfy.sh) and [in the docs](https:ntfy.sh/docs).")
                        .foregroundColor(.gray)
                }
                .padding(40)
            }
        })
        .refreshable {
            subscriptionManager.poll(subscription)
        }
    }
    
    private var editButton: some View {
        if editMode == .inactive {
            return Button(action: {
                self.editMode = .active
                self.selection = Set<Notification>()
            }) {
                Text("Select messages")
            }
        } else {
            return Button(action: {
                self.editMode = .inactive
                self.selection = Set<Notification>()
            }) {
                Text("Done")
            }
        }
    }
    
    private func sendTestNotification() {
        let possibleTags: Array<String> = ["warning", "skull", "success", "triangular_flag_on_post", "de", "us", "dog", "cat", "rotating_light", "bike", "backup", "rsync", "this-s-a-tag", "ios"]
        let priority = Int.random(in: 1..<6)
        let tags = Array(possibleTags.shuffled().prefix(Int.random(in: 0..<4)))
        DispatchQueue.global(qos: .background).async {
            ApiService.shared.publish(
                subscription: subscription,
                message: "This is a test notification from the ntfy iOS app. It has a priority of \(priority). If you send another one, it may look different.",
                title: "Test: You can set a title if you like",
                priority: priority,
                tags: tags
            )
        }
    }
    
    private func unsubscribe() {
        DispatchQueue.global(qos: .background).async {
            subscriptionManager.unsubscribe(subscription)
        }
        presentationMode.wrappedValue.dismiss()
    }
    
    private func deleteAll() {
        DispatchQueue.global(qos: .background).async {
            store.delete(allNotificationsFor: subscription)
        }
    }
    
    private func deleteSelected() {
        DispatchQueue.global(qos: .background).async {
            store.delete(notifications: selection)
            selection = Set<Notification>()
        }
        editMode = .inactive
    }
}

struct NotificationRowView: View {
    @EnvironmentObject private var store: Store
    @ObservedObject var notification: Notification

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(notification.shortDateTime())
                .font(.subheadline)
                .foregroundColor(.gray)
            if let title = notification.title, title != "" {
                Text(title)
                    .font(.headline)
                    .bold()
            }
            Text(notification.message ?? "")
                .font(.body)
        }
        .padding(.all, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.delete(notification: notification)
            } label: {
                Label("Delete", systemImage: "trash.circle")
            }
        }
    }
}

struct NotificationListView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store.preview
        Group {
            let subscriptionWithNotifications = store.makeSubscription(store.context, "stats", Store.sampleData["stats"]!)
            let subscriptionWithoutNotifications = store.makeSubscription(store.context, "announcements", Store.sampleData["announcements"]!)
            NotificationListView(subscription: subscriptionWithNotifications)
                .environment(\.managedObjectContext, store.context)
                .environmentObject(store)
            NotificationListView(subscription: subscriptionWithoutNotifications)
                .environment(\.managedObjectContext, store.context)
                .environmentObject(store)
        }
    }
}
