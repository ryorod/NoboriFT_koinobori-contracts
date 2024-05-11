module koinobori::image {
    // === Imports ===

    use sui::event;
    use sui::dynamic_field;
    use sui::hex;
    use sui::vec_map::{Self, VecMap};
    use std::hash;
    use std::string::String;

    // === Errors ===

    const EImageContentHashMismatch: u64 = 1;
    const EWrongImageForContent: u64 = 2;
    const EImagePromiseMismatch: u64 = 3;
    const EImageContentNotDeleted: u64 = 4;
    const EImageContentMissingValue: u64 = 5;

    // === Structs ===

    public struct IMAGE has drop {}

    public struct Image has key, store {
        id: UID,
        encoding: String,
        mime_type: String,
        extension: String,
        // Stores a mapping between the image content's SHA-256 hash and its ID.
        content: VecMap<String, Option<ID>>,
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

    public struct CreateImageContentCap has key {
        id: UID,
        hash: String,
        image_id: ID,
    }

    public struct RegisterImageContentCap has key {
        id: UID,
        image_id: ID,
        content_id: ID,
        content_hash: String,
        // ID of the CreateImageContentCap that was used to create this RegisterImageContentCap.
        created_with: ID,
    }

    public struct DeleteImagePromise {
        image_id: ID,
    }

    // === Events ===

    public struct CreateImageContentCapCreated has copy, drop {
        id: ID,
        hash: String,
        image_id: ID,
    }

    public struct ImageCreated has copy, drop {
        id: ID,
    }

    public struct ImageContentCreated has copy, drop {
        id: ID,
        hash: String,
        image_id: ID,
    }

    // === Public-Mutative Functions ===

    public fun create_image(
        image_hash: String,
        data: vector<String>,
        ctx: &mut TxContext,
    ): Image {
        let mut image = Image {
            id: object::new(ctx),
            encoding: b"base85".to_string(),
            mime_type: b"image/avif".to_string(),
            extension: b"avif".to_string(),
            content: vec_map::empty(),
        };

        let create_image_content_cap = CreateImageContentCap {
            id: object::new(ctx),
            hash: image_hash,
            image_id: object::id(&image),
        };

        event::emit(
            CreateImageContentCapCreated {
                id: object::id(&create_image_content_cap),
                hash: image_hash,
                image_id: object::id(&image),
            }
        );

        image.content.insert(image_hash, option::none());

        // Add a dynamic field to store the CreateImageContentCap ID.
        dynamic_field::add(
            &mut image.id,
            b"create_image_content_cap_id".to_string(),
            object::id(&create_image_content_cap),
        );

        event::emit(
            ImageCreated {
                id: object::id(&image),
            }
        );

        create_and_transfer_image_content(create_image_content_cap, data, &mut image, ctx);

        image
    }

    // === Private Functions ===

    fun create_and_transfer_image_content(
        cap: CreateImageContentCap,
        mut data: vector<String>,
        image: &mut Image,
        ctx: &mut TxContext,
    ) {
        // Create an empty string.
        let mut concat_content_str = b"".to_string();

        // Loop through data, remove each string, and append it to the concatenated string.
        while (!data.is_empty()) {
            // Remove the first string in the vector.
            let content_str = data.remove(0);
            concat_content_str.append(content_str);
        };

        // Grab a reference to the concatenated string's underlying bytes.
        let concat_content_bytes = concat_content_str.bytes();

        // Calculate a SHA-256 hash of the concatenated string.
        let content_hash_bytes = hash::sha2_256(*concat_content_bytes);
        let content_hash_hex = hex::encode(content_hash_bytes);
        let content_hash_str = content_hash_hex.to_string();

        // Assert the calculated hash matches the target hash.
        assert!(content_hash_str == cap.hash, EImageContentHashMismatch);

        let content = ImageContent {
            id: object::new(ctx),
            image_id: cap.image_id,
            hash: content_hash_str,
            data: concat_content_str,
        };

        let register_image_content_cap = RegisterImageContentCap {
            id: object::new(ctx),
            image_id: cap.image_id,
            content_id: object::id(&content),
            content_hash: content_hash_str,
            created_with: object::id(&cap),
        };

        event::emit(
            ImageContentCreated{
                id: object::id(&content),
                image_id: cap.image_id,
                hash: content_hash_str,
            }
        );

        // Transfer content to the image directly.
        transfer::transfer(content, cap.image_id.to_address());

        let CreateImageContentCap {
            id,
            hash: _,
            image_id: _,
        } = cap;
        id.delete();

        register_image_content(register_image_content_cap, image);
    }

    fun register_image_content(
        cap: RegisterImageContentCap,
        image: &mut Image,
    ) {
        assert!(cap.image_id == object::id(image), EWrongImageForContent);

        let content_opt = &mut image.content[&cap.content_hash];
        content_opt.fill(cap.content_id);

        // remove the "create_image_content_cap_id" dynamic field.
        let _create_image_content_cap_id_for_image: ID = dynamic_field::remove(&mut image.id, b"create_image_content_cap_id".to_string());

        let RegisterImageContentCap {
            id,
            image_id: _,
            content_id: _,
            content_hash: _,
            created_with: _,
        } = cap;
        id.delete();
    }

    // === Delete Functions ===

    public fun delete_image_content(
        image: &mut Image,
        content: ImageContent,
    ) {
        let (_content_hash, content_opt) = image.content.remove(&content.hash);
        let _content_id = content_opt.destroy_some();

        let ImageContent {
            id,
            image_id: _,
            hash: _,
            data: _,
        } = content;

        id.delete();
    }

    public fun delete_image(
        image: Image,
        promise: DeleteImagePromise,
    ) {
        assert!(object::id(&image) == promise.image_id, EImagePromiseMismatch);
        assert!(image.content.is_empty(), EImageContentNotDeleted);

        let Image {
            id,
            encoding: _,
            mime_type: _,
            extension: _,
            content,
        } = image;

        // This will abort if the image content linked table is not empty.
        // We designed it this way to ensure there are no orphaned content objects
        // as a result of destroying the parent image object.
        content.destroy_empty();
        id.delete();

        let DeleteImagePromise { image_id: _ } = promise;
    }

    // === Public-Package Functions ===

    public(package) fun issue_delete_image_promise(
        image: &Image,
    ): DeleteImagePromise {
        let promise = DeleteImagePromise {
            image_id: object::id(image),
        };

        promise
    }

    public(package) fun verify_image_content_registered(
        image: &Image,
    ) {
        let mut content_keys = image.content.keys();

        while (!content_keys.is_empty()) {
            let content_key = content_keys.pop_back();
            let content_value = &image.content[&content_key];
            assert!(content_value.is_some(), EImageContentMissingValue);
        };

        content_keys.destroy_empty();
    }
}