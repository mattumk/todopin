import SwiftUI

// MARK: - QuickDatePicker principal

struct QuickDatePicker: View {
    @Binding var date:    Date
    @Binding var hasDate: Bool

    @State private var dayOffset  = 0      // 0=aujourd'hui, 1=demain, 2=autre
    @State private var hour       = 9
    @State private var minute     = 0
    @State private var customDate = Date()
    @State private var showCal    = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            presetRow
            Divider().opacity(0.4)
            customRow
        }
        .onAppear { syncIn() }
    }

    // MARK: - Chips raccourcis

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if hasDate { clearChip }
                ForEach(presets(), id: \.0) { label, d in presetChip(label, d) }
            }
            .padding(.horizontal, 1).padding(.vertical, 2)
        }
    }

    private var clearChip: some View {
        Label("Effacer", systemImage: "xmark")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(Color.secondary.opacity(0.10)))
            .contentShape(Capsule())
            .onTapGesture { withAnimation { hasDate = false } }
    }

    private func presetChip(_ label: String, _ preset: Date) -> some View {
        let active = hasDate && abs(date.timeIntervalSince(preset)) < 90
        return Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(active ? .white : .primary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(active ? UmakeTheme.navy : Color.secondary.opacity(0.10)))
            .contentShape(Capsule())
            .onTapGesture { applyPreset(preset) }
    }

    // MARK: - Ligne date + heure

    private var customRow: some View {
        HStack(alignment: .center, spacing: 10) {
            // Sélecteur de jour
            HStack(spacing: 4) {
                dayPill("Auj.", 0)
                dayPill("Dem.", 1)
                calendarButton
            }
            Spacer()
            // Dials heure / minutes
            HStack(spacing: 2) {
                Dial(value: $hour,   maxVal: 23, step: 1,  onChange: commit)
                Text(":").font(.system(size: 16, weight: .light)).foregroundColor(.secondary).frame(width: 8)
                Dial(value: $minute, maxVal: 55, step: 5,  onChange: commit)
            }
            .opacity(hasDate ? 1 : 0.45)
            .onTapGesture {}   // absorbe les taps pour ne pas désactiver hasDate accidentellement
        }
    }

    private func dayPill(_ label: String, _ offset: Int) -> some View {
        let active = hasDate && dayOffset == offset
        return Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(active ? .white : .primary)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(active ? UmakeTheme.navy : Color.secondary.opacity(0.10)))
            .contentShape(Capsule())
            .onTapGesture { dayOffset = offset; hasDate = true; commit() }
    }

    private var calendarButton: some View {
        Image(systemName: dayOffset == 2 ? "calendar.circle.fill" : "calendar")
            .font(.system(size: 14))
            .foregroundColor(dayOffset == 2 ? .accentColor : .secondary)
            .frame(width: 26, height: 26)
            .contentShape(Circle())
            .onTapGesture { showCal = true }
            .popover(isPresented: $showCal) {
                calendarPopover
            }
    }

    private var calendarPopover: some View {
        DatePicker("", selection: $customDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(width: 280)
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .onChange(of: customDate) { _ in
                dayOffset = 2
                hasDate   = true
                showCal   = false
                commit()
            }
            .padding(8)
    }

    // MARK: - Logique

    private func applyPreset(_ d: Date) {
        let cal = Calendar.current
        hour   = cal.component(.hour,   from: d)
        minute = cal.component(.minute, from: d)
        if cal.isDateInToday(d)     { dayOffset = 0 }
        else if cal.isDateInTomorrow(d) { dayOffset = 1 }
        else { dayOffset = 2; customDate = d }
        hasDate = true
        commit()
    }

    private func commit() {
        let cal   = Calendar.current
        let base  = baseDate()
        var c     = cal.dateComponents([.year, .month, .day], from: base)
        c.hour    = hour
        c.minute  = minute
        c.second  = 0
        date      = cal.date(from: c) ?? base
        hasDate   = true
    }

    private func baseDate() -> Date {
        switch dayOffset {
        case 1:
            return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        case 2:
            return customDate
        default:
            return Date()
        }
    }

    /// Charge l'état interne depuis la binding `date` (appelé à l'apparition)
    private func syncIn() {
        guard hasDate else {
            // Pas de date → propose heure+1 arrondie comme défaut visuel
            let cal = Calendar.current
            hour    = min(23, cal.component(.hour, from: Date()) + 1)
            minute  = 0
            dayOffset = 0
            return
        }
        let cal = Calendar.current
        hour    = cal.component(.hour,   from: date)
        minute  = (cal.component(.minute, from: date) / 5) * 5
        if cal.isDateInToday(date)     { dayOffset = 0 }
        else if cal.isDateInTomorrow(date) { dayOffset = 1 }
        else { dayOffset = 2; customDate = date }
    }

    private func presets() -> [(String, Date)] {
        let now = Date(); let cal = Calendar.current
        var r: [(String, Date)] = []
        r.append(("Dans 1h",    roundQ(now.addingTimeInterval(3_600))))
        r.append(("Dans 3h",    roundQ(now.addingTimeInterval(10_800))))
        var ec = cal.dateComponents([.year,.month,.day], from: now)
        ec.hour = 20; ec.minute = 0
        if let ev = cal.date(from: ec), ev > now.addingTimeInterval(5_400) { r.append(("Ce soir", ev)) }
        if let tom = cal.date(byAdding: .day, value: 1, to: now) {
            var c = cal.dateComponents([.year,.month,.day], from: tom)
            c.hour = 9;  c.minute = 0; if let d = cal.date(from: c) { r.append(("Demain 9h", d)) }
            c.hour = 20; c.minute = 0; if let d = cal.date(from: c) { r.append(("Demain soir", d)) }
        }
        return r
    }

    private func roundQ(_ d: Date) -> Date {
        let cal = Calendar.current
        var c = cal.dateComponents([.year,.month,.day,.hour,.minute], from: d)
        let m = c.minute ?? 0; let r = ((m / 15) + 1) * 15
        if r >= 60 { c.hour = (c.hour ?? 0) + 1; c.minute = 0 } else { c.minute = r }
        return cal.date(from: c) ?? d
    }
}

// MARK: - Dial (heure ou minutes)

struct Dial: View {
    @Binding var value: Int
    let maxVal:  Int
    let step:    Int
    let onChange: () -> Void

    @State private var dragAccum: CGFloat = 0

    var body: some View {
        VStack(spacing: 2) {
            arrow(up: true)
            numberBox
            arrow(up: false)
        }
    }

    private func arrow(up: Bool) -> some View {
        Image(systemName: up ? "chevron.up" : "chevron.down")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(width: 40, height: 15)
            .contentShape(Rectangle())
            .onTapGesture { up ? inc() : dec(); onChange() }
    }

    private var numberBox: some View {
        Text(String(format: "%02d", value))
            .font(.system(size: 20, weight: .semibold, design: .monospaced))
            .frame(width: 40, height: 34)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.09)))
            .contentShape(Rectangle())
            // Glisser verticalement pour changer la valeur — fluide, aucun clic
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { v in
                        let delta = -v.translation.height   // glisser vers le haut = +
                        let pxPerStep: CGFloat = 16
                        while delta > dragAccum + pxPerStep { dragAccum += pxPerStep; inc(); onChange() }
                        while delta < dragAccum - pxPerStep { dragAccum -= pxPerStep; dec(); onChange() }
                    }
                    .onEnded { _ in dragAccum = 0 }
            )
    }

    private func inc() { value = (value + step > maxVal) ? 0     : value + step }
    private func dec() { value = (value - step < 0)      ? maxVal : value - step }
}
