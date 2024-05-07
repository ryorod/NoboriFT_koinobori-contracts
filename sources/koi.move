module koinobori::koi {
    // === Imports ===

    use sui::package;
    use sui::display;
    use sui::event;
    use std::string::String;

    use koinobori::image::{Self, Image};
    use koinobori::role::AdminCap;

    // === Errors ===

    const EImageAlreadySet: u64 = 1;
    const EImageNotSet: u64 = 2;

    // === Structs ===

    public struct KOI has drop {}

    public struct Koi has key, store {
        id: UID,
        image: Option<Image>,
        image_url: String,
        nobori_id: ID,
    }

    // ===== Events =====

    public struct KoiCreated has copy, drop {
        object_id: ID,
        nobori_id: ID,
        creator: address,
        epoch: u64,
    }

    // === Init Function ===

    fun init(
        otw: KOI,
        ctx: &mut TxContext,
    ) {
        let publisher = package::claim(otw, ctx);

        let mut display = display::new<Koi>(&publisher, ctx);
        display.add(b"name".to_string(), b"koi - NoboriFT".to_string());
        display.add(b"description".to_string(), b"A \"koi\" for \"koinobori\".".to_string());
        display.add(b"image_url".to_string(), b"{image_url}".to_string());
        display.add(b"project_url".to_string(), b"https://koinobori2024.junni.dev".to_string());
        display.add(b"nobori_id".to_string(), b"{nobori_id}".to_string());
        display.update_version();

        transfer::public_transfer(publisher, ctx.sender());
        transfer::public_transfer(display, ctx.sender());
    }

    // === New Function ===

    public(package) fun new(
        nobori_id: ID,
        image_url: String,
        ctx: &mut TxContext,
    ): Koi {
        let koi = Koi {
            id: object::new(ctx),
            image: option::none(),
            image_url: image_url,
            nobori_id: nobori_id,
        };

        event::emit(KoiCreated {
            object_id: object::id(&koi),
            nobori_id: nobori_id,
            creator: ctx.sender(),
            epoch: ctx.epoch(),
        });

        koi
    }

    // === Admin Functions ===

    public fun set_image(
        cap: &AdminCap,
        koi: &mut Koi,
        image: Image,
        ctx: &mut TxContext,
    ) {
        cap.verify_admin_cap(ctx);
        assert!(koi.image.is_none(), EImageAlreadySet);

        koi.image.fill(image);
    }

    public fun unset_image(
        cap: &AdminCap,
        koi: &mut Koi,
        ctx: &mut TxContext,
    ) {
        cap.verify_admin_cap(ctx);
        assert!(koi.image.is_some(), EImageNotSet);

        let old_image = koi.image.extract();
        let promise = image::issue_delete_image_promise(&old_image);
        
        image::delete_image(old_image, promise);
    }

    public fun swap_image(
        cap: &AdminCap,
        koi: &mut Koi,
        new_image: Image,
        ctx: &mut TxContext,
    ) {
        cap.verify_admin_cap(ctx);

        let old_image = koi.image.swap(new_image);
        let promise = image::issue_delete_image_promise(&old_image);

        image::delete_image(old_image, promise);
    }

    public fun update_image_url(
        cap: &AdminCap,
        koi: &mut Koi,
        new_image_url: String,
        ctx: &mut TxContext,
    ) {
        cap.verify_admin_cap(ctx);

        koi.image_url = new_image_url;
    }
}