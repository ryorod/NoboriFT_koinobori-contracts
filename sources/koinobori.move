module koinobori::koinobori {
    // === Imports ===

    use sui::package;
    use sui::display;
    use sui::event;
    use sui::vec_set::{Self, VecSet};
    use std::string::String;

    use koinobori::role::AdminCap;

    // === Structs ===

    public struct KOINOBORI has drop {}

    public struct Koi has key, store {
        id: UID,
        // image: Option<Image>
        image_url: String,
        nobori_id: ID,
    }

    public struct Nobori has key {
        id: UID,
        // image: Option<Image>
        image_url: Option<String>,
        koi_collection: VecSet<ID>,
    }

    // ===== Events =====

    public struct KoiAdded has copy, drop {
        object_id: ID,
        nobori_id: ID,
        creator: address,
        epoch: u64,
    }

    public struct NoboriCreated has copy, drop {
        object_id: ID,
        creator: address,
        epoch: u64,
    }

    // === Init Function ===

    fun init(
        otw: KOINOBORI,
        ctx: &mut TxContext,
    ) {
        let publisher = package::claim(otw, ctx);

        let mut koi_display = display::new<Koi>(&publisher, ctx);
        koi_display.add(b"name".to_string(), b"koi - NoboriFT".to_string());
        koi_display.add(b"description".to_string(), b"A \"koi\" for \"koinobori\".".to_string());
        koi_display.add(b"image_url".to_string(), b"{image_url}".to_string());
        koi_display.add(b"project_url".to_string(), b"https://koinobori2024.junni.dev".to_string());
        koi_display.update_version();

        let mut nobori_display = display::new<Nobori>(&publisher, ctx);
        nobori_display.add(b"name".to_string(), b"koinobori - NoboriFT".to_string());
        nobori_display.add(b"description".to_string(), b"A school of \"koi\" as a \"nobori\".".to_string());
        nobori_display.add(b"image_url".to_string(), b"{image_url}".to_string());
        nobori_display.add(b"project_url".to_string(), b"https://koinobori2024.junni.dev".to_string());
        nobori_display.update_version();

        transfer::public_transfer(publisher, ctx.sender());
        transfer::public_transfer(koi_display, ctx.sender());
        transfer::public_transfer(nobori_display, ctx.sender());

        let nobori = Nobori {
            id: object::new(ctx),
            // image: option::none(),
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

    public fun add_koi(
        cap: &AdminCap,
        nobori: &mut Nobori,
        image_url: String,
        koi_receiver: address,
        ctx: &mut TxContext,
    ) {
        cap.verify_admin_cap(ctx);

        let nobori_id = object::id(nobori);

        let koi = Koi {
            id: object::new(ctx),
            // image: option::none(),
            image_url: image_url,
            nobori_id: nobori_id,
        };

        let koi_id = object::id(&koi);

        event::emit(KoiAdded {
            object_id: koi_id,
            nobori_id: nobori_id,
            creator: ctx.sender(),
            epoch: ctx.epoch(),
        });

        nobori.koi_collection.insert(koi_id);
        transfer::transfer(koi, koi_receiver);
    }
}