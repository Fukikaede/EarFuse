import Capture
import SwiftUI

public struct CaptureSourcePickerView: View {
    @Binding private var source: CaptureSource

    public init(source: Binding<CaptureSource>) {
        _source = source
    }

    public var body: some View {
        Picker("Capture", selection: $source) {
            ForEach(CaptureSource.allCases, id: \.self) { item in
                Text(item.displayName).tag(item)
            }
        }
        .pickerStyle(.menu)
    }
}
