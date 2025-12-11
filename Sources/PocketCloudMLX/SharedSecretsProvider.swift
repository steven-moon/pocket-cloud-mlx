import PocketCloudCommon

enum SharedSecretsProvider {
    static func providerKeys(envPath: String? = nil) -> ProviderKeys {
        SharedSecrets.providerKeys(envPath: envPath)
    }
}
