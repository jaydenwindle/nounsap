//
//  docknounsApp.swift
//  docknouns
//
//  Created by Jayden Windle on 2022-07-18.
//

import SwiftUI
import WebKit

import web3swift
import BigInt

enum NounType {
    case nouns, lilnouns
}

class NounsViewModel: ObservableObject, Web3SocketDelegate {

    private var socketProvider: InfuraWebsocketProvider!
    
    // model
    @Published var nounType: NounType!
    @Published var nounsContractAddress: EthereumAddress!
    @Published var auctionHouseAddress: EthereumAddress!
    @Published var imageURI: URL!
    @Published var nounId: String!
    @Published var amount: String!
    @Published var endTime: Date!
    
    init() {
        setNounType(newNounType: NounType.lilnouns)
        
        socketProvider = InfuraWebsocketProvider("wss://eth-mainnet.g.alchemy.com/v2/UQ3BdPV4IAfBQ5VcNmYoHf1xBitfyerN", delegate: self)!
        socketProvider.connectSocket()
        try! (socketProvider).subscribeOnLogs(addresses: [auctionHouseAddress], topics: ["0x1159164c56f277e6fc99c11731bd380e0347deb969b75523398734c252706ea3", "0xc9f72b276a388619c6d185d146697036241880c36654b1a3ffdad07c24038d99"])
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWakeNote(note:)),
                                                                  name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onSleepNote(note:)),
                                                                  name: NSWorkspace.willSleepNotification, object: nil)
    }
    
    @MainActor func fetchCurrentAuction() async {
        let auctionHouseABIPath = Bundle.main.path(forResource: "auctionHouseABI", ofType: "json")
        guard let auctionHouseABI = try? String(contentsOfFile: auctionHouseABIPath!, encoding: String.Encoding.utf8) else { return }
        
        guard let rpcURL = URL(string: "https://eth-mainnet.g.alchemy.com/v2/UQ3BdPV4IAfBQ5VcNmYoHf1xBitfyerN") else { return }
        if let provider = Web3HttpProvider(rpcURL) {
            let web3 = web3(provider: provider)
            
            let auctionHouseContract = web3.contract(auctionHouseABI, at: auctionHouseAddress, abiVersion: 2)!

            let auctionTx = auctionHouseContract.read("auction", parameters: [] as [AnyObject])!

            let auctionResult = try! auctionTx.call()
            
            if let endTime = auctionResult["endTime"] {
                print(endTime)
                let timestamp = Web3.Utils.formatToPrecision(endTime as! BigUInt, numberDecimals: 0)!
                let date = Date(timeIntervalSince1970: Double(timestamp)!)

                self.endTime = date
            }
            
            let amount = auctionResult["amount"]!
            
            self.amount = "Ξ" + Web3.Utils.formatToEthereumUnits(amount as! BigUInt, toUnits: .eth, decimals: 2)!
            
            if let nounId = auctionResult["nounId"] {
                let nounIdString = Web3.Utils.formatToPrecision(nounId as! BigUInt, numberDecimals: 0)!
                if nounIdString != self.nounId {
                    await fetchNounImage(nounId: nounIdString)
                }
                self.nounId = nounIdString
            }
        } else {
            // retry
            print("failed to connect to rpc, retrying...")
            await fetchCurrentAuction()
        }
    }
    
    func fetchNounImage(nounId: String) async {
        let nounsABIPath = Bundle.main.path(forResource: "nounsABI", ofType: "json")
        let nounsABI = try! String(contentsOfFile: nounsABIPath!, encoding: String.Encoding.utf8)
        
        guard let rpcURL = URL(string: "https://eth-mainnet.g.alchemy.com/v2/UQ3BdPV4IAfBQ5VcNmYoHf1xBitfyerN") else { return }
        let web3 = web3(provider: Web3HttpProvider(rpcURL)!)

        let nounsContract = web3.contract(nounsABI, at: nounsContractAddress, abiVersion: 2)!
        
        let tx = nounsContract.read("dataURI", parameters: [nounId] as [AnyObject])!
        
        let result = try! tx.call()
        
        guard let data = try? Data(contentsOf: URL(string: result["0"] as! String)!) else {return}
        
        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        
        if let dictionary = json as? [String: Any] {
            if let image = dictionary["image"] as? String {
                DispatchQueue.main.async {
                    self.imageURI = URL(string: image)
                    NSApp.dockTile.display()
                }
            }
        }
    }
    
    func getFormattedTimeLeft() -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        let timeInterval = self.endTime.timeIntervalSince(Date())
        
        if timeInterval > 0 {
            return formatter.string(from: timeInterval)!
        }
        
        return "ended"
    }
    
    func setNounType(newNounType: NounType) {
        nounType = newNounType
        
        print(newNounType)
        
        if newNounType == NounType.nouns {
            auctionHouseAddress = EthereumAddress("0x830bd73e4184cef73443c15111a1df14e495c706")! // Nouns
            nounsContractAddress = EthereumAddress("0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03")! // Nouns
        }
        
        if newNounType == NounType.lilnouns {
            auctionHouseAddress = EthereumAddress("0x55e0f7a3bb39a28bd7bcc458e04b3cf00ad3219e")! // lil nouns
            nounsContractAddress = EthereumAddress("0x4b10701Bfd7BFEdc47d50562b76b436fbB5BdB3B")! // lil nouns
        }
        
        Task {
            await fetchCurrentAuction()
            socketProvider.disconnectSocket()
            socketProvider.connectSocket()
            try! (socketProvider).subscribeOnLogs(addresses: [auctionHouseAddress], topics: ["0x1159164c56f277e6fc99c11731bd380e0347deb969b75523398734c252706ea3", "0xc9f72b276a388619c6d185d146697036241880c36654b1a3ffdad07c24038d99"])
        }
    }
    
    func received(message: Any) {
        print(message)
        Task {
            await fetchCurrentAuction()
        }
    }
    
    func gotError(error: Error) {
        print(error)
    }
    
    func socketConnected(_ headers: [String : String]) {
        print("connected")
    }
    
    @objc func onWakeNote(note _: NSNotification) {
        socketProvider.connectSocket()
        try! (socketProvider).subscribeOnLogs(addresses: [auctionHouseAddress], topics: ["0x1159164c56f277e6fc99c11731bd380e0347deb969b75523398734c252706ea3", "0xc9f72b276a388619c6d185d146697036241880c36654b1a3ffdad07c24038d99"])
    }

    @objc func onSleepNote(note _: NSNotification) {
        socketProvider.disconnectSocket()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var nounsViewModel: NounsViewModel!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.orderOut(self)
        }
        
        nounsViewModel = NounsViewModel()
        
        Task {
            await nounsViewModel.fetchCurrentAuction()
            self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            
            if let statusButton = self.statusItem.button {
                DispatchQueue.main.async {
                    statusButton.title = String(format: "%@ %@: %@ | %@", self.nounsViewModel.nounType == NounType.nouns ? "Noun" : "lilnoun", self.nounsViewModel.nounId, self.nounsViewModel.amount, self.nounsViewModel.getFormattedTimeLeft())
                    statusButton.action = #selector(self.togglePopover)
                    statusButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
                }
            }

            let timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(refreshTitle), userInfo: nil, repeats: true)
            timer.fire()
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 300)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView(viewModel: nounsViewModel))
        
        let dockIconView = DockIconView(viewModel: nounsViewModel)
        NSApp.dockTile.contentView = NSHostingView(rootView: dockIconView)
        NSApp.dockTile.display()
    }
    
    @objc func togglePopover(sender: NSStatusItem) {
        
//        let event = NSApp.currentEvent!
        
        print(NSEvent.modifierFlags.contains(.option))
        
        if NSEvent.modifierFlags.contains(.option) {
            // toggle noun type
            if (nounsViewModel.nounType == NounType.nouns) {
                nounsViewModel.setNounType(newNounType: NounType.lilnouns)
            } else {
                nounsViewModel.setNounType(newNounType: NounType.nouns)
            }
            return
        }
        
        print("toggling popover")
        if let statusButton = self.statusItem.button {
            if popover.isShown {
                popover.performClose(self)
            } else {
                popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    @objc func refreshTitle() {
        if let statusButton = self.statusItem.button {
            statusButton.title = String(format: "%@ %@: %@ | %@", self.nounsViewModel.nounType == NounType.nouns ? "Noun" : "lilnoun", self.nounsViewModel.nounId, self.nounsViewModel.amount, self.nounsViewModel.getFormattedTimeLeft())
        }
    }
}

@main
struct docknounsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: NounsViewModel()).frame(width: 300, height: 300)
        }
    }
}
