import Foundation
import HirebarCore

public final class Scheduler {
    public static let shared = Scheduler()
    static let followUpHours = [10, 16]
    static let followUpWindowHours = 3
    static let socialHours = 8...20
    static let prospectingHours = 7..<19
    static let linkedInHours = 9..<21
    static let reportHour = 18
    static let sunday = 1, monday = 2, tuesday = 3, friday = 6

    public var onChange: (() -> Void)?
    private var timer: Timer?
    private let defaults = UserDefaults.standard

    public func start() {
        timer?.invalidate()
        let clock = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.tick() }
        clock.tolerance = 10
        RunLoop.main.add(clock, forMode: .common)
        timer = clock
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in self?.tick() }
    }

    private func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func once(_ key: String, _ action: () -> Void) {
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        action()
    }

    private func tick() {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        let config = Config.load()
        let today = dayKey(now)

        if config.freelanceOn {
            for slot in Self.followUpHours where hour >= slot && hour < slot + Self.followUpWindowHours {
                once("sched.seguimiento.\(today).\(slot)") {
                    Log.write("Programador: seguimientos de las \(slot) h")
                    Controller.shared.runScheduled(.followUp)
                }
            }
        }
        if Self.socialHours.contains(hour) && hour % 2 == 0 && config.jobsOn {
            once("sched.redes.\(today).\(hour)") {
                Log.write("Programador: búsqueda en redes de las \(hour) h")
                Controller.shared.runScheduled(.social)
            }
        }
        if (Self.monday...Self.friday).contains(weekday) && Self.prospectingHours.contains(hour) {
            once("sched.prospeccion.\(today)") {
                Log.write("Programador: prospección del día")
                Controller.shared.runScheduled(.prospecting)
            }
        }
        if weekday == Self.tuesday && Self.linkedInHours.contains(hour) {
            let week = Metrics.weekKey(now)
            once("sched.linkedin.\(week)") {
                Log.write("Programador: borrador de LinkedIn \(week)")
                Controller.shared.runScheduled(.linkedInDraft)
            }
        }
        let lastSunday = weekday == Self.monday ? now.addingTimeInterval(-86400) : now
        let closingWeek = Metrics.weekKey(lastSunday)
        if (weekday == Self.sunday && hour >= Self.reportHour) || weekday == Self.monday {
            once("sched.informe.\(closingWeek)") {
                Log.write("Programador: informe semanal \(closingWeek)")
                Controller.shared.runScheduled(.weeklyReport)
            }
        }
        if ((weekday == Self.sunday && hour >= Self.reportHour + 1) || weekday == Self.monday) && Controller.shared.isIdle {
            once("sched.limpieza.\(closingWeek)") { Housekeeping.run() }
        }
        onChange?()
    }

    public var nextFollowUp: Date? {
        Self.followUpHours.compactMap {
            Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: $0, minute: 0), matchingPolicy: .nextTime)
        }.min()
    }

    public var nextReport: Date? {
        Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: Self.reportHour, minute: 0, weekday: Self.sunday),
                                  matchingPolicy: .nextTime)
    }
}
