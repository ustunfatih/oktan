import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    
    // MARK: - Connection
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        print("CarPlay Connected")
        
        // Simple Dashboard Interface
        // Since we are primarily using this for Disconnect detection, the UI can be minimal.
        var items: [CPListItem] = []
        
        let headerItem = CPListItem(text: "Oktan Fuel Tracker", detailText: "Drive Safe!")
        headerItem.setImage(UIImage(systemName: "fuelpump.fill"))
        items.append(headerItem)
        
        // We could display stats here if we fetch them
        
        let section = CPListSection(items: items)
        let listTemplate = CPListTemplate(title: "Oktan", sections: [section])
        
        interfaceController.setRootTemplate(listTemplate, animated: true, completion: nil)
    }
    
    // MARK: - Disconnection (Smart Refuel Trigger)
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        print("CarPlay Disconnected - Triggering Smart Refuel Check")
        
        // Trigger the Location Manager to check if we are at a gas station
        // This works because the app is briefly awakened/active during the transition.
        LocationManager.shared.checkForGasStation()
    }
}
