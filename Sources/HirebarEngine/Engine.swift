import Foundation
import HirebarCore

public enum Engine {
    public static func start(resources: URL?) {
        Paths.ensure()
        Paths.installTemplates(from: resources)
        AgentStore.writeMissingDefaults()
        Migrations.run()
        Controller.shared.start()
        FreelanceRadar.shared.start()
        JobRadar.shared.start()
        Scheduler.shared.start()
        Log.write("Hirebar iniciado")
    }
}
