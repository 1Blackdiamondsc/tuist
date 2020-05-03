import Foundation
import TSCBasic
import TuistCore
import TuistSupport

public protocol SigningInteracting {
    func install(graph: Graph) throws
}

public final class SigningInteractor: SigningInteracting {
    private let signingFilesLocator: SigningFilesLocating
    private let rootDirectoryLocator: RootDirectoryLocating
    private let signingMatcher: SigningMatching
    private let signingInstaller: SigningInstalling
    private let signingLinter: SigningLinting
    private let securityController: SecurityControlling
    private let signingCipher: SigningCiphering
    
    public convenience init() {
        self.init(signingFilesLocator: SigningFilesLocator(),
                  rootDirectoryLocator: RootDirectoryLocator(),
                  signingMatcher: SigningMatcher(),
                  signingInstaller: SigningInstaller(),
                  signingLinter: SigningLinter(),
                  securityController: SecurityController(),
                  signingCipher: SigningCipher())
    }
    
    init(signingFilesLocator: SigningFilesLocating,
         rootDirectoryLocator: RootDirectoryLocating,
         signingMatcher: SigningMatching,
         signingInstaller: SigningInstalling,
         signingLinter: SigningLinting,
         securityController: SecurityControlling,
         signingCipher: SigningCiphering) {
        self.signingFilesLocator = signingFilesLocator
        self.rootDirectoryLocator = rootDirectoryLocator
        self.signingMatcher = signingMatcher
        self.signingInstaller = signingInstaller
        self.signingLinter = signingLinter
        self.securityController = securityController
        self.signingCipher = signingCipher
    }
    
    public func install(graph: Graph) throws {
        let entryPath = graph.entryPath
        guard
            let signingDirectory = try signingFilesLocator.locateSigningDirectory(from: entryPath),
            let derivedDirectory = rootDirectoryLocator.locate(from: entryPath)?.appending(component: Constants.derivedFolderName)
        else { return }
        
        let keychainPath = derivedDirectory.appending(component: Constants.signingKeychain)
                
        let masterKey = try signingCipher.readMasterKey(at: signingDirectory)
        try FileHandler.shared.createFolder(derivedDirectory)
        try securityController.createKeychain(at: keychainPath, password: masterKey)
        try securityController.unlockKeychain(at: keychainPath, password: masterKey)
        defer { try? securityController.lockKeychain(at: keychainPath, password: masterKey) }
        
        try signingCipher.decryptSigning(at: entryPath, keepFiles: true)
        defer { try? signingCipher.encryptSigning(at: entryPath, keepFiles: false) }
        
        let (certificates, provisioningProfiles) = try signingMatcher.match(graph: graph)
        
        try graph.projects.forEach { project in
            try project.targets.forEach {
                try install(target: $0,
                            project: project,
                            keychainPath: keychainPath,
                            certificates: certificates,
                            provisioningProfiles: provisioningProfiles)
            }
        }
    }
    
    private func install(target: Target,
                         project: Project,
                         keychainPath: AbsolutePath,
                         certificates: [String: Certificate],
                         provisioningProfiles: [String: [String: ProvisioningProfile]]) throws {
        let targetConfigurations = target.settings?.configurations ?? [:]
        let signingPairs = Set(targetConfigurations
            .merging(project.settings.configurations,
                     uniquingKeysWith: { config, _ in config })
            .keys)
            .compactMap { configuration -> (certificate: Certificate, provisioningProfile: ProvisioningProfile)? in
                guard
                    let provisioningProfile = provisioningProfiles[target.name]?[configuration.name],
                    let certificate = certificates[configuration.name.lowercased()]
                    else {
                        return nil
                }
                return (certificate: certificate, provisioningProfile: provisioningProfile)
        }
        
        try signingPairs.map(\.certificate).forEach {
            try signingInstaller.installCertificate($0, keychainPath: keychainPath)
        }
        try signingPairs.map(\.provisioningProfile).forEach(signingInstaller.installProvisioningProfile)
        
        try signingPairs.flatMap(signingLinter.lint).printAndThrowIfNeeded()
    }
}