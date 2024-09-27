//
//  Indicator.swift
//  SoundControlKitExample
//
//  Created by Bilal Bakhrom on 26/09/24.
//

import SwiftUI

struct Indicator: View {
    var width: CGFloat = 60
    var height: CGFloat = 5
    var cornerRadius: CGFloat = 2.5
    var bottomPadding: CGFloat = 20
    var opacity: Double = 0.2

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .foregroundColor(colorScheme == .dark ? Color.white.opacity(opacity) : Color.black.opacity(opacity))
            .padding(.bottom, bottomPadding)
    }
}
