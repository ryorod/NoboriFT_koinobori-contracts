module koinobori::nobori {
    // === Imports ===

    use sui::package;
    use sui::display;
    use sui::event;
    use sui::vec_set::{Self, VecSet};
    use std::string::String;

    use koinobori::koi;
    use koinobori::image::{Self, Image};
    use koinobori::role::AdminCap;

    // === Errors ===

    const EImageAlreadySet: u64 = 1;

    // === Structs ===

    public struct NOBORI has drop {}

    public struct Nobori has key {
        id: UID,
        image: Option<Image>,
        image_url: Option<String>,
        koi_collection: VecSet<ID>,
    }

    // ===== Events =====

    public struct NoboriCreated has copy, drop {
        object_id: ID,
        creator: address,
        epoch: u64,
    }

    // === Init Function ===

    fun init(
        otw: NOBORI,
        ctx: &mut TxContext,
    ) {
        let publisher = package::claim(otw, ctx);

        let mut display = display::new<Nobori>(&publisher, ctx);
        display.add(b"name".to_string(), b"koinobori - NoboriFT".to_string());
        display.add(b"description".to_string(), b"A school of \"koi\" as a \"nobori\".".to_string());
        display.add(b"image_url".to_string(), b"{image_url}".to_string());
        display.add(b"project_url".to_string(), b"https://koinobori2024.junni.dev".to_string());
        display.add(b"koi_collection".to_string(), b"{koi_collection}".to_string());
        display.update_version();

        transfer::public_transfer(publisher, ctx.sender());
        transfer::public_transfer(display, ctx.sender());

        let nobori = Nobori {
            id: object::new(ctx),
            image: option::none(),
            image_url: option::none(),
            koi_collection: vec_set::empty(),
        };

        event::emit(NoboriCreated {
            object_id: object::id(&nobori),
            creator: ctx.sender(),
            epoch: ctx.epoch(),
        });

        transfer::share_object(nobori);
    }

    // === Admin Functions ===

    entry fun create_insert_and_transfer_koi(
        cap: &AdminCap,
        nobori: &mut Nobori,
        image_url: String,
        koi_recipient: address,
        ctx: &mut TxContext,
    ) {
        cap.verify_admin_cap(ctx);

        let koi = koi::new(object::id(nobori), image_url, ctx);

        nobori.koi_collection.insert(object::id(&koi));
        transfer::public_transfer(koi, koi_recipient);
    }

    entry fun set_image(
        cap: &AdminCap,
        nobori: &mut Nobori,
        image: Image,
        ctx: &TxContext,
    ) {
        cap.verify_admin_cap(ctx);
        assert!(nobori.image.is_none(), EImageAlreadySet);

        nobori.image.fill(image);
    }

    entry fun swap_image(
        cap: &AdminCap,
        nobori: &mut Nobori,
        new_image: Image,
        ctx: &TxContext,
    ) {
        cap.verify_admin_cap(ctx);

        let old_image = nobori.image.swap(new_image);
        let promise = image::issue_delete_image_promise(&old_image);

        image::delete_image(old_image, promise);
    }

    entry fun update_image_url(
        cap: &AdminCap,
        nobori: &mut Nobori,
        new_image_url: String,
        ctx: &TxContext,
    ) {
        cap.verify_admin_cap(ctx);

        nobori.image_url = option::some(new_image_url);
    }
}