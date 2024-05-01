module koinobori::nobori {
    use sui::package;
    use sui::display;
    use sui::tx_context::{sender};
    use sui::object_table::{Self, ObjectTable};
    use sui::transfer_policy;
    use sui::kiosk;
    use std::string::String;

    use koinobori::koi::{Self, Koi};

    public struct Nobori has key {
        id: UID,
        // image: Option<Image>
        image_url: Option<String>,
        koi_collection: ObjectTable<u16, Koi>,
    }

    public struct NOBORI has drop {}

    fun init(
        otw: NOBORI,
        ctx: &mut TxContext,
    ) {
        let publisher = package::claim(otw, ctx);

        let nobori = Nobori {
            id: object::new(ctx),
            // image: option::none(),
            image_url: option::none(),
            koi_collection: object_table::new(ctx),
        };

        let mut nobori_display = display::new<Nobori>(&publisher, ctx);
        nobori_display.add(b"name".to_string(), b"koinobori - NoboriFT".to_string());
        nobori_display.add(b"description".to_string(), b"A school of \"koi\" as a \"nobori\".".to_string());
        nobori_display.add(b"image_url".to_string(), b"ipfs://{image_url}".to_string());
        nobori_display.update_version();

        let mut koi_display = display::new<Koi>(&publisher, ctx);
        koi_display.add(b"name".to_string(), b"koi #{number} - NoboriFT".to_string());
        koi_display.add(b"description".to_string(), b"koi #{number} for \"koinobori\".".".to_string());
        koi_display.add(b"image_url".to_string(), b"ipfs://{image_url}".to_string());
        koi_display.add(b"kiosk_id".to_string(), b"{kiosk_id}".to_string());
        koi_display.add(b"kiosk_owner_cap_id".to_string(), b"{kiosk_owner_cap_id}".to_string());
        koi_display.update_version();

        let (policy, policy_cap) = transfer_policy::new<Koi>(&publisher, ctx);

        transfer::public_share_object(policy);
        transfer::public_transfer(policy_cap, sender(ctx));
        transfer::public_transfer(publisher, sender(ctx));
        transfer::public_transfer(nobori_display, sender(ctx));
        transfer::public_transfer(koi_display, sender(ctx));

        transfer::share_object(nobori);
    }

    public fun add_koi(
        cap: &AdminCap,
        nobori: &mut Nobori,
        image_url: String,
        ctx: &mut TxContext,
    ) {
        cap.verify_admin_cap(ctx);

        let (mut kiosk, kiosk_owner_cap) = kiosk::new(ctx);

        let koi = Koi {
            id: object::new(ctx),
            number: (nobori.koi_collection.length() as u16) + 1,
            // image: option::none(),
            image_url: image_url,
            kiosk_id: kiosk.id,
            kiosk_owner_cap_id: kiosk_owner_cap.id,
        };
    }
}