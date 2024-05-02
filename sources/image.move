module koinobori::image {
    // === Imports ===

    use sui::table::{Self, Table};
    use std::string::String;

    // === Structs ===

    public struct IMAGE has drop {}

    public struct Image has key, store {
        id: UID,
        encoding: String,
        mime_type: String,
        extension: String,
        // Stores a mapping between the image content's SHA-256 hash and its ID.
        content: Table<String, ID>,
    }

    public struct ImageContent has key {
        id: UID,
        // ID of the parent image.
        image_id: ID,
         // SHA-256 hash of the image.
        hash: String,
        // Base85-encoded string of the data.
        data: String,
    }
}