import Foundation

/// Reminders set in the chat. They run on wall-clock time, so a reminder that comes due while
/// the Mac sleeps fires as soon as it wakes up instead of being pushed back by the nap.
/// They only live as long as the app does.
@MainActor
final class ReminderScheduler {
    var onDue: ((String) -> Void)?
    private var pending: [UUID: DispatchWorkItem] = [:]

    var count: Int { pending.count }

    func schedule(after seconds: TimeInterval, message: String) {
        let id = UUID()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.pending.removeValue(forKey: id) != nil else { return }
                self.onDue?(message)
            }
        }
        pending[id] = item
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + seconds, execute: item)
    }

    func cancelAll() {
        pending.values.forEach { $0.cancel() }
        pending.removeAll()
    }
}
