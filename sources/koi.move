module koinobori::koi {
    use sui::package;
    use sui::display;
    use std::string::String;

    public struct Koi has key, store {
        id: UID,
        number: u16,
        // image: Option<Image>
        image_url: Option<String>,
        kiosk_id: ID,
        kiosk_owner_cap_id: ID,
    }
}