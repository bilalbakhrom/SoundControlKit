//
//  Indicator.swift
//  SoundControlKitExample
//
//  Created by Bilal Bakhrom on 26/09/24.
//

import SwiftUI

struct Indicator: View {
    var body: some View {
        Rectangle()
            .frame(width: 60, height: 5)
            .cornerRadius(2.5)
            .foregroundColor(Color.white.opacity(0.2))
            .padding(.bottom, 20)
    }
}

