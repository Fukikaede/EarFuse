import Profiles
import SwiftUI

public struct ProfilePickerView: View {
    @Binding private var selectedProfile: AppProfileKind

    public init(selectedProfile: Binding<AppProfileKind>) {
        _selectedProfile = selectedProfile
    }

    public var body: some View {
        Picker("Mode", selection: $selectedProfile) {
            ForEach(AppProfileKind.allCases, id: \.self) { kind in
                Text(kind.displayName).tag(kind)
            }
        }
        .pickerStyle(.segmented)
    }
}
