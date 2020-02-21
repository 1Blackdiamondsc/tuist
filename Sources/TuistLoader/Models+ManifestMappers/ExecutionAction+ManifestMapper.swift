import Basic
import Foundation
import ProjectDescription
import TuistCore

extension TuistCore.ExecutionAction {
    /// Maps a ProjectDescription.ExecutionAction instance into a TuistCore.ExecutionAction instance.
    /// - Parameters:
    ///   - manifest: Manifest representation of execution action model.
    ///   - generatorPaths: Generator paths.
    static func from(manifest: ProjectDescription.ExecutionAction, generatorPaths: GeneratorPaths) throws -> TuistCore.ExecutionAction {
        let targetReference: TuistCore.TargetReference? = try manifest.target.map {
            .init(projectPath: try generatorPaths.resolveSchemeActionProjectPath($0.projectPath),
                  name: $0.targetName)
        }
        return ExecutionAction(title: manifest.title, scriptText: manifest.scriptText, target: targetReference)
    }
}