import Foundation
import SwiftData

public enum ChronoceptionMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum ChronoceptionStore {
    public static var schema: Schema { Schema(versionedSchema: SchemaV1.self) }

    /// The app's container. Pass `url` to use a specific store file, or `inMemory`
    /// for previews and tests.
    public static func makeContainer(url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let configuration =
            if let url {
                ModelConfiguration(schema: schema, url: url)
            } else if inMemory {
                // A unique name keeps separate in-memory containers from sharing a store.
                ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
            } else {
                ModelConfiguration("Chronoception", schema: schema)
            }
        return try ModelContainer(
            for: schema,
            migrationPlan: ChronoceptionMigrationPlan.self,
            configurations: configuration
        )
    }
}
