import Foundation
import HirebarCore

public enum AI {
    public static var settings: AIEngineSettings { Config.load().aiEngine }
    public static var name: String { settings.displayName }
    public static var capitalizedName: String { name.prefix(1).uppercased() + name.dropFirst() }
}
