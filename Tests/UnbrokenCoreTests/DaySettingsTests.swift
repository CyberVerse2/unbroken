import Foundation
import Testing
@testable import UnbrokenCore

/// Shared helpers for building deterministic, timezone-pinned dates.
enum TestClock {
    static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0,
        calendar: Calendar
    ) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        return calendar.date(from: comps)!
    }
}

@Suite("DaySettings logical day boundaries")
struct DaySettingsTests {
    let cal = TestClock.utcCalendar()

    @Test("01:30 belongs to the previous logical day with dayEndHour 3")
    func earlyMorningIsPreviousDay() {
        let settings = DaySettings(dayEndHour: 3)
        let moment = TestClock.date(2026, 7, 2, 1, 30, calendar: cal)
        let expected = TestClock.date(2026, 7, 1, calendar: cal)
        #expect(settings.logicalDay(containing: moment, calendar: cal) == expected)
    }

    @Test("04:00 belongs to the same logical day with dayEndHour 3")
    func afterBoundaryIsSameDay() {
        let settings = DaySettings(dayEndHour: 3)
        let moment = TestClock.date(2026, 7, 2, 4, 0, calendar: cal)
        let expected = TestClock.date(2026, 7, 2, calendar: cal)
        #expect(settings.logicalDay(containing: moment, calendar: cal) == expected)
    }

    @Test("Exactly the boundary hour (03:00) starts the new logical day")
    func boundaryHourIsNewDay() {
        let settings = DaySettings(dayEndHour: 3)
        let moment = TestClock.date(2026, 7, 2, 3, 0, calendar: cal)
        let expected = TestClock.date(2026, 7, 2, calendar: cal)
        #expect(settings.logicalDay(containing: moment, calendar: cal) == expected)
    }

    @Test("One second before the boundary is still the previous day")
    func justBeforeBoundary() {
        let settings = DaySettings(dayEndHour: 3)
        let moment = TestClock.date(2026, 7, 2, 2, 59, 59, calendar: cal)
        let expected = TestClock.date(2026, 7, 1, calendar: cal)
        #expect(settings.logicalDay(containing: moment, calendar: cal) == expected)
    }

    @Test("dayEndHour 0 makes logical day equal calendar day")
    func midnightBoundary() {
        let settings = DaySettings(dayEndHour: 0)
        let earlyMorning = TestClock.date(2026, 7, 2, 1, 30, calendar: cal)
        #expect(settings.logicalDay(containing: earlyMorning, calendar: cal)
                == TestClock.date(2026, 7, 2, calendar: cal))

        let exactMidnight = TestClock.date(2026, 7, 2, 0, 0, calendar: cal)
        #expect(settings.logicalDay(containing: exactMidnight, calendar: cal)
                == TestClock.date(2026, 7, 2, calendar: cal))

        let lateNight = TestClock.date(2026, 7, 2, 23, 59, calendar: cal)
        #expect(settings.logicalDay(containing: lateNight, calendar: cal)
                == TestClock.date(2026, 7, 2, calendar: cal))
    }

    @Test("end(ofLogicalDay:) is the boundary hour of the next calendar day")
    func endOfLogicalDay() {
        let settings = DaySettings(dayEndHour: 3)
        let day = TestClock.date(2026, 7, 1, calendar: cal)
        let expectedEnd = TestClock.date(2026, 7, 2, 3, 0, calendar: cal)
        #expect(settings.end(ofLogicalDay: day, calendar: cal) == expectedEnd)
    }

    @Test("end(ofLogicalDay:) with dayEndHour 0 is next midnight")
    func endOfLogicalDayMidnight() {
        let settings = DaySettings(dayEndHour: 0)
        let day = TestClock.date(2026, 7, 1, calendar: cal)
        let expectedEnd = TestClock.date(2026, 7, 2, 0, 0, calendar: cal)
        #expect(settings.end(ofLogicalDay: day, calendar: cal) == expectedEnd)
    }

    @Test("logicalDay and end are consistent: the end moment belongs to the next day")
    func boundaryConsistency() {
        let settings = DaySettings(dayEndHour: 3)
        let day = TestClock.date(2026, 7, 1, calendar: cal)
        let end = settings.end(ofLogicalDay: day, calendar: cal)
        // The end is exclusive: that instant is the start of the next logical day.
        #expect(settings.logicalDay(containing: end, calendar: cal)
                == TestClock.date(2026, 7, 2, calendar: cal))
        // One second earlier still belongs to `day`.
        let justInside = end.addingTimeInterval(-1)
        #expect(settings.logicalDay(containing: justInside, calendar: cal) == day)
    }

    @Test("Logical day math survives a US spring-forward DST transition")
    func dstSpringForward() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let settings = DaySettings(dayEndHour: 3)
        // 2026-03-08: clocks spring forward 02:00 -> 03:00 in New York.
        let afterTransition = TestClock.date(2026, 3, 8, 4, 0, calendar: calendar)
        #expect(settings.logicalDay(containing: afterTransition, calendar: calendar)
                == TestClock.date(2026, 3, 8, calendar: calendar))
        // 01:30 that morning still counts for the prior logical day.
        let beforeTransition = TestClock.date(2026, 3, 8, 1, 30, calendar: calendar)
        #expect(settings.logicalDay(containing: beforeTransition, calendar: calendar)
                == TestClock.date(2026, 3, 7, calendar: calendar))
    }
}
