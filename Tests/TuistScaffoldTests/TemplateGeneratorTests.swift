import Basic
import Foundation
import TuistSupport
import XCTest

@testable import TuistCore
@testable import TuistCoreTesting
@testable import TuistScaffold
@testable import TuistSupportTesting

final class TemplateGeneratorTests: TuistTestCase {
    var subject: TemplateGenerator!

    override func setUp() {
        super.setUp()
        subject = TemplateGenerator()
    }

    override func tearDown() {
        super.tearDown()
        subject = nil
    }

    func test_directories_are_generated() throws {
        // Given
        let directories = [RelativePath("a"), RelativePath("a/b"), RelativePath("c")]
        let destinationPath = try temporaryPath()
        let expectedDirectories = directories.map(destinationPath.appending)
        let files = directories.map {
            Template.File.test(path: RelativePath($0.pathString + "/file.swift"))
        }

        let template = Template.test(files: files)

        // When
        try subject.generate(template: template,
                             to: destinationPath,
                             attributes: [:])

        // Then
        XCTAssertTrue(expectedDirectories.allSatisfy(FileHandler.shared.exists))
    }

    func test_directories_with_attributes() throws {
        // Given
        let directories = [RelativePath("{{ name }}"), RelativePath("{{ aName }}"), RelativePath("{{ name }}/{{ bName }}")]
        let files = directories.map {
            Template.File.test(path: RelativePath($0.pathString + "/file.swift"))
        }
        let template = Template.test(files: files)
        let destinationPath = try temporaryPath()
        let expectedDirectories = [RelativePath("test_name"),
                                   RelativePath("test"),
                                   RelativePath("test_name/nested_dir")].map(destinationPath.appending)

        // When
        try subject.generate(template: template,
                             to: destinationPath,
                             attributes: ["name": "test_name",
                                          "aName": "test",
                                          "bName": "nested_dir"])

        // Then
        XCTAssertTrue(expectedDirectories.allSatisfy(FileHandler.shared.exists))
    }

    func test_files_are_generated() throws {
        // Given
        let files: [Template.File] = [
            Template.File(path: RelativePath("a"), contents: .string("aContent")),
            Template.File(path: RelativePath("b"), contents: .string("bContent")),
        ]

        let template = Template.test(files: files)
        let destinationPath = try temporaryPath()
        let expectedFiles: [(AbsolutePath, String)] = files.compactMap {
            let content: String
            switch $0.contents {
            case let .string(staticContent):
                content = staticContent
            case .file:
                XCTFail("Unexpected type")
                return nil
            }
            return (destinationPath.appending($0.path), content)
        }

        // When
        try subject.generate(template: template,
                             to: destinationPath,
                             attributes: [:])

        // Then
        try expectedFiles.forEach {
            XCTAssertEqual(try FileHandler.shared.readTextFile($0.0), $0.1)
        }
    }

    func test_files_are_generated_with_attributes() throws {
        // Given
        let files = [
            Template.File(path: RelativePath("{{ name }}"), contents: .string("{{ contentName }}")),
            Template.File(path: RelativePath("{{ directoryName }}/{{ fileName }}"), contents: .string("bContent")),
        ]
        let template = Template.test(files: files)
        let name = "test name"
        let contentName = "test content"
        let directoryName = "test directory"
        let fileName = "test file"
        let destinationPath = try temporaryPath()
        let expectedFiles: [(AbsolutePath, String)] = [
            (destinationPath.appending(component: name), contentName),
            (destinationPath.appending(components: directoryName, fileName), "bContent"),
        ]

        // When
        try subject.generate(template: template,
                             to: destinationPath,
                             attributes: [
                                 "name": name,
                                 "contentName": contentName,
                                 "directoryName": directoryName,
                                 "fileName": fileName,
                             ])

        // Then
        try expectedFiles.forEach {
            XCTAssertEqual(try FileHandler.shared.readTextFile($0.0), $0.1)
        }
    }

    func test_rendered_files() throws {
        // Given
        let sourcePath = try temporaryPath()
        let destinationPath = try temporaryPath()
        let name = "test name"
        let aContent = "test a content"
        let bContent = "test b content"
        let files = [
            Template.File(path: RelativePath("a/file"), contents: .file(sourcePath.appending(component: "testFile"))),
            Template.File(path: RelativePath("b/{{ name }}/file"), contents: .file(sourcePath.appending(components: "bTestFile"))),
        ]
        let template = Template.test(files: files)
        try FileHandler.shared.write(aContent, path: sourcePath.appending(component: "testFile"), atomically: true)
        try FileHandler.shared.write(bContent, path: sourcePath.appending(component: "bTestFile"), atomically: true)
        let expectedFiles: [(AbsolutePath, String)] = [
            (destinationPath.appending(components: "a", "file"), aContent),
            (destinationPath.appending(components: "b", name, "file"), bContent),
        ]

        // When
        try subject.generate(template: template,
                             to: destinationPath,
                             attributes: ["name": name])

        // Then
        try expectedFiles.forEach {
            XCTAssertEqual(try FileHandler.shared.readTextFile($0.0), $0.1)
        }
    }

    func test_file_rendered_with_attributes() throws {
        // Given
        let sourcePath = try temporaryPath()
        let destinationPath = try temporaryPath()
        let expectedContents = "attribute name content"
        try FileHandler.shared.write(expectedContents,
                                     path: sourcePath.appending(component: "a"),
                                     atomically: true)
        let template = Template.test(files: [Template.File(path: RelativePath("a"),
                                                           contents: .file(sourcePath.appending(component: "a")))])

        // When
        try subject.generate(template: template,
                             to: destinationPath,
                             attributes: ["name": "attribute name"])

        // Then
        XCTAssertEqual(try FileHandler.shared.readTextFile(destinationPath.appending(component: "a")),
                       expectedContents)
    }
}