//
//  ContentView.swift
//  docknouns
//
//  Created by Jayden Windle on 2022-07-18.
//

import SwiftUI
import WebKit
import SVGView


struct ContentView: View {
    @StateObject private var viewModel: NounsViewModel
    
    init(viewModel: NounsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack{
            if viewModel.imageURI != nil {
                SVGView(contentsOf: viewModel.imageURI!)
                    .onAppear(perform: {
                        NSApp.dockTile.display()
                    })
            } else {
                Image("nounsLoadingSkull").resizable().background(Color("nounsBackgroundColor"))
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: NounsViewModel())
    }
}
