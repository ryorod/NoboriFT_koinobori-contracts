module koinobori::image {
    // === Imports ===

    use sui::event;
    use sui::dynamic_field;
    use sui::hex;
    use sui::transfer::Receiving;
    use sui::linked_table::{Self, LinkedTable};
    use std::hash;
    use std::string::String;

    use koinobori::role::AdminCap;

    // === Errors ===

    const EImageContentHashMismatch: u64 = 1;
    const EWrongImageForContent: u64 = 2;
    const EImagePromiseMismatch: u64 = 3;
    const EImageContentNotDeleted: u64 = 4;
    const EImageContentMissingKey: u64 = 5;
    const EImageContentMissingValue: u64 = 6;

    // === Structs ===

    public struct IMAGE has drop {}

    public struct Image has key, store {
        id: UID,
        encoding: String,
        mime_type: String,
        extension: String,
        // Stores a mapping between the image content's SHA-256 hash and its ID.
        content: LinkedTable<String, Option<ID>>,
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

    // === Entry Functions ===

    entry fun create_image(
        cap: &AdminCap,
        image_hash: String,
        ctx: &mut TxContext,
    ) {
        cap.verify_admin_cap(ctx);

        let mut image = Image {
            id: object::new(ctx),
            encoding: b"base85".to_string(),
            mime_type: b"image/avif".to_string(),
            extension: b"avif".to_string(),
            content: linked_table::new(ctx),
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

        image.content.push_front(image_hash, option::none());

        // Add a dynamic field to store the CreateImageContentCap ID.
        dynamic_field::add(
            &mut image.id,
            b"create_image_content_cap_id".to_string(),
            object::id(&create_image_content_cap),
        );

        transfer::transfer(create_image_content_cap, ctx.sender());

        event::emit(
            ImageCreated {
                id: object::id(&image),
            }
        );

        transfer::transfer(image, ctx.sender());
    }

    entry fun create_and_transfer_image_content(
        cap: CreateImageContentCap,
        mut data: vector<String>,
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
        transfer::transfer(register_image_content_cap, cap.image_id.to_address());

        let CreateImageContentCap {
            id,
            hash: _,
            image_id: _,
        } = cap;
        id.delete();
    }

    // === Receive Functions ===

    public fun receive_and_register_image_content(
        image: &mut Image,
        cap_to_receive: Receiving<RegisterImageContentCap>,
    ) {
        let cap = transfer::receive(&mut image.id, cap_to_receive);
        assert!(cap.image_id == object::id(image), EWrongImageForContent);

        let content_opt = image.content.borrow_mut(cap.content_hash);
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

    public fun receive_and_destroy_image_content(
        image: &mut Image,
        content_to_receive: Receiving<ImageContent>,
    ) {
        let content = transfer::receive(&mut image.id, content_to_receive);

        let content_opt = image.content.remove(content.hash);
        let _content_id = content_opt.destroy_some();

        let ImageContent {
            id,
            image_id: _,
            hash: _,
            data: _,
        } = content;

        id.delete();
    }

    // === Delete Function ===

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
        let content_key = image.content.front();
        assert!(content_key.is_some(), EImageContentMissingKey);

        let content_value = image.content.borrow(content_key.get_with_default(b"".to_string()));
        assert!(content_value.is_some(), EImageContentMissingValue);
    }
}