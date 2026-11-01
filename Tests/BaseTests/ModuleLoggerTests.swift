import Testing

@testable import Base

@Test func theCategoryIsTheModuleOfTheFileID() {
    #expect(category(fileID: "Meters/AppPaths.swift") == "Meters")
    #expect(category(fileID: #fileID) == "BaseTests")
}
