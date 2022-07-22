//
//  DockIconView.swift
//  docknouns
//
//  Created by Jayden Windle on 2022-07-20.
//

import SwiftUI
import SVGView

struct DockIconView: View {
    @StateObject private var viewModel: NounsViewModel
    
    init(viewModel: NounsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    var body: some View {
        GeometryReader { parent in
            ZStack {
                ZStack{
                    if viewModel.imageURI != nil {
                        SVGView(contentsOf: viewModel.imageURI!)
                            .onAppear(perform: {
                                NSApp.dockTile.display()
                            })
                    } else {
                        SVGView(contentsOf: Bundle.main.url(forResource: "appicon", withExtension: "svg")!)
                    }
                }
                .cornerRadius(parent.size.height * 0.179)
                .shadow(radius: 3)
            }.padding(parent.size.height * 0.098)
        }
    }
}

struct DockIconView_Previews: PreviewProvider {
    static var previews: some View {
        DockIconView(viewModel: NounsViewModel())
    }
}
