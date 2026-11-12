import Foundation
import WidgetEngineXPC

func installWidgetEngineService() {
    let serviceName = WidgetEngineXPC.embeddedServiceName() ?? "com.kidzyaka.taugram.WidgetEngineService"
    WidgetEngineXPC.install(serviceName: serviceName)
}
